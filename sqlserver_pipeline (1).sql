/* ============================================================================
   COLLECTIONS ANALYTICS  |  SQL SERVER (T-SQL) VERSION
   ============================================================================
   SQL Server cannot read CSVs directly (no read_csv_auto). So the flow is:

     STEP 1 (once): import the 17 CSVs into tables named stg_<table>
                    via SSMS  ->  right-click database  ->  Tasks  ->
                    Import Flat File...   (wizard, no code needed)
                    Name each import  stg_accounts, stg_payments, etc.

     STEP 2: run this script. It builds the golden tables + metrics as VIEWS
             and TABLES, mirroring the Python/DuckDB pipeline exactly.

   Timezone note: SQL Server has no per-row named-zone convert like DuckDB.
   We normalise using the offset each zone had in 2026 (UTC+0, +5:30, +4:00)
   via DATEADD on a CASE. Result = IST wall-clock, same as the Python to_ist().
   ============================================================================ */

/* ------------------------------------------------------------------ helper:
   a scalar expression we reuse to push any event_at + its timezone to IST.
   UTC ->+330 min | Asia/Dubai(+4) ->+90 min to reach IST(+5:30) | Kolkata ->0 */
-- (implemented inline per table below as CASE ... DATEADD)

/* ============================ DIM: ACCOUNT (spine) ======================== */
IF OBJECT_ID('dim_account','V') IS NOT NULL DROP VIEW dim_account;
GO
CREATE VIEW dim_account AS
SELECT
    a.account_id, a.borrower_id, a.loan_type,
    a.principal_amount, a.outstanding_amount, a.dpd, a.risk_segment,
    a.[status]  AS status_snapshot,
    a.timezone, a.schema_version,
    /* opened_at -> IST */
    DATEADD(MINUTE,
        CASE a.timezone WHEN 'UTC' THEN 330 WHEN 'Asia/Dubai' THEN 90 ELSE 0 END,
        a.opened_at)                                    AS opened_at_ist,
    CASE WHEN a.borrower_id IS NULL THEN 'missing'
         WHEN b.borrower_id IS NULL THEN 'orphan'
         ELSE 'valid' END                               AS borrower_link,
    CASE WHEN a.outstanding_amount > a.principal_amount THEN 1 ELSE 0 END
                                                         AS flag_outstanding_gt_principal
FROM stg_accounts a
LEFT JOIN (SELECT DISTINCT borrower_id FROM stg_borrowers) b
       ON a.borrower_id = b.borrower_id;
GO

/* ============================ DIM: AGENT (30k -> 1k) ===================== */
IF OBJECT_ID('dim_agent','U') IS NOT NULL DROP TABLE dim_agent;
GO
;WITH latest AS (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY agent_id ORDER BY updated_at DESC) rn
    FROM stg_agents
),
tenure AS (SELECT agent_id, MIN(joined_at) tenure_start FROM stg_agents GROUP BY agent_id)
SELECT l.agent_id, l.employee_code, l.agent_name, l.vendor_id, l.team, l.[status],
       t.tenure_start, l.updated_at, CAST('LOW' AS varchar(10)) AS identity_confidence
INTO dim_agent
FROM latest l JOIN tenure t ON l.agent_id = t.agent_id
WHERE l.rn = 1;
GO

/* ============================ DIM: BORROWER (30.6k -> 11k) =============== */
IF OBJECT_ID('dim_borrower','U') IS NOT NULL DROP TABLE dim_borrower;
GO
;WITH deduped AS (           /* exact-dedup: one row per identical tuple */
    SELECT DISTINCT borrower_id, name, phone, email, city, state, created_at, updated_at
    FROM stg_borrowers
),
ranked AS (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY borrower_id ORDER BY updated_at DESC) rn
    FROM deduped
)
SELECT borrower_id, name, phone, email, city, state, created_at, updated_at,
       CAST('MEDIUM' AS varchar(10)) AS identity_confidence
INTO dim_borrower
FROM ranked WHERE rn = 1;
GO

/* ============================ DIM: CAMPAIGN / VENDOR ===================== */
IF OBJECT_ID('dim_campaign','V') IS NOT NULL DROP VIEW dim_campaign;
GO
CREATE VIEW dim_campaign AS
SELECT campaign_id, campaign_name,
       channel AS channel_source_of_truth,   -- trust channel, NOT name
       strategy_version, start_at, end_at, target_definition,
       CAST(1 AS bit) AS name_channel_conflict
FROM stg_campaigns;
GO

/* ============================ FACT: PAYMENT (core correction) =========== */
IF OBJECT_ID('fact_payment','U') IS NOT NULL DROP TABLE fact_payment;
GO
;WITH deduped AS (            /* DELETE exact duplicate rows */
    SELECT DISTINCT payment_id, account_id, borrower_id, event_at,
           payment_reference, amount, payment_status, payment_method, provider_id
    FROM stg_payments
),
ranked_success AS (          /* dedup SUCCESS by reference (retry) */
    SELECT *, ROW_NUMBER() OVER (PARTITION BY payment_reference ORDER BY event_at) ref_rn
    FROM deduped
    WHERE payment_status='SUCCESS' AND payment_reference IS NOT NULL
),
kept AS (
    SELECT payment_id,account_id,borrower_id,event_at,payment_reference,amount,payment_status,payment_method,provider_id
    FROM ranked_success WHERE ref_rn=1
    UNION ALL
    SELECT payment_id,account_id,borrower_id,event_at,payment_reference,amount,payment_status,payment_method,provider_id
    FROM deduped WHERE payment_status='SUCCESS' AND payment_reference IS NULL
    UNION ALL
    SELECT payment_id,account_id,borrower_id,event_at,payment_reference,amount,payment_status,payment_method,provider_id
    FROM deduped WHERE payment_status <> 'SUCCESS'
)
SELECT k.*,
       DATEADD(MINUTE,
           CASE ac.timezone WHEN 'UTC' THEN 330 WHEN 'Asia/Dubai' THEN 90 ELSE 0 END,
           k.event_at)                                  AS event_ist,
       CASE WHEN k.payment_status='SUCCESS' THEN 1 ELSE 0 END AS is_recovery,
       CASE WHEN k.payment_reference IS NULL THEN 1 ELSE 0 END AS null_reference
INTO fact_payment
FROM kept k
LEFT JOIN stg_accounts ac ON k.account_id = ac.account_id;
GO

/* ============================ FACT: CALL ================================= */
IF OBJECT_ID('fact_call','U') IS NOT NULL DROP TABLE fact_call;
GO
;WITH d AS (
    SELECT DISTINCT call_id,account_id,borrower_id,event_at,agent_id,campaign_id,
           direction,vendor_id,call_status,duration_sec,timezone
    FROM stg_calls
)
SELECT d.*,
       DATEADD(MINUTE, CASE d.timezone WHEN 'UTC' THEN 330 WHEN 'Asia/Dubai' THEN 90 ELSE 0 END, d.event_at) AS event_ist,
       CASE WHEN d.agent_id IS NULL THEN 1 ELSE 0 END AS is_automated,
       CASE WHEN d.call_status='ANSWERED' THEN 1 ELSE 0 END AS duration_valid
INTO fact_call
FROM d;
GO

/* ============================ FACT: DISPOSITIONS (unify PTP) ============= */
IF OBJECT_ID('fact_disposition','U') IS NOT NULL DROP TABLE fact_disposition;
GO
SELECT cd.*,
       CASE WHEN cd.disposition_code='PTP' THEN 'PROMISE_TO_PAY'
            ELSE cd.disposition_code END AS disposition_clean,
       DATEADD(MINUTE, CASE ac.timezone WHEN 'UTC' THEN 330 WHEN 'Asia/Dubai' THEN 90 ELSE 0 END, cd.event_at) AS event_ist
INTO fact_disposition
FROM stg_call_dispositions cd
LEFT JOIN stg_accounts ac ON cd.account_id = ac.account_id;
GO

/* ============================ FACT: STATUS HISTORY + point-in-time ======= */
IF OBJECT_ID('fact_status_history','U') IS NOT NULL DROP TABLE fact_status_history;
GO
SELECT h.*,
       DATEADD(MINUTE, CASE ac.timezone WHEN 'UTC' THEN 330 WHEN 'Asia/Dubai' THEN 90 ELSE 0 END, h.event_at) AS event_ist
INTO fact_status_history
FROM stg_status_history h
LEFT JOIN stg_accounts ac ON h.account_id = ac.account_id;
GO
IF OBJECT_ID('dim_account_final_status','U') IS NOT NULL DROP TABLE dim_account_final_status;
GO
;WITH r AS (
    SELECT account_id, [status],
           ROW_NUMBER() OVER (PARTITION BY account_id ORDER BY event_ist DESC) rn
    FROM fact_status_history
)
SELECT account_id, [status] AS final_status INTO dim_account_final_status
FROM r WHERE rn=1;
GO

/* ============================ FACT: TARGETING =========================== */
IF OBJECT_ID('fact_targeting','U') IS NOT NULL DROP TABLE fact_targeting;
GO
SELECT dt.*,
       CASE WHEN COUNT(*) OVER (PARTITION BY account_id, target_date) > 1 THEN 1 ELSE 0 END AS dup_account_day
INTO fact_targeting
FROM stg_daily_targeting dt;
GO

/* ============================ FACT: PTP + kept verification ============= */
IF OBJECT_ID('fact_ptp','U') IS NOT NULL DROP TABLE fact_ptp;
GO
;WITH pay AS (SELECT account_id, event_ist FROM fact_payment WHERE is_recovery=1),
verify AS (
    SELECT p.ptp_id,
           MIN(ABS(DATEDIFF(SECOND, pay.event_ist, p.promised_date))/86400.0) AS min_days
    FROM stg_promises_to_pay p
    LEFT JOIN pay ON p.account_id = pay.account_id
    GROUP BY p.ptp_id
)
SELECT pt.*,
       DATEADD(MINUTE, CASE ac.timezone WHEN 'UTC' THEN 330 WHEN 'Asia/Dubai' THEN 90 ELSE 0 END, pt.event_at) AS event_ist,
       CASE WHEN v.min_days <= 7 THEN 1 ELSE 0 END AS kept_verified
INTO fact_ptp
FROM stg_promises_to_pay pt
LEFT JOIN stg_accounts ac ON pt.account_id = ac.account_id
LEFT JOIN verify v ON pt.ptp_id = v.ptp_id;
GO

/* ============================ FACT: AGENT SESSIONS ====================== */
IF OBJECT_ID('fact_agent_session','U') IS NOT NULL DROP TABLE fact_agent_session;
GO
SELECT s.*,
       DATEADD(MINUTE, CASE s.timezone WHEN 'UTC' THEN 330 WHEN 'Asia/Dubai' THEN 90 ELSE 0 END, s.login_at)  AS login_ist,
       DATEADD(MINUTE, CASE s.timezone WHEN 'UTC' THEN 330 WHEN 'Asia/Dubai' THEN 90 ELSE 0 END, s.logout_at) AS logout_ist,
       DATEDIFF(SECOND, s.login_at, s.logout_at)/3600.0 AS session_hours
INTO fact_agent_session
FROM stg_agent_sessions s;
GO

/* ========================================================================
   METRICS  (views — read only the golden layer, definitions locked)
   ======================================================================== */

/* ---- Recovery: naive vs true (the ~25% inflation) ---- */
IF OBJECT_ID('metric_recovery_naive_vs_true','V') IS NOT NULL DROP VIEW metric_recovery_naive_vs_true;
GO
CREATE VIEW metric_recovery_naive_vs_true AS
SELECT
  (SELECT SUM(amount) FROM stg_payments WHERE payment_status='SUCCESS') AS naive_recovery,
  (SELECT SUM(CASE WHEN is_recovery=1 THEN amount ELSE 0 END)
        - SUM(CASE WHEN payment_status='REVERSED' THEN amount ELSE 0 END)
   FROM fact_payment) AS true_recovery;
GO

/* ---- Monthly recovery + MoM (the 11% debunk) ---- */
IF OBJECT_ID('metric_monthly_recovery','V') IS NOT NULL DROP VIEW metric_monthly_recovery;
GO
CREATE VIEW metric_monthly_recovery AS
WITH rec AS (
    SELECT DATEFROMPARTS(YEAR(event_ist),MONTH(event_ist),1) AS mth,
           SUM(CASE WHEN is_recovery=1 THEN amount ELSE 0 END) AS gross_recovery,
           SUM(CASE WHEN payment_status='REVERSED' THEN amount ELSE 0 END) AS reversed_amt
    FROM fact_payment GROUP BY DATEFROMPARTS(YEAR(event_ist),MONTH(event_ist),1)
)
SELECT mth,
       (gross_recovery - reversed_amt) AS true_recovery,
       ROUND(100.0*((gross_recovery-reversed_amt)
             / NULLIF(LAG(gross_recovery-reversed_amt) OVER (ORDER BY mth),0) - 1),1) AS mom_pct
FROM rec;
GO

/* ---- PTP rate (unified code) & PTP-kept (label vs verified) ---- */
IF OBJECT_ID('metric_ptp','V') IS NOT NULL DROP VIEW metric_ptp;
GO
CREATE VIEW metric_ptp AS
SELECT
  (SELECT SUM(CASE WHEN disposition_clean='PROMISE_TO_PAY' THEN 1 ELSE 0 END) FROM fact_disposition) AS ptp_count,
  (SELECT COUNT(*) FROM fact_disposition) AS dispositions,
  (SELECT SUM(CASE WHEN [status]='KEPT' THEN 1 ELSE 0 END) FROM fact_ptp) AS labelled_kept,
  (SELECT SUM(kept_verified) FROM fact_ptp) AS verified_kept;
GO

/* ---- Selection bias: targeted vs never-targeted pay rate ---- */
IF OBJECT_ID('analysis_selection_bias','V') IS NOT NULL DROP VIEW analysis_selection_bias;
GO
CREATE VIEW analysis_selection_bias AS
WITH targeted AS (SELECT DISTINCT account_id FROM fact_targeting),
grp AS (
  SELECT a.account_id,
         CASE WHEN t.account_id IS NOT NULL THEN 'targeted' ELSE 'never_targeted' END AS grp
  FROM dim_account a LEFT JOIN targeted t ON a.account_id=t.account_id
),
pays AS (SELECT DISTINCT account_id FROM fact_payment WHERE is_recovery=1)
SELECT g.grp, COUNT(*) AS accounts, COUNT(pays.account_id) AS paying,
       ROUND(100.0*COUNT(pays.account_id)/COUNT(*),1) AS pay_rate_pct
FROM grp g LEFT JOIN pays ON g.account_id=pays.account_id
GROUP BY g.grp;
GO
