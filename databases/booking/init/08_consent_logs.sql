-- ================================================================================
-- CONSENT LOGS TABLE – v1.2 (FIXED)
-- Database: koshiv_bus_booking
-- Author: Koushal Jha
-- Date: May 2026
-- Project: KOSHIV BUS BOOKING SYSTEM
-- Compliance: IT Act 2000, GDPR, Consumer Protection Laws, TRAI (India)
-- ================================================================================
-- VERSION HISTORY:
-- v1.0 (May 2026) – Initial release
-- v1.1 (May 2026) – Added BEFORE UPDATE trigger for immutability, document_hash column,
--                    composite index for latest-status queries
-- v1.2 (May 2026) – Removed redundant is_revoked and revoked_at columns
--                    REMOVED foreign key to users (different database - koshiv_bus_user)
--                    Application must validate user_id existence
-- ================================================================================

-- ================================================================================
-- CREATE CONSENT LOGS TABLE
-- ================================================================================

CREATE TABLE IF NOT EXISTS consent_logs (
    consent_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    consent_type TEXT NOT NULL,
    consent_version TEXT NOT NULL,
    document_hash TEXT,
    consent_given BOOLEAN NOT NULL,
    ip_address INET,
    user_agent TEXT,
    timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    notes TEXT,
    
    -- Constraints
    CONSTRAINT consent_type_check CHECK (
        consent_type IN (
            'terms_of_service', 
            'privacy_policy', 
            'marketing_sms', 
            'marketing_email', 
            'data_sharing'
        )
    )
);

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

COMMENT ON TABLE consent_logs IS 'Records user consents for legal compliance - IT Act 2000, GDPR, consumer protection laws. Append-only, immutable table.';
COMMENT ON COLUMN consent_logs.consent_id IS 'Unique identifier for each consent record';
COMMENT ON COLUMN consent_logs.user_id IS 'References users.user_id from koshiv_bus_user database - NO FK (different DB) - application must validate';
COMMENT ON COLUMN consent_logs.consent_type IS 'terms_of_service, privacy_policy, marketing_sms, marketing_email, data_sharing';
COMMENT ON COLUMN consent_logs.consent_version IS 'Version string of the document (e.g., v1.0, v2.1)';
COMMENT ON COLUMN consent_logs.document_hash IS 'SHA-256 hash of exact legal document text - cryptographic proof';
COMMENT ON COLUMN consent_logs.consent_given IS 'TRUE = accepted, FALSE = revoked/not given';
COMMENT ON COLUMN consent_logs.ip_address IS 'IP address from which consent action originated';
COMMENT ON COLUMN consent_logs.user_agent IS 'Browser/device information for legal proof';
COMMENT ON COLUMN consent_logs.timestamp IS 'When the consent action occurred';
COMMENT ON COLUMN consent_logs.notes IS 'Optional internal notes (e.g., reason for manual override)';

-- ================================================================================
-- CREATE INDEXES
-- ================================================================================

CREATE INDEX IF NOT EXISTS idx_consent_user_type ON consent_logs(user_id, consent_type);
CREATE INDEX IF NOT EXISTS idx_consent_timestamp ON consent_logs(timestamp);
CREATE INDEX IF NOT EXISTS idx_consent_version ON consent_logs(consent_version);
CREATE INDEX IF NOT EXISTS idx_consent_user_type_time ON consent_logs(user_id, consent_type, timestamp DESC);

-- ================================================================================
-- TRIGGER FUNCTION FOR IMMUTABILITY (Prevent UPDATE)
-- ================================================================================

CREATE OR REPLACE FUNCTION prevent_consent_update()
RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION 'consent_logs is append-only; UPDATE not allowed';
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- ================================================================================
-- CREATE TRIGGER FOR IMMUTABILITY
-- ================================================================================

DROP TRIGGER IF EXISTS trigger_consent_no_update ON consent_logs;
CREATE TRIGGER trigger_consent_no_update
    BEFORE UPDATE ON consent_logs
    FOR EACH ROW
    EXECUTE FUNCTION prevent_consent_update();

-- ================================================================================
-- BUSINESS RULES (For Application Developer)
-- ================================================================================
-- 1. When user creates account, record consent for 'terms_of_service' and 'privacy_policy'
-- 2. Marketing opt-in records separate consent rows for 'marketing_sms' and/or 'marketing_email'
-- 3. Unsubscribe = insert new row with consent_given = FALSE
-- 4. Query latest row (timestamp DESC) per (user_id, consent_type) to determine current status
-- 5. consent_given = TRUE + latest timestamp = active consent
-- 6. consent_given = FALSE OR no row = not consented
-- 7. document_hash should be SHA-256 of exact document text presented to user
-- 8. All PII (user_id, ip_address) must be handled as per IT Act 2000
-- ================================================================================

-- ================================================================================
-- SAMPLE INSERT DATA (For testing purposes only)
-- ================================================================================

-- INSERT INTO consent_logs (user_id, consent_type, consent_version, document_hash, consent_given, ip_address, user_agent, timestamp, notes)
-- VALUES (
--     '123e4567-e89b-12d3-a456-426614174000', 
--     'terms_of_service', 
--     'v2.0', 
--     'a1b2c3d4e5f67890abcdef1234567890', 
--     TRUE, 
--     '192.168.1.10'::INET, 
--     'Mozilla/5.0 (Windows NT 10.0)', 
--     NOW(), 
--     NULL
-- );