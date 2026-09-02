/* ============================================================================
   05_business_analytics_17.sql   |   SQL SERVER
   ----------------------------------------------------------------------------
   17 BUSINESS ANALYTICS QUERIES answering the assignment's four questions.
   Each query states: [ASKED] what the brief wants  /  [DELIVER] the result.
   Run AFTER: 00_load -> 00b_typed -> sqlserver_pipeline.
   All numbers below were validated against the golden layer.
   ============================================================================ */


/* ========================================================================
   THEME 1: "IS THE REPORTED 11% IMPROVEMENT REAL?"  (Question 3)
   ======================================================================== */

/* Q1 ---------------------------------------------------------------------
   [ASKED]   Prove or disprove the reported recovery number.
   [DELIVER] Naive Rs 134.1 Cr vs TRUE Rs 107.5 Cr -> 24.8% duplicate inflation. */
SELECT
  CAST((SELECT SUM(TRY_CAST(amount AS float)) FROM stg_payments WHERE payment_status='SUCCESS')/10000000.0 AS decimal(6,1)) AS naive_recovery_cr,
  CAST((SELECT SUM(CASE WHEN is_recovery=1 THEN amount ELSE 0 END)
            - SUM(CASE WHEN payment_status='REVERSED' THEN amount ELSE 0 END)
        FROM fact_payment)/10000000.0 AS decimal(6,1)) AS true_recovery_cr;

/* Q2 ---------------------------------------------------------------------
   [ASKED]   Is recovery improving 11% month-on-month?
   [DELIVER] NO. Series is flat/declining; the +11% is one Feb->Mar month-pair.
             MoM swings -10% to +11%; Jan->Jul trend is DOWN. */
WITH r AS (
  SELECT DATEFROMPARTS(YEAR(event_ist),MONTH(event_ist),1) AS mth,
         SUM(CASE WHEN is_recovery=1 THEN amount ELSE 0 END)
       - SUM(CASE WHEN payment_status='REVERSED' THEN amount ELSE 0 END) AS rec
  FROM fact_payment GROUP BY DATEFROMPARTS(YEAR(event_ist),MONTH(event_ist),1))
SELECT mth,
       CAST(rec/10000000.0 AS decimal(6,2)) AS recovery_cr,
       CAST(100.0*(rec/NULLIF(LAG(rec) OVER (ORDER BY mth),0)-1) AS decimal(6,1)) AS mom_pct
FROM r WHERE mth < '2026-08-01' ORDER BY mth;

/* Q3 ---------------------------------------------------------------------
   [ASKED]   Are duplicate payments inflating recovery? (Forensics A)
   [DELIVER] YES. 500 duplicate payment_ids + 2,531 duplicate SUCCESS references. */
SELECT
  (SELECT COUNT(*) FROM stg_payments) - (SELECT COUNT(DISTINCT payment_id) FROM stg_payments) AS duplicate_payment_ids,
  (SELECT COUNT(*) FROM stg_payments WHERE payment_status='SUCCESS')
   - (SELECT COUNT(DISTINCT payment_reference) FROM stg_payments WHERE payment_status='SUCCESS' AND payment_reference IS NOT NULL) AS duplicate_success_refs;

/* Q4 ---------------------------------------------------------------------
   [ASKED]   Independent recovery rate (challenge their definition).
   [DELIVER] 40.5% of accounts ever pay (12,145 of 30,000). */
SELECT COUNT(DISTINCT CASE WHEN is_recovery=1 THEN account_id END) AS paying_accounts,
       (SELECT COUNT(*) FROM dim_account) AS total_accounts,
       CAST(100.0*COUNT(DISTINCT CASE WHEN is_recovery=1 THEN account_id END)
            /(SELECT COUNT(*) FROM dim_account) AS decimal(5,1)) AS recovery_rate_pct
FROM fact_payment;

/* Q16 --------------------------------------------------------------------
   [ASKED]   Where does the inflation come from? (payment status breakdown)
   [DELIVER] Only SUCCESS (Rs 117 Cr) counts; REVERSED (Rs 9.5 Cr) must be netted;
             FAILED/PENDING (Rs 47 Cr) are NOT recovery. */
SELECT payment_status, COUNT(*) AS rows_cnt, CAST(SUM(amount)/10000000.0 AS decimal(6,2)) AS amount_cr
FROM fact_payment GROUP BY payment_status ORDER BY 3 DESC;


/* ========================================================================
   THEME 2: FUNNEL & EFFICIENCY METRICS  (Question 3 - challenge definitions)
   ======================================================================== */

/* Q5 ---------------------------------------------------------------------
   [ASKED]   Contact rate (challenge the definition).
   [DELIVER] 19.9% true contact rate (answered / total calls, TZ-normalised). */
SELECT COUNT(*) AS total_calls,
       SUM(CASE WHEN call_status='ANSWERED' THEN 1 ELSE 0 END) AS answered,
       CAST(100.0*SUM(CASE WHEN call_status='ANSWERED' THEN 1 ELSE 0 END)/COUNT(*) AS decimal(5,1)) AS contact_rate_pct
FROM fact_call;

/* Q6 ---------------------------------------------------------------------
   [ASKED]   PTP rate (challenge - codes were split PTP vs PROMISE_TO_PAY).
   [DELIVER] 22.4% using the UNIFIED code (was understated ~50% before). */
SELECT SUM(CASE WHEN disposition_clean='PROMISE_TO_PAY' THEN 1 ELSE 0 END) AS ptp_count,
       COUNT(*) AS dispositions,
       CAST(100.0*SUM(CASE WHEN disposition_clean='PROMISE_TO_PAY' THEN 1 ELSE 0 END)/COUNT(*) AS decimal(5,1)) AS ptp_rate_pct
FROM fact_disposition;

/* Q7 ---------------------------------------------------------------------
   [ASKED]   PTP-kept rate (challenge - is the label trustworthy?).
   [DELIVER] NO. 4,489 labelled KEPT, only 567 (12.6%) have a real matching payment. */
SELECT SUM(CASE WHEN [status]='KEPT' THEN 1 ELSE 0 END) AS labelled_kept,
       SUM(kept_verified) AS verified_kept,
       CAST(100.0*SUM(kept_verified)/NULLIF(SUM(CASE WHEN [status]='KEPT' THEN 1 ELSE 0 END),0) AS decimal(5,1)) AS truly_kept_pct
FROM fact_ptp;

/* Q8 ---------------------------------------------------------------------
   [ASKED]   Recovery per agent-hour (efficiency metric).
   [DELIVER] ~Rs 14,829 recovered per agent-hour (Rs 117 Cr / 78,871 hrs). */
SELECT CAST((SELECT SUM(amount) FROM fact_payment WHERE is_recovery=1)/10000000.0 AS decimal(7,2)) AS recovery_cr,
       CAST((SELECT SUM(session_hours) FROM fact_agent_session) AS decimal(9,0)) AS agent_hours,
       CAST((SELECT SUM(amount) FROM fact_payment WHERE is_recovery=1)
            /(SELECT SUM(session_hours) FROM fact_agent_session) AS decimal(9,0)) AS recovery_per_agent_hour;


/* ========================================================================
   THEME 3: WHY DID IT CHANGE? DRIVERS  (Question 2)
   ======================================================================== */

/* Q9 ---------------------------------------------------------------------
   [ASKED]   Recovery by risk segment (is improvement from easier accounts?).
   [DELIVER] All 4 segments recover ~Rs 29 Cr each -> risk_segment is RANDOM;
             any "segment improvement" is a mix illusion, not real performance. */
SELECT a.risk_segment, COUNT(DISTINCT p.account_id) AS paying_accounts,
       CAST(SUM(p.amount)/10000000.0 AS decimal(6,2)) AS recovery_cr
FROM fact_payment p JOIN dim_account a ON p.account_id=a.account_id
WHERE p.is_recovery=1 GROUP BY a.risk_segment ORDER BY 3 DESC;

/* Q10 --------------------------------------------------------------------
   [ASKED]   Is the targeting strategy working? (borrower targeting driver)
   [DELIVER] NO. Targeted accounts pay 40.2% vs never-targeted 41.4%.
             Targeting adds ~0 -> current strategy is idle. */
WITH t AS (SELECT DISTINCT account_id FROM fact_targeting),
g AS (SELECT a.account_id, CASE WHEN t.account_id IS NOT NULL THEN 'targeted' ELSE 'never_targeted' END grp
      FROM dim_account a LEFT JOIN t ON a.account_id=t.account_id),
pays AS (SELECT DISTINCT account_id FROM fact_payment WHERE is_recovery=1)
SELECT g.grp, COUNT(*) AS accounts, COUNT(pays.account_id) AS paying,
       CAST(100.0*COUNT(pays.account_id)/COUNT(*) AS decimal(5,1)) AS pay_rate_pct
FROM g LEFT JOIN pays ON g.account_id=pays.account_id GROUP BY g.grp;

/* Q11 --------------------------------------------------------------------
   [ASKED]   Denominator manipulation? Do write-offs leave the population? (Forensics G)
   [DELIVER] NO. Collectible% is flat ~57% every month -> denominator is stable,
             so improvement is NOT a survivorship artifact. */
WITH months AS (SELECT CAST('2026-01-31' AS date) me UNION ALL SELECT '2026-03-31'
                UNION ALL SELECT '2026-05-31' UNION ALL SELECT '2026-07-31'),
pit AS (SELECT m.me, h.account_id, h.[status],
        ROW_NUMBER() OVER (PARTITION BY m.me,h.account_id ORDER BY h.event_ist DESC) rn
        FROM months m JOIN fact_status_history h ON h.event_ist<=m.me)
SELECT me, COUNT(*) AS tracked,
       CAST(100.0*SUM(CASE WHEN [status] IN ('ACTIVE','DELINQUENT','PTP','NPA') THEN 1 ELSE 0 END)/COUNT(*) AS decimal(5,1)) AS collectible_pct
FROM pit WHERE rn=1 GROUP BY me ORDER BY me;

/* Q14 --------------------------------------------------------------------
   [ASKED]   Channel conversion - which channel produces kept promises?
   [DELIVER] All channels ~3% verified-kept; FIELD/WHATSAPP marginally best.
             No channel is a clear winner -> spend decision needs an experiment. */
SELECT source AS channel, COUNT(*) AS promises,
       SUM(kept_verified) AS kept_verified,
       CAST(100.0*SUM(kept_verified)/COUNT(*) AS decimal(5,1)) AS kept_rate_pct
FROM fact_ptp GROUP BY source ORDER BY 4 DESC;


/* ========================================================================
   THEME 4: DATA-INTEGRITY TRAPS  (Forensics - deducted from the data)
   ======================================================================== */

/* Q12 --------------------------------------------------------------------
   [ASKED]   Agent identity problem - one agent under many IDs? (Forensics E)
   [DELIVER] 30,000 agent rows collapse to 1,000 real agents ->
             ALL agent-level metrics must be treated as LOW confidence. */
SELECT (SELECT COUNT(*) FROM stg_agents) AS raw_agent_rows,
       (SELECT COUNT(*) FROM dim_agent)  AS real_agents;

/* Q13 --------------------------------------------------------------------
   [ASKED]   Timezone problem - are calls in the wrong hour? (Forensics C)
   [DELIVER] YES. Peak calling hour shifts 23:00 (raw) -> 05:00 (IST). Any
             "best time to call" built on raw timestamps is wrong. */
SELECT (SELECT TOP 1 DATEPART(HOUR,TRY_CAST(event_at AS datetime2)) FROM stg_calls
        GROUP BY DATEPART(HOUR,TRY_CAST(event_at AS datetime2)) ORDER BY COUNT(*) DESC) AS raw_peak_hour,
       (SELECT TOP 1 DATEPART(HOUR,event_ist) FROM fact_call
        GROUP BY DATEPART(HOUR,event_ist) ORDER BY COUNT(*) DESC) AS ist_peak_hour;

/* Q15 --------------------------------------------------------------------
   [ASKED]   Guardrail - are we recovering at the cost of complaints?
   [DELIVER] 8,000 complaints; AGENT_BEHAVIOUR & HARASSMENT are top types ->
             any aggressive-channel investment must watch this. */
SELECT complaint_type, COUNT(*) AS complaints
FROM fact_complaint GROUP BY complaint_type ORDER BY 2 DESC;

/* Q17 --------------------------------------------------------------------
   [ASKED]   Time-series integrity - is August a real collapse?
   [DELIVER] NO. Data ends 2026-08-08 -> August is a PARTIAL month (8 days),
             not a -74% drop. Must exclude/annualise, never read as a crash. */
SELECT MAX(TRY_CAST(event_at AS datetime2)) AS last_payment_timestamp,
       'August is partial (ends Aug 8) - exclude from trend' AS interpretation
FROM stg_payments;
