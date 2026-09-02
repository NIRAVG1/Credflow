/*
   00b_typed_staging.sql   |   SQL SERVER — TYPE THE LOADED TEXT

   00_load_csvs.sql loaded everything as NVARCHAR (safe for messy data).
   This script wraps each stg_ table in a typed VIEW (stg_<t>_t) that TRY_CASTs
   text -> proper number/datetime. TRY_CAST returns NULL on bad values instead
   of erroring, so dirty cells become NULL (which the pipeline already handles).*/

/* We rebuild each stg_ table as a typed view. Drop the text table's name clash
   by creating *_typed views and a thin rename via synonym-free approach:
   simplest = create typed VIEWs named stg_<t>_typed and edit pipeline to use them.
   To avoid editing the pipeline, we instead SELECT ... INTO typed tables that
   REPLACE the text ones. */

-- ACCOUNTS
IF OBJECT_ID('stg_accounts_typed','U') IS NOT NULL DROP TABLE stg_accounts_typed;
SELECT account_id, borrower_id, loan_type,
       TRY_CAST(principal_amount   AS float)    AS principal_amount,
       TRY_CAST(outstanding_amount AS float)    AS outstanding_amount,
       TRY_CAST(dpd                AS int)      AS dpd,
       risk_segment, [status],
       TRY_CAST(opened_at AS datetime2)         AS opened_at,
       timezone, schema_version
INTO stg_accounts_typed FROM stg_accounts;
DROP TABLE stg_accounts; EXEC sp_rename 'stg_accounts_typed','stg_accounts';
GO
--BORROWERS
IF OBJECT_ID('stg_borrowers_typed','U') IS NOT NULL DROP TABLE stg_borrowers_typed;
SELECT borrower_id, name, phone, email, city, state,
       TRY_CAST(created_at AS datetime2) AS created_at,
       TRY_CAST(updated_at AS datetime2) AS updated_at
INTO stg_borrowers_typed FROM stg_borrowers;
DROP TABLE stg_borrowers; EXEC sp_rename 'stg_borrowers_typed','stg_borrowers';
GO

-- AGENTS 
IF OBJECT_ID('stg_agents_typed','U') IS NOT NULL DROP TABLE stg_agents_typed;
SELECT agent_id, employee_code, agent_name, vendor_id, team, [status],
       TRY_CAST(joined_at  AS datetime2) AS joined_at,
       TRY_CAST(updated_at AS datetime2) AS updated_at
INTO stg_agents_typed FROM stg_agents;
DROP TABLE stg_agents; EXEC sp_rename 'stg_agents_typed','stg_agents';
GO

-- AGENT SESSIONS
IF OBJECT_ID('stg_agent_sessions_typed','U') IS NOT NULL DROP TABLE stg_agent_sessions_typed;
SELECT session_id, agent_id,
       TRY_CAST(login_at  AS datetime2) AS login_at, channel, device_id, timezone,
       TRY_CAST(logout_at AS datetime2) AS logout_at
INTO stg_agent_sessions_typed FROM stg_agent_sessions;
DROP TABLE stg_agent_sessions; EXEC sp_rename 'stg_agent_sessions_typed','stg_agent_sessions';
GO

-- CAMPAIGNS
IF OBJECT_ID('stg_campaigns_typed','U') IS NOT NULL DROP TABLE stg_campaigns_typed;
SELECT campaign_id, campaign_name, channel, strategy_version,
       TRY_CAST(start_at AS datetime2) AS start_at, target_definition,
       TRY_CAST(end_at   AS datetime2) AS end_at
INTO stg_campaigns_typed FROM stg_campaigns;
DROP TABLE stg_campaigns; EXEC sp_rename 'stg_campaigns_typed','stg_campaigns';
GO
-- DAILY TARGETING 
IF OBJECT_ID('stg_daily_targeting_typed','U') IS NOT NULL DROP TABLE stg_daily_targeting_typed;
SELECT target_id, account_id, campaign_id,
       TRY_CAST(target_date AS datetime2) AS target_date,
       TRY_CAST(priority AS int) AS priority, recommended_channel, [status]
INTO stg_daily_targeting_typed FROM stg_daily_targeting;
DROP TABLE stg_daily_targeting; EXEC sp_rename 'stg_daily_targeting_typed','stg_daily_targeting';
GO

-- CALLS
IF OBJECT_ID('stg_calls_typed','U') IS NOT NULL DROP TABLE stg_calls_typed;
SELECT call_id, account_id, borrower_id,
       TRY_CAST(event_at AS datetime2) AS event_at, agent_id, campaign_id, direction, vendor_id,
       call_status, TRY_CAST(duration_sec AS int) AS duration_sec, timezone
INTO stg_calls_typed FROM stg_calls;
DROP TABLE stg_calls; EXEC sp_rename 'stg_calls_typed','stg_calls';
GO

-- CALL ATTEMPTS
IF OBJECT_ID('stg_call_attempts_typed','U') IS NOT NULL DROP TABLE stg_call_attempts_typed;
SELECT attempt_id, account_id, borrower_id,
       TRY_CAST(event_at AS datetime2) AS event_at, call_id, agent_id,
       TRY_CAST(attempt_no AS int) AS attempt_no, vendor_id, attempt_status
INTO stg_call_attempts_typed FROM stg_call_attempts;
DROP TABLE stg_call_attempts; EXEC sp_rename 'stg_call_attempts_typed','stg_call_attempts';
GO

-- CALL DISPOSITIONS 
IF OBJECT_ID('stg_call_dispositions_typed','U') IS NOT NULL DROP TABLE stg_call_dispositions_typed;
SELECT disposition_id, account_id, borrower_id,
       TRY_CAST(event_at AS datetime2) AS event_at, call_id, agent_id, disposition_code, disposition_version
INTO stg_call_dispositions_typed FROM stg_call_dispositions;
DROP TABLE stg_call_dispositions; EXEC sp_rename 'stg_call_dispositions_typed','stg_call_dispositions';
GO

-- WHATSAPP
IF OBJECT_ID('stg_whatsapp_typed','U') IS NOT NULL DROP TABLE stg_whatsapp_typed;
SELECT whatsapp_event_id, account_id, borrower_id,
       TRY_CAST(event_at AS datetime2) AS event_at, message_id, event_type, template_code, provider_id
INTO stg_whatsapp_typed FROM stg_whatsapp;
DROP TABLE stg_whatsapp; EXEC sp_rename 'stg_whatsapp_typed','stg_whatsapp';
GO
-- SMS 
IF OBJECT_ID('stg_sms_typed','U') IS NOT NULL DROP TABLE stg_sms_typed;
SELECT sms_event_id, account_id, borrower_id,
       TRY_CAST(event_at AS datetime2) AS event_at, message_id, event_type, template_code, provider_id
INTO stg_sms_typed FROM stg_sms;
DROP TABLE stg_sms; EXEC sp_rename 'stg_sms_typed','stg_sms';
GO
-- FIELD VISITS 
IF OBJECT_ID('stg_field_visits_typed','U') IS NOT NULL DROP TABLE stg_field_visits_typed;
SELECT visit_id, account_id, borrower_id,
       TRY_CAST(event_at AS datetime2) AS event_at, agent_id, visit_type, outcome,
       TRY_CAST(latitude AS float) AS latitude, TRY_CAST(longitude AS float) AS longitude,
       TRY_CAST(scheduled_at AS datetime2) AS scheduled_at
INTO stg_field_visits_typed FROM stg_field_visits;
DROP TABLE stg_field_visits; EXEC sp_rename 'stg_field_visits_typed','stg_field_visits';
GO
-- PROMISES TO PAY
IF OBJECT_ID('stg_promises_to_pay_typed','U') IS NOT NULL DROP TABLE stg_promises_to_pay_typed;
SELECT ptp_id, account_id, borrower_id,
       TRY_CAST(event_at AS datetime2) AS event_at, agent_id,
       TRY_CAST(promised_amount AS float) AS promised_amount,
       TRY_CAST(promised_date AS datetime2) AS promised_date, [status], source
INTO stg_promises_to_pay_typed FROM stg_promises_to_pay;
DROP TABLE stg_promises_to_pay; EXEC sp_rename 'stg_promises_to_pay_typed','stg_promises_to_pay';
GO
-- PAYMENTS
IF OBJECT_ID('stg_payments_typed','U') IS NOT NULL DROP TABLE stg_payments_typed;
SELECT payment_id, account_id, borrower_id,
       TRY_CAST(event_at AS datetime2) AS event_at, payment_reference,
       TRY_CAST(amount AS float) AS amount, payment_status, payment_method, provider_id
INTO stg_payments_typed FROM stg_payments;
DROP TABLE stg_payments; EXEC sp_rename 'stg_payments_typed','stg_payments';
GO
-- VENDOR 
IF OBJECT_ID('stg_vendor_typed','U') IS NOT NULL DROP TABLE stg_vendor_typed;
SELECT vendor_id, vendor_name, vendor_account_id, timezone, [status], schema_version
INTO stg_vendor_typed FROM stg_vendor;
DROP TABLE stg_vendor; EXEC sp_rename 'stg_vendor_typed','stg_vendor';
GO

-- COMPLAINTS
IF OBJECT_ID('stg_complaints_typed','U') IS NOT NULL DROP TABLE stg_complaints_typed;
SELECT complaint_id, account_id, borrower_id,
       TRY_CAST(event_at AS datetime2) AS event_at, complaint_type, severity, [status], source,
       TRY_CAST(resolution_at AS datetime2) AS resolution_at
INTO stg_complaints_typed FROM stg_complaints;
DROP TABLE stg_complaints; EXEC sp_rename 'stg_complaints_typed','stg_complaints';
GO

-- STATUS HISTORY 
IF OBJECT_ID('stg_status_history_typed','U') IS NOT NULL DROP TABLE stg_status_history_typed;
SELECT history_id, account_id, borrower_id,
       TRY_CAST(event_at AS datetime2) AS event_at, [status], changed_by, source,
       TRY_CAST(recorded_at AS datetime2) AS recorded_at
INTO stg_status_history_typed FROM stg_status_history;
DROP TABLE stg_status_history; EXEC sp_rename 'stg_status_history_typed','stg_status_history';
GO

PRINT 'Typed staging ready. Now run sqlserver_pipeline.sql';
GO
