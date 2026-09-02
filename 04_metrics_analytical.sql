/* ============================================================================
   04_metrics_analytical.sql  |  SQL SERVER
   Extra METRIC CALCULATIONS + ANALYTICAL QUERIES (Deliverable 1 checklist).
   Run AFTER sqlserver_pipeline.sql. All read the golden layer only.
   ============================================================================ */

/* ========================= METRIC CALCULATIONS ============================ */

/* ---- Contact rate = answered / total calls (TZ-normalised, dedup'd) ---- */
IF OBJECT_ID('metric_contact_rate','V') IS NOT NULL DROP VIEW metric_contact_rate;
GO
CREATE VIEW metric_contact_rate AS
SELECT COUNT(*) AS total_calls,
       SUM(CASE WHEN call_status='ANSWERED' THEN 1 ELSE 0 END) AS answered,
       ROUND(100.0*SUM(CASE WHEN call_status='ANSWERED' THEN 1 ELSE 0 END)/COUNT(*),1) AS contact_rate_pct
FROM fact_call;
GO

/* ---- RPC (right-party-contact) rate = meaningful dispositions / connected ---- */
IF OBJECT_ID('metric_rpc_rate','V') IS NOT NULL DROP VIEW metric_rpc_rate;
GO
CREATE VIEW metric_rpc_rate AS
SELECT
  SUM(CASE WHEN disposition_clean IN ('PROMISE_TO_PAY','PAID','DISPUTE','REFUSED','CALLBACK') THEN 1 ELSE 0 END) AS rpc_contacts,
  COUNT(*) AS dispositions,
  ROUND(100.0*SUM(CASE WHEN disposition_clean IN ('PROMISE_TO_PAY','PAID','DISPUTE','REFUSED','CALLBACK') THEN 1 ELSE 0 END)/COUNT(*),1) AS rpc_rate_pct
FROM fact_disposition;
GO

/* ---- Recovery per agent-hour = true recovery / total session hours ---- */
IF OBJECT_ID('metric_recovery_per_agent_hour','V') IS NOT NULL DROP VIEW metric_recovery_per_agent_hour;
GO
CREATE VIEW metric_recovery_per_agent_hour AS
SELECT
  (SELECT SUM(amount) FROM fact_payment WHERE is_recovery=1)              AS recovery,
  (SELECT SUM(session_hours) FROM fact_agent_session)                     AS agent_hours,
  ROUND( (SELECT SUM(amount) FROM fact_payment WHERE is_recovery=1)
       / NULLIF((SELECT SUM(session_hours) FROM fact_agent_session),0), 0) AS recovery_per_agent_hour;
GO

/* ---- Recovery rate = paying accounts / total accounts ---- */
IF OBJECT_ID('metric_recovery_rate','V') IS NOT NULL DROP VIEW metric_recovery_rate;
GO
CREATE VIEW metric_recovery_rate AS
SELECT
  (SELECT COUNT(DISTINCT account_id) FROM fact_payment WHERE is_recovery=1) AS paying_accounts,
  (SELECT COUNT(*) FROM dim_account)                                        AS total_accounts,
  ROUND(100.0*(SELECT COUNT(DISTINCT account_id) FROM fact_payment WHERE is_recovery=1)
        /(SELECT COUNT(*) FROM dim_account),1)                              AS recovery_rate_pct;
GO

/* ========================= ANALYTICAL QUERIES ============================= */

/* ---- WHY: recovery by risk segment ---- */
IF OBJECT_ID('analysis_recovery_by_risk','V') IS NOT NULL DROP VIEW analysis_recovery_by_risk;
GO
CREATE VIEW analysis_recovery_by_risk AS
SELECT a.risk_segment,
       COUNT(DISTINCT p.account_id)      AS paying_accounts,
       ROUND(SUM(p.amount)/10000000.0,2) AS recovery_cr
FROM fact_payment p JOIN dim_account a ON p.account_id=a.account_id
WHERE p.is_recovery=1
GROUP BY a.risk_segment;
GO

/* ---- WHY: recovery by loan type ---- */
IF OBJECT_ID('analysis_recovery_by_loan_type','V') IS NOT NULL DROP VIEW analysis_recovery_by_loan_type;
GO
CREATE VIEW analysis_recovery_by_loan_type AS
SELECT a.loan_type,
       COUNT(DISTINCT p.account_id)      AS paying_accounts,
       ROUND(SUM(p.amount)/10000000.0,2) AS recovery_cr
FROM fact_payment p JOIN dim_account a ON p.account_id=a.account_id
WHERE p.is_recovery=1
GROUP BY a.loan_type;
GO

/* ---- CHANNEL conversion: PTP source -> which channel produces kept promises ---- */
IF OBJECT_ID('analysis_channel_conversion','V') IS NOT NULL DROP VIEW analysis_channel_conversion;
GO
CREATE VIEW analysis_channel_conversion AS
SELECT source AS channel,
       COUNT(*)                                          AS promises,
       SUM(kept_verified)                                AS kept_verified,
       ROUND(100.0*SUM(kept_verified)/COUNT(*),1)        AS kept_rate_pct
FROM fact_ptp
GROUP BY source;
GO

/* ---- SURVIVORSHIP: collectible population per month (point-in-time) ---- */
IF OBJECT_ID('analysis_survivorship','V') IS NOT NULL DROP VIEW analysis_survivorship;
GO
CREATE VIEW analysis_survivorship AS
WITH months AS (
  SELECT CAST('2026-01-31' AS date) m_end UNION ALL SELECT '2026-02-28' UNION ALL
  SELECT '2026-03-31' UNION ALL SELECT '2026-04-30' UNION ALL SELECT '2026-05-31' UNION ALL
  SELECT '2026-06-30' UNION ALL SELECT '2026-07-31'
),
pit AS (
  SELECT m.m_end, h.account_id, h.[status],
         ROW_NUMBER() OVER (PARTITION BY m.m_end, h.account_id ORDER BY h.event_ist DESC) rn
  FROM months m JOIN fact_status_history h ON h.event_ist <= m.m_end
)
SELECT m_end,
       COUNT(*) AS tracked,
       SUM(CASE WHEN [status] IN ('ACTIVE','DELINQUENT','PTP','NPA') THEN 1 ELSE 0 END) AS collectible,
       ROUND(100.0*SUM(CASE WHEN [status] IN ('ACTIVE','DELINQUENT','PTP','NPA') THEN 1 ELSE 0 END)/COUNT(*),1) AS collectible_pct
FROM pit WHERE rn=1
GROUP BY m_end;
GO

/* ---- COST per Rs recovered by channel (uses simple per-touch cost assumptions) ---- */
IF OBJECT_ID('analysis_cost_per_recovery','V') IS NOT NULL DROP VIEW analysis_cost_per_recovery;
GO
CREATE VIEW analysis_cost_per_recovery AS
/* touch costs (illustrative): call Rs 5, whatsapp Rs 1, sms Rs 0.5, field Rs 200 */
SELECT 'CALL'  AS channel, (SELECT COUNT(*) FROM fact_call)*5.0     AS est_cost UNION ALL
SELECT 'WHATSAPP', (SELECT COUNT(*) FROM fact_whatsapp)*1.0 UNION ALL
SELECT 'SMS', (SELECT COUNT(*) FROM fact_sms)*0.5 UNION ALL
SELECT 'FIELD', (SELECT COUNT(*) FROM fact_field_visit)*200.0;
GO
