-- ================================================================================
-- BOOKING STATUS HISTORY TABLE – v1.2
-- Database: koshiv_bus_booking
-- Author: Koushal Jha
-- Date: May 2026
-- Project: KOSHIV BUS BOOKING SYSTEM
-- Compliance: IT Act 2000, Indian Financial Regulations, Legal Audit
-- ================================================================================
-- VERSION HISTORY:
-- v1.0 (May 2026) – Initial release
-- v1.1 (May 2026) – Added CHECK constraint to ensure new_status != old_status (when old_status not NULL)
-- v1.2 (May 2026) – Final version with flowchart, admin handling, standardized columns
-- ================================================================================

-- ================================================================================
-- CREATE BOOKING STATUS HISTORY TABLE
-- ================================================================================

CREATE TABLE IF NOT EXISTS booking_status_history (
    history_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_id UUID NOT NULL,
    old_status TEXT,
    new_status TEXT NOT NULL,
    changed_by UUID,
    changed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    reason TEXT,
    
    -- Constraints
    CONSTRAINT old_status_check CHECK (old_status IN ('pending', 'confirmed', 'cancelled', 'failed', 'waitlisted') OR old_status IS NULL),
    CONSTRAINT new_status_check CHECK (new_status IN ('pending', 'confirmed', 'cancelled', 'failed', 'waitlisted')),
    CONSTRAINT status_change_check CHECK (old_status IS NULL OR new_status != old_status)
);

-- ================================================================================
-- FOREIGN KEY (booking_id references bookings table)
-- ================================================================================

ALTER TABLE booking_status_history DROP CONSTRAINT IF EXISTS fk_booking_status_history_booking;
ALTER TABLE booking_status_history ADD CONSTRAINT fk_booking_status_history_booking
    FOREIGN KEY (booking_id) REFERENCES bookings(booking_id) ON DELETE CASCADE;

-- ================================================================================
-- TABLE COMMENTS
-- ================================================================================

COMMENT ON TABLE booking_status_history IS 'Append-only audit trail of booking status changes - required for legal disputes, customer support, and internal audits';
COMMENT ON COLUMN booking_status_history.history_id IS 'Unique identifier for each status change event';
COMMENT ON COLUMN booking_status_history.booking_id IS 'References bookings(booking_id) - which booking changed status';
COMMENT ON COLUMN booking_status_history.old_status IS 'Status before the change - NULL for first entry (booking creation)';
COMMENT ON COLUMN booking_status_history.new_status IS 'Status after the change';
COMMENT ON COLUMN booking_status_history.changed_by IS 'User ID who caused change - NULL for admin/system actions';
COMMENT ON COLUMN booking_status_history.changed_at IS 'Timestamp of the change (UTC)';
COMMENT ON COLUMN booking_status_history.reason IS 'Human-readable explanation - e.g., Payment successful, Customer cancelled, Auto-cancelled after charting';

-- ================================================================================
-- CREATE INDEXES
-- ================================================================================

CREATE INDEX IF NOT EXISTS idx_booking_status_history_booking ON booking_status_history(booking_id);
CREATE INDEX IF NOT EXISTS idx_booking_status_history_changed_at ON booking_status_history(changed_at);
CREATE INDEX IF NOT EXISTS idx_booking_status_history_booking_time ON booking_status_history(booking_id, changed_at);

-- ================================================================================
-- TRIGGER FUNCTION FOR AUTO-INSERT ON BOOKINGS STATUS CHANGE
-- ================================================================================

CREATE OR REPLACE FUNCTION trigger_booking_status_history_insert()
RETURNS TRIGGER AS $$
BEGIN
    -- Check if status actually changed
    IF OLD.booking_status IS DISTINCT FROM NEW.booking_status THEN
        INSERT INTO booking_status_history (
            booking_id,
            old_status,
            new_status,
            changed_by,
            changed_at,
            reason
        ) VALUES (
            NEW.booking_id,
            OLD.booking_status,
            NEW.booking_status,
            current_setting('app.current_user_id', true)::UUID,
            NOW(),
            current_setting('app.reason', true)
        );
    END IF;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- ================================================================================
-- CREATE TRIGGER ON BOOKINGS TABLE
-- ================================================================================

DROP TRIGGER IF EXISTS trg_booking_status_history ON bookings;
CREATE TRIGGER trg_booking_status_history
    AFTER UPDATE OF booking_status ON bookings
    FOR EACH ROW
    EXECUTE FUNCTION trigger_booking_status_history_insert();

-- ================================================================================
-- SAMPLE INSERT DATA (For testing purposes only)
-- ================================================================================

-- Note: These inserts assume booking_id exists. For testing only.
-- INSERT INTO booking_status_history (booking_id, old_status, new_status, changed_by, reason)
-- VALUES (gen_random_uuid(), NULL, 'pending', NULL, 'Booking created');