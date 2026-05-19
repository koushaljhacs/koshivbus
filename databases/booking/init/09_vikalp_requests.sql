-- ================================================================================
-- VIKALP REQUESTS TABLE – v1.3
-- Database: koshiv_bus_booking
-- Author: Koushal Jha
-- Date: May 2026
-- Project: KOSHIV BUS BOOKING SYSTEM
-- Compliance: IT Act 2000, Indian Financial Regulations
-- ================================================================================
-- VERSION HISTORY:
-- v1.0 – Initial release
-- v1.1 – Added expires_at, unique constraint guidance, index on offers.expires_at, decline_reason
-- v1.2 – No schema changes; added complete BUSINESS RULES
-- v1.3 – Added original_group_booking_id column for group bookings, mutual exclusivity constraint
-- ================================================================================

-- ================================================================================
-- CREATE VIKALP REQUESTS TABLE
-- ================================================================================

CREATE TABLE IF NOT EXISTS vikalp_requests (
    vikalp_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    original_booking_id UUID,
    original_group_booking_id UUID,
    from_highway_station TEXT NOT NULL,
    to_highway_station TEXT NOT NULL,
    journey_date DATE NOT NULL,
    preferred_bus_types TEXT[],
    preferred_quota_types TEXT[],
    max_alternative_fare_percentage INTEGER DEFAULT 20,
    request_status TEXT NOT NULL DEFAULT 'active',
    notification_window_hours_before INTEGER NOT NULL DEFAULT 48,
    expires_at TIMESTAMPTZ NOT NULL,
    search_last_run_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    metadata JSONB,
    
    -- Constraints
    CONSTRAINT journey_date_check CHECK (journey_date >= CURRENT_DATE),
    CONSTRAINT request_status_check CHECK (request_status IN ('active', 'expired', 'cancelled', 'completed')),
    CONSTRAINT max_fare_percentage_check CHECK (max_alternative_fare_percentage BETWEEN 0 AND 100),
    CONSTRAINT notification_window_check CHECK (notification_window_hours_before > 0),
    CONSTRAINT original_booking_xor_group CHECK (
        (original_booking_id IS NOT NULL AND original_group_booking_id IS NULL) OR
        (original_booking_id IS NULL AND original_group_booking_id IS NOT NULL)
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
-- FOREIGN KEY TO bookings (same database - NULLABLE)
-- ================================================================================

ALTER TABLE vikalp_requests DROP CONSTRAINT IF EXISTS fk_vikalp_requests_booking;
ALTER TABLE vikalp_requests ADD CONSTRAINT fk_vikalp_requests_booking
    FOREIGN KEY (original_booking_id) REFERENCES bookings(booking_id) ON DELETE SET NULL;

-- ================================================================================
-- TABLE COMMENTS
-- ================================================================================

COMMENT ON TABLE vikalp_requests IS 'Implements Vikalp (alternative bus offer) for waitlisted bookings - supports both single and group bookings';
COMMENT ON COLUMN vikalp_requests.vikalp_id IS 'Unique identifier for Vikalp request';
COMMENT ON COLUMN vikalp_requests.user_id IS 'References users.user_id from koshiv_bus_user database - NO FK (different DB) - application must validate';
COMMENT ON COLUMN vikalp_requests.original_booking_id IS 'Single booking ID (NULL for group requests)';
COMMENT ON COLUMN vikalp_requests.original_group_booking_id IS 'Group booking ID from bookings table (for group requests)';
COMMENT ON COLUMN vikalp_requests.from_highway_station IS 'Pickup highway station';
COMMENT ON COLUMN vikalp_requests.to_highway_station IS 'Drop highway station';
COMMENT ON COLUMN vikalp_requests.journey_date IS 'Travel date - must be >= CURRENT_DATE';
COMMENT ON COLUMN vikalp_requests.preferred_bus_types IS 'Array of preferred bus classes - empty means any';
COMMENT ON COLUMN vikalp_requests.preferred_quota_types IS 'Array of preferred quotas - empty means any';
COMMENT ON COLUMN vikalp_requests.max_alternative_fare_percentage IS 'Max allowed fare percentage above original (default 20%)';
COMMENT ON COLUMN vikalp_requests.request_status IS 'active, expired, cancelled, completed';
COMMENT ON COLUMN vikalp_requests.notification_window_hours_before IS 'Hours before journey to stop searching (default 48)';
COMMENT ON COLUMN vikalp_requests.expires_at IS 'Computed as journey_date - notification_window_hours_before hours';
COMMENT ON COLUMN vikalp_requests.search_last_run_at IS 'Timestamp of last background search';
COMMENT ON COLUMN vikalp_requests.metadata IS 'Additional JSON data for future extensions';

-- ================================================================================
-- CREATE INDEXES
-- ================================================================================

CREATE INDEX IF NOT EXISTS idx_vikalp_user ON vikalp_requests(user_id);
CREATE INDEX IF NOT EXISTS idx_vikalp_status_active ON vikalp_requests(request_status, journey_date) WHERE request_status = 'active';
CREATE INDEX IF NOT EXISTS idx_vikalp_journey_date ON vikalp_requests(journey_date);
CREATE INDEX IF NOT EXISTS idx_vikalp_expires_at ON vikalp_requests(expires_at) WHERE request_status = 'active';
CREATE INDEX IF NOT EXISTS idx_vikalp_original_group ON vikalp_requests(original_group_booking_id) WHERE original_group_booking_id IS NOT NULL;

-- ================================================================================
-- TRIGGER FUNCTION FOR UPDATED_AT
-- ================================================================================

CREATE OR REPLACE FUNCTION trigger_vikalp_update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- ================================================================================
-- CREATE TRIGGER
-- ================================================================================

DROP TRIGGER IF EXISTS trg_vikalp_update_updated_at ON vikalp_requests;
CREATE TRIGGER trg_vikalp_update_updated_at
    BEFORE UPDATE ON vikalp_requests
    FOR EACH ROW
    EXECUTE FUNCTION trigger_vikalp_update_updated_at();