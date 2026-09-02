/* ============================================================================
   00_load_csvs.sql   |   SQL SERVER — LOAD ALL 17 CSVs (full paths, no variable)
   ============================================================================
   Creates the 17 stg_ tables and BULK INSERTs each CSV using its full path.
   Run FIRST, then 00b_typed_staging.sql, then sqlserver_pipeline.sql.

   If BULK INSERT throws "Access is denied (error code 5)", SQL Server's service
   account cannot read Downloads. Copy the 17 CSVs to C:\collections\ and
   Find-and-Replace  C:\Users\Dell\Downloads\collections_30k_dataset (1)
   with  C:\collections  in this file.

   All columns load as NVARCHAR (safe on messy data); 00b_typed_staging.sql
   converts them to proper types afterward.
   ============================================================================ */

/* 1. accounts */
IF OBJECT_ID('stg_accounts','U') IS NOT NULL DROP TABLE stg_accounts;
CREATE TABLE stg_accounts(account_id NVARCHAR(50),borrower_id NVARCHAR(50),loan_type NVARCHAR(50),
 principal_amount NVARCHAR(50),outstanding_amount NVARCHAR(50),dpd NVARCHAR(50),risk_segment NVARCHAR(50),
 [status] NVARCHAR(50),opened_at NVARCHAR(50),timezone NVARCHAR(50),schema_version NVARCHAR(50));
BULK INSERT stg_accounts FROM 'C:\Users\Dell\Downloads\collections_30k_dataset (1)\accounts.csv'
WITH (FIRSTROW=2, FORMAT='CSV', FIELDQUOTE='"', ROWTERMINATOR='0x0a', TABLOCK);

/* 2. borrowers */
IF OBJECT_ID('stg_borrowers','U') IS NOT NULL DROP TABLE stg_borrowers;
CREATE TABLE stg_borrowers(borrower_id NVARCHAR(50),name NVARCHAR(200),phone NVARCHAR(50),email NVARCHAR(200),
 city NVARCHAR(100),created_at NVARCHAR(50),updated_at NVARCHAR(50),state NVARCHAR(100));
BULK INSERT stg_borrowers FROM 'C:\Users\Dell\Downloads\collections_30k_dataset (1)\borrowers.csv'
WITH (FIRSTROW=2, FORMAT='CSV', FIELDQUOTE='"', ROWTERMINATOR='0x0a', TABLOCK);

/* 3. agents */
IF OBJECT_ID('stg_agents','U') IS NOT NULL DROP TABLE stg_agents;
CREATE TABLE stg_agents(agent_id NVARCHAR(50),employee_code NVARCHAR(50),agent_name NVARCHAR(200),
 vendor_id NVARCHAR(50),team NVARCHAR(50),[status] NVARCHAR(50),joined_at NVARCHAR(50),updated_at NVARCHAR(50));
BULK INSERT stg_agents FROM 'C:\Users\Dell\Downloads\collections_30k_dataset (1)\agents.csv'
WITH (FIRSTROW=2, FORMAT='CSV', FIELDQUOTE='"', ROWTERMINATOR='0x0a', TABLOCK);

/* 4. agent_sessions */
IF OBJECT_ID('stg_agent_sessions','U') IS NOT NULL DROP TABLE stg_agent_sessions;
CREATE TABLE stg_agent_sessions(session_id NVARCHAR(50),agent_id NVARCHAR(50),login_at NVARCHAR(50),
 channel NVARCHAR(50),device_id NVARCHAR(50),timezone NVARCHAR(50),logout_at NVARCHAR(50));
BULK INSERT stg_agent_sessions FROM 'C:\Users\Dell\Downloads\collections_30k_dataset (1)\agent_sessions.csv'
WITH (FIRSTROW=2, FORMAT='CSV', FIELDQUOTE='"', ROWTERMINATOR='0x0a', TABLOCK);

/* 5. campaigns */
IF OBJECT_ID('stg_campaigns','U') IS NOT NULL DROP TABLE stg_campaigns;
CREATE TABLE stg_campaigns(campaign_id NVARCHAR(50),campaign_name NVARCHAR(100),channel NVARCHAR(50),
 strategy_version NVARCHAR(50),start_at NVARCHAR(50),target_definition NVARCHAR(100),end_at NVARCHAR(50));
BULK INSERT stg_campaigns FROM 'C:\Users\Dell\Downloads\collections_30k_dataset (1)\campaigns.csv'
WITH (FIRSTROW=2, FORMAT='CSV', FIELDQUOTE='"', ROWTERMINATOR='0x0a', TABLOCK);

/* 6. daily_targeting */
IF OBJECT_ID('stg_daily_targeting','U') IS NOT NULL DROP TABLE stg_daily_targeting;
CREATE TABLE stg_daily_targeting(target_id NVARCHAR(50),account_id NVARCHAR(50),campaign_id NVARCHAR(50),
 target_date NVARCHAR(50),priority NVARCHAR(50),recommended_channel NVARCHAR(50),[status] NVARCHAR(50));
BULK INSERT stg_daily_targeting FROM 'C:\Users\Dell\Downloads\collections_30k_dataset (1)\daily_targeting.csv'
WITH (FIRSTROW=2, FORMAT='CSV', FIELDQUOTE='"', ROWTERMINATOR='0x0a', TABLOCK);

/* 7. calls */
IF OBJECT_ID('stg_calls','U') IS NOT NULL DROP TABLE stg_calls;
CREATE TABLE stg_calls(call_id NVARCHAR(50),account_id NVARCHAR(50),borrower_id NVARCHAR(50),event_at NVARCHAR(50),
 agent_id NVARCHAR(50),campaign_id NVARCHAR(50),direction NVARCHAR(50),vendor_id NVARCHAR(50),
 call_status NVARCHAR(50),duration_sec NVARCHAR(50),timezone NVARCHAR(50));
BULK INSERT stg_calls FROM 'C:\Users\Dell\Downloads\collections_30k_dataset (1)\calls.csv'
WITH (FIRSTROW=2, FORMAT='CSV', FIELDQUOTE='"', ROWTERMINATOR='0x0a', TABLOCK);

/* 8. call_attempts */
IF OBJECT_ID('stg_call_attempts','U') IS NOT NULL DROP TABLE stg_call_attempts;
CREATE TABLE stg_call_attempts(attempt_id NVARCHAR(50),account_id NVARCHAR(50),borrower_id NVARCHAR(50),
 event_at NVARCHAR(50),call_id NVARCHAR(50),agent_id NVARCHAR(50),attempt_no NVARCHAR(50),
 vendor_id NVARCHAR(50),attempt_status NVARCHAR(50));
BULK INSERT stg_call_attempts FROM 'C:\Users\Dell\Downloads\collections_30k_dataset (1)\call_attempts.csv'
WITH (FIRSTROW=2, FORMAT='CSV', FIELDQUOTE='"', ROWTERMINATOR='0x0a', TABLOCK);

/* 9. call_dispositions */
IF OBJECT_ID('stg_call_dispositions','U') IS NOT NULL DROP TABLE stg_call_dispositions;
CREATE TABLE stg_call_dispositions(disposition_id NVARCHAR(50),account_id NVARCHAR(50),borrower_id NVARCHAR(50),
 event_at NVARCHAR(50),call_id NVARCHAR(50),agent_id NVARCHAR(50),disposition_code NVARCHAR(50),disposition_version NVARCHAR(50));
BULK INSERT stg_call_dispositions FROM 'C:\Users\Dell\Downloads\collections_30k_dataset (1)\call_dispositions.csv'
WITH (FIRSTROW=2, FORMAT='CSV', FIELDQUOTE='"', ROWTERMINATOR='0x0a', TABLOCK);

/* 10. whatsapp_events */
IF OBJECT_ID('stg_whatsapp','U') IS NOT NULL DROP TABLE stg_whatsapp;
CREATE TABLE stg_whatsapp(whatsapp_event_id NVARCHAR(50),account_id NVARCHAR(50),borrower_id NVARCHAR(50),
 event_at NVARCHAR(50),message_id NVARCHAR(50),event_type NVARCHAR(50),template_code NVARCHAR(50),provider_id NVARCHAR(50));
BULK INSERT stg_whatsapp FROM 'C:\Users\Dell\Downloads\collections_30k_dataset (1)\whatsapp_events.csv'
WITH (FIRSTROW=2, FORMAT='CSV', FIELDQUOTE='"', ROWTERMINATOR='0x0a', TABLOCK);

/* 11. sms_events */
IF OBJECT_ID('stg_sms','U') IS NOT NULL DROP TABLE stg_sms;
CREATE TABLE stg_sms(sms_event_id NVARCHAR(50),account_id NVARCHAR(50),borrower_id NVARCHAR(50),
 event_at NVARCHAR(50),message_id NVARCHAR(50),event_type NVARCHAR(50),template_code NVARCHAR(50),provider_id NVARCHAR(50));
BULK INSERT stg_sms FROM 'C:\Users\Dell\Downloads\collections_30k_dataset (1)\sms_events.csv'
WITH (FIRSTROW=2, FORMAT='CSV', FIELDQUOTE='"', ROWTERMINATOR='0x0a', TABLOCK);

/* 12. field_visits */
IF OBJECT_ID('stg_field_visits','U') IS NOT NULL DROP TABLE stg_field_visits;
CREATE TABLE stg_field_visits(visit_id NVARCHAR(50),account_id NVARCHAR(50),borrower_id NVARCHAR(50),
 event_at NVARCHAR(50),agent_id NVARCHAR(50),visit_type NVARCHAR(50),outcome NVARCHAR(50),
 latitude NVARCHAR(50),longitude NVARCHAR(50),scheduled_at NVARCHAR(50));
BULK INSERT stg_field_visits FROM 'C:\Users\Dell\Downloads\collections_30k_dataset (1)\field_visits.csv'
WITH (FIRSTROW=2, FORMAT='CSV', FIELDQUOTE='"', ROWTERMINATOR='0x0a', TABLOCK);

/* 13. promises_to_pay */
IF OBJECT_ID('stg_promises_to_pay','U') IS NOT NULL DROP TABLE stg_promises_to_pay;
CREATE TABLE stg_promises_to_pay(ptp_id NVARCHAR(50),account_id NVARCHAR(50),borrower_id NVARCHAR(50),
 event_at NVARCHAR(50),agent_id NVARCHAR(50),promised_amount NVARCHAR(50),promised_date NVARCHAR(50),
 [status] NVARCHAR(50),source NVARCHAR(50));
BULK INSERT stg_promises_to_pay FROM 'C:\Users\Dell\Downloads\collections_30k_dataset (1)\promises_to_pay.csv'
WITH (FIRSTROW=2, FORMAT='CSV', FIELDQUOTE='"', ROWTERMINATOR='0x0a', TABLOCK);

/* 14. payments */
IF OBJECT_ID('stg_payments','U') IS NOT NULL DROP TABLE stg_payments;
CREATE TABLE stg_payments(payment_id NVARCHAR(50),account_id NVARCHAR(50),borrower_id NVARCHAR(50),
 event_at NVARCHAR(50),payment_reference NVARCHAR(100),amount NVARCHAR(50),payment_status NVARCHAR(50),
 payment_method NVARCHAR(50),provider_id NVARCHAR(50));
BULK INSERT stg_payments FROM 'C:\Users\Dell\Downloads\collections_30k_dataset (1)\payments.csv'
WITH (FIRSTROW=2, FORMAT='CSV', FIELDQUOTE='"', ROWTERMINATOR='0x0a', TABLOCK);

/* 15. vendor_telephony */
IF OBJECT_ID('stg_vendor','U') IS NOT NULL DROP TABLE stg_vendor;
CREATE TABLE stg_vendor(vendor_id NVARCHAR(50),vendor_name NVARCHAR(100),vendor_account_id NVARCHAR(50),
 timezone NVARCHAR(50),[status] NVARCHAR(50),schema_version NVARCHAR(50));
BULK INSERT stg_vendor FROM 'C:\Users\Dell\Downloads\collections_30k_dataset (1)\vendor_telephony.csv'
WITH (FIRSTROW=2, FORMAT='CSV', FIELDQUOTE='"', ROWTERMINATOR='0x0a', TABLOCK);

/* 16. complaints */
IF OBJECT_ID('stg_complaints','U') IS NOT NULL DROP TABLE stg_complaints;
CREATE TABLE stg_complaints(complaint_id NVARCHAR(50),account_id NVARCHAR(50),borrower_id NVARCHAR(50),
 event_at NVARCHAR(50),complaint_type NVARCHAR(50),severity NVARCHAR(50),[status] NVARCHAR(50),
 source NVARCHAR(50),resolution_at NVARCHAR(50));
BULK INSERT stg_complaints FROM 'C:\Users\Dell\Downloads\collections_30k_dataset (1)\complaints.csv'
WITH (FIRSTROW=2, FORMAT='CSV', FIELDQUOTE='"', ROWTERMINATOR='0x0a', TABLOCK);

/* 17. account_status_history */
IF OBJECT_ID('stg_status_history','U') IS NOT NULL DROP TABLE stg_status_history;
CREATE TABLE stg_status_history(history_id NVARCHAR(50),account_id NVARCHAR(50),borrower_id NVARCHAR(50),
 event_at NVARCHAR(50),[status] NVARCHAR(50),changed_by NVARCHAR(50),source NVARCHAR(50),recorded_at NVARCHAR(50));
BULK INSERT stg_status_history FROM 'C:\Users\Dell\Downloads\collections_30k_dataset (1)\account_status_history.csv'
WITH (FIRSTROW=2, FORMAT='CSV', FIELDQUOTE='"', ROWTERMINATOR='0x0a', TABLOCK);

/* ---- confirm row counts (expect accounts 30000, payments 25500, calls 91351) ---- */
SELECT 'stg_accounts' t, COUNT(*) rows FROM stg_accounts
UNION ALL SELECT 'stg_borrowers', COUNT(*) FROM stg_borrowers
UNION ALL SELECT 'stg_agents', COUNT(*) FROM stg_agents
UNION ALL SELECT 'stg_agent_sessions', COUNT(*) FROM stg_agent_sessions
UNION ALL SELECT 'stg_campaigns', COUNT(*) FROM stg_campaigns
UNION ALL SELECT 'stg_daily_targeting', COUNT(*) FROM stg_daily_targeting
UNION ALL SELECT 'stg_calls', COUNT(*) FROM stg_calls
UNION ALL SELECT 'stg_call_attempts', COUNT(*) FROM stg_call_attempts
UNION ALL SELECT 'stg_call_dispositions', COUNT(*) FROM stg_call_dispositions
UNION ALL SELECT 'stg_whatsapp', COUNT(*) FROM stg_whatsapp
UNION ALL SELECT 'stg_sms', COUNT(*) FROM stg_sms
UNION ALL SELECT 'stg_field_visits', COUNT(*) FROM stg_field_visits
UNION ALL SELECT 'stg_promises_to_pay', COUNT(*) FROM stg_promises_to_pay
UNION ALL SELECT 'stg_payments', COUNT(*) FROM stg_payments
UNION ALL SELECT 'stg_vendor', COUNT(*) FROM stg_vendor
UNION ALL SELECT 'stg_complaints', COUNT(*) FROM stg_complaints
UNION ALL SELECT 'stg_status_history', COUNT(*) FROM stg_status_history;
