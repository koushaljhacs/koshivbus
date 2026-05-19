-- ================================================================================
-- TDR REQUESTS TABLE – v1.0
-- Database: koshiv_bus_booking
-- Author: Koushal Jha
-- Date: May 2026
-- Project: KOSHIV BUS BOOKING SYSTEM
-- Compliance: IT Act 2000, Indian Financial Regulations
-- ================================================================================
-- VERSION HISTORY:
-- v1.0 (May 2026) – Initial release
-- ================================================================================

-- ================================================================================
-- CREATE TDR REQUESTS TABLE
-- ================================================================================

CREATE TABLE IF NOT EXISTS tdr_requests (
    tdr_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_id UUID NOT NULL,
    user_id UUID NOT NULL,
    reason TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending',
    tdr_filed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    tdr_processed_at TIMESTAMPTZ,
    tdr_decision TEXT,
    refund_amount DECIMAL(10,2) DEFAULT 0,
    attached_proof_url TEXT,
    notes TEXT,
    metadata JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Constraints
    CONSTRAINT status_check CHECK (status IN ('pending', 'approved', 'rejected', 'refunded')),
    CONSTRAINT tdr_decision_check CHECK (tdr_decision IN ('full_refund', 'partial_refund', 'rejected') OR tdr_decision IS NULL),
    CONSTRAINT refund_amount_positive CHECK (refund_amount >= 0)
);

-- ================================================================================
-- FOREIGN KEY TO bookings (same database)
-- ================================================================================

ALTER TABLE tdr_requests DROP CONSTRAINT IF EXISTS fk_tdr_requests_booking;
ALTER TABLE tdr_requests ADD CONSTRAINT fk_tdr_requests_booking
    FOREIGN KEY (booking_id) REFERENCES bookings(booking_id) ON DELETE CASCADE;

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

COMMENT ON TABLE tdr_requests IS 'Stores Ticket Deposit Receipt (TDR) requests filed by passengers when chart is prepared - for refund claims due to bus delay, cancellation, or other reasons';
COMMENT ON COLUMN tdr_requests.tdr_id IS 'Unique identifier for each TDR request';
COMMENT ON COLUMN tdr_requests.booking_id IS 'References bookings(booking_id) - ON DELETE CASCADE';
COMMENT ON COLUMN tdr_requests.user_id IS 'References users.user_id from koshiv_bus_user database - NO FK (different DB) - application must validate';
COMMENT ON COLUMN tdr_requests.reason IS 'Reason for filing TDR - Bus delay >3 hours, Bus cancelled by operator, Partial cancellation, Accident / route change, Other';
COMMENT ON COLUMN tdr_requests.status IS 'pending, approved, rejected, refunded';
COMMENT ON COLUMN tdr_requests.tdr_filed_at IS 'When the TDR request was submitted by passenger';
COMMENT ON COLUMN tdr_requests.tdr_processed_at IS 'When admin reviewed and processed the TDR';
COMMENT ON COLUMN tdr_requests.tdr_decision IS 'Admin decision - full_refund, partial_refund, rejected';
COMMENT ON COLUMN tdr_requests.refund_amount IS 'Amount refunded (if approved) - links to refund_transactions';
COMMENT ON COLUMN tdr_requests.attached_proof_url IS 'URL or file path to supporting document';
COMMENT ON COLUMN tdr_requests.notes IS 'Internal admin notes (reason for rejection, remarks)';
COMMENT ON COLUMN tdr_requests.metadata IS 'Flexible additional data - proof_filenames, operator_acknowledged, refund_event_id, etc.';

-- ================================================================================
-- CREATE INDEXES
-- ================================================================================

CREATE INDEX IF NOT EXISTS idx_tdr_booking ON tdr_requests(booking_id);
CREATE INDEX IF NOT EXISTS idx_tdr_user ON tdr_requests(user_id);
CREATE INDEX IF NOT EXISTS idx_tdr_status ON tdr_requests(status);
CREATE INDEX IF NOT EXISTS idx_tdr_filed_at ON tdr_requests(tdr_filed_at);

-- ================================================================================
-- TRIGGER FUNCTION FOR UPDATED_AT
-- ================================================================================

CREATE OR REPLACE FUNCTION trigger_tdr_update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- ================================================================================
-- CREATE TRIGGER
-- ================================================================================

DROP TRIGGER IF EXISTS trg_tdr_update_updated_at ON tdr_requests;
CREATE TRIGGER trg_tdr_update_updated_at
    BEFORE UPDATE ON tdr_requests
    FOR EACH ROW
    EXECUTE FUNCTION trigger_tdr_update_updated_at();

-- ================================================================================
-- BUSINESS RULES (For Application Developer)
-- ================================================================================
-- 1. User can file TDR only if:
--    - Booking exists and belongs to user
--    - bookings.charting_status = 'generated'
--    - bookings.booking_status NOT IN ('cancelled', 'failed')
--    - No approved TDR exists for same booking
--
-- 2. When TDR approved (status = 'approved' or 'refunded'):
--    - Initiate refund via payment_transactions and refund_transactions
--    - Store refund_event_id in metadata for audit trail
--    - Record refund_amount in this table
--    - Cancel original booking if not already cancelled
--
-- 3. Admin actions:
--    - View pending TDRs (status = 'pending')
--    - Update status, tdr_decision, refund_amount, notes
--    - After setting status='approved', application must trigger refund process
--
-- 4. TDR vs Normal Refund:
--    - Normal refund: User cancels ticket via dashboard → refund_transactions directly
--    - TDR: Operator fails to provide service, chart already prepared → claim via this table
--
-- 5. Attachments:
--    - Proof documents stored externally (cloud/local storage)
--    - URL stored in attached_proof_url
--    - Multiple files: use metadata JSONB
-- ================================================================================

-- ================================================================================
-- SAMPLE INSERT DATA (For testing purposes only)
-- ================================================================================

-- INSERT INTO tdr_requests (
--     tdr_id, booking_id, user_id, reason, status, tdr_filed_at, 
--     tdr_processed_at, tdr_decision, refund_amount, attached_proof_url, 
--     notes, metadata
-- ) VALUES (
--     gen_random_uuid(), 
--     '123e4567-e89b-12d3-a456-426614174000', 
--     '123e4567-e89b-12d3-a456-426614174001', 
--     'Bus delay >3 hours', 
--     'approved', 
--     NOW(), 
--     NOW(), 
--     'full_refund', 
--     500.00, 
--     'https://storage.koshiv.com/tdrs/delay_certificate.pdf', 
--     'Inspected; bus delayed 4 hours. Full refund approved.', 
--     '{"operator_acknowledged": true, "refund_event_id": "ref-123"}'
-- );