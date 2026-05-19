-- ================================================================================
-- COMMUNICATION LOGS TABLE – v1.2 (FIXED)
-- Database: koshiv_bus_booking
-- Author: Koushal Jha
-- Date: May 2026
-- Project: KOSHIV BUS BOOKING SYSTEM
-- Compliance: IT Act 2000, Indian Financial Regulations, Legal Audit, Customer Communication Log
-- ================================================================================
-- VERSION HISTORY:
-- v1.0 (May 2026) – Initial release
-- v1.1 (May 2026) – Added template_id, attempt_source_ip, request_id, retry_count CHECK
-- v1.2 (May 2026) – REMOVED foreign key to users (different database - koshiv_bus_user)
--                    Kept foreign key only to bookings (same database)
--                    Application must validate user_id existence
-- ================================================================================

-- ================================================================================
-- CREATE COMMUNICATION LOGS TABLE
-- ================================================================================

CREATE TABLE IF NOT EXISTS communication_logs (
    log_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_id UUID,
    user_id UUID NOT NULL,
    template_id TEXT NOT NULL,
    communication_type TEXT NOT NULL,
    recipient TEXT NOT NULL,
    subject TEXT,
    content_snippet TEXT,
    delivery_status TEXT NOT NULL DEFAULT 'queued',
    provider TEXT NOT NULL,
    provider_message_id TEXT,
    sent_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    delivered_at TIMESTAMPTZ,
    failure_reason TEXT,
    retry_count INTEGER NOT NULL DEFAULT 0,
    attempt_source_ip INET,
    request_id TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Constraints
    CONSTRAINT communication_type_check CHECK (communication_type IN ('email', 'sms')),
    CONSTRAINT delivery_status_check CHECK (delivery_status IN ('queued', 'sent', 'delivered', 'failed', 'bounced')),
    CONSTRAINT delivery_time_check CHECK (sent_at <= delivered_at OR delivered_at IS NULL),
    CONSTRAINT retry_count_check CHECK (retry_count BETWEEN 0 AND 5)
);

-- ================================================================================
-- FOREIGN KEY (Only to bookings – same database)
-- ================================================================================

ALTER TABLE communication_logs DROP CONSTRAINT IF EXISTS fk_communication_logs_booking;
ALTER TABLE communication_logs ADD CONSTRAINT fk_communication_logs_booking
    FOREIGN KEY (booking_id) REFERENCES bookings(booking_id) ON DELETE SET NULL;

-- ================================================================================
-- NO FOREIGN KEY TO users TABLE
-- ================================================================================
-- users table is in different database (koshiv_bus_user)
-- Foreign keys cannot reference tables across different databases
-- Application code MUST validate user_id exists before inserting
-- ================================================================================

-- ================================================================================
-- TABLE COMMENTS
-- ================================================================================

COMMENT ON TABLE communication_logs IS 'Stores all outbound customer communications (email and SMS) related to bookings - required for legal compliance, customer support, delivery tracking, and anti-abuse rate limiting';
COMMENT ON COLUMN communication_logs.log_id IS 'Unique identifier for each communication event';
COMMENT ON COLUMN communication_logs.booking_id IS 'References bookings(booking_id) - NULL for non-booking communications';
COMMENT ON COLUMN communication_logs.user_id IS 'References users.user_id from koshiv_bus_user database - NO FK (different DB) - application must validate';
COMMENT ON COLUMN communication_logs.template_id IS 'Exact template name used (e.g., booking_confirmation_email_v2) - critical for legal audit';
COMMENT ON COLUMN communication_logs.communication_type IS 'email or sms';
COMMENT ON COLUMN communication_logs.recipient IS 'Email address or mobile number with country code';
COMMENT ON COLUMN communication_logs.subject IS 'Email subject line (NULL for sms)';
COMMENT ON COLUMN communication_logs.content_snippet IS 'Preview: first 200 characters of rendered message - optional';
COMMENT ON COLUMN communication_logs.delivery_status IS 'queued, sent, delivered, failed, bounced';
COMMENT ON COLUMN communication_logs.provider IS 'twilio, msg91, textlocal, aws_ses, etc.';
COMMENT ON COLUMN communication_logs.provider_message_id IS 'Unique ID returned by provider - for tracking and refunds';
COMMENT ON COLUMN communication_logs.sent_at IS 'When the message was sent (or attempted)';
COMMENT ON COLUMN communication_logs.delivered_at IS 'When provider confirmed delivery';
COMMENT ON COLUMN communication_logs.failure_reason IS 'Error message or reason for failure';
COMMENT ON COLUMN communication_logs.retry_count IS 'Number of retry attempts - max 5';
COMMENT ON COLUMN communication_logs.attempt_source_ip IS 'IP address that initiated the resend or triggered this communication - for anti-abuse';
COMMENT ON COLUMN communication_logs.request_id IS 'Correlation ID from API gateway - links to request logs';
COMMENT ON COLUMN communication_logs.created_at IS 'When the record was inserted';
COMMENT ON COLUMN communication_logs.updated_at IS 'Last update (e.g., status change)';

-- ================================================================================
-- CREATE INDEXES
-- ================================================================================

CREATE INDEX IF NOT EXISTS idx_comm_booking ON communication_logs(booking_id);
CREATE INDEX IF NOT EXISTS idx_comm_user ON communication_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_comm_delivery_status ON communication_logs(delivery_status);
CREATE INDEX IF NOT EXISTS idx_comm_sent_at ON communication_logs(sent_at);
CREATE INDEX IF NOT EXISTS idx_comm_provider_message_id ON communication_logs(provider_message_id);
CREATE INDEX IF NOT EXISTS idx_comm_request_id ON communication_logs(request_id);

-- ================================================================================
-- OPTIONAL PARTIAL UNIQUE INDEX (if provider guarantees uniqueness)
-- ================================================================================

-- CREATE UNIQUE INDEX IF NOT EXISTS idx_comm_provider_unique ON communication_logs (provider, provider_message_id) 
--     WHERE provider_message_id IS NOT NULL;

-- ================================================================================
-- TRIGGER FUNCTION FOR UPDATED_AT
-- ================================================================================

CREATE OR REPLACE FUNCTION trigger_comm_update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- ================================================================================
-- CREATE TRIGGER
-- ================================================================================

DROP TRIGGER IF EXISTS trg_comm_update_updated_at ON communication_logs;
CREATE TRIGGER trg_comm_update_updated_at
    BEFORE UPDATE ON communication_logs
    FOR EACH ROW
    EXECUTE FUNCTION trigger_comm_update_updated_at();