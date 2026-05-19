-- ================================================================================
-- VIKALP OFFERS TABLE – v1.3
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
-- v1.3 – Added required_seat_count for group bookings
-- ================================================================================

-- ================================================================================
-- CREATE VIKALP OFFERS TABLE
-- ================================================================================

CREATE TABLE IF NOT EXISTS vikalp_offers (
    offer_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    vikalp_id UUID NOT NULL,
    offered_bus_id UUID NOT NULL,
    offered_seat_id_offset INTEGER,
    required_seat_count INTEGER NOT NULL,
    offered_fare DECIMAL(10,2) NOT NULL,
    offer_status TEXT NOT NULL DEFAULT 'pending',
    offered_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMPTZ NOT NULL,
    accepted_at TIMESTAMPTZ,
    declined_at TIMESTAMPTZ,
    decline_reason TEXT,
    notes TEXT,
    
    -- Constraints
    CONSTRAINT required_seat_count_check CHECK (required_seat_count >= 1),
    CONSTRAINT offered_fare_positive CHECK (offered_fare >= 0),
    CONSTRAINT offer_status_check CHECK (offer_status IN ('pending', 'accepted', 'declined', 'expired')),
    CONSTRAINT seat_offset_check CHECK (offered_seat_id_offset IS NULL OR offered_seat_id_offset >= 0)
);

-- ================================================================================
-- FOREIGN KEY TO vikalp_requests
-- ================================================================================

ALTER TABLE vikalp_offers DROP CONSTRAINT IF EXISTS fk_vikalp_offers_request;
ALTER TABLE vikalp_offers ADD CONSTRAINT fk_vikalp_offers_request
    FOREIGN KEY (vikalp_id) REFERENCES vikalp_requests(vikalp_id) ON DELETE CASCADE;

-- ================================================================================
-- TABLE COMMENTS
-- ================================================================================

COMMENT ON TABLE vikalp_offers IS 'Stores alternative bus offers for Vikalp requests - supports both single and group bookings';
COMMENT ON COLUMN vikalp_offers.offer_id IS 'Unique identifier for Vikalp offer';
COMMENT ON COLUMN vikalp_offers.vikalp_id IS 'References vikalp_requests(vikalp_id)';
COMMENT ON COLUMN vikalp_offers.offered_bus_id IS 'Reference to koshiv_bus_operations.buses - NO FK (different DB) - application must validate';
COMMENT ON COLUMN vikalp_offers.offered_seat_id_offset IS 'Starting seat number for group offers (if seats are contiguous)';
COMMENT ON COLUMN vikalp_offers.required_seat_count IS 'Number of seats needed - for group requests = group size, for single = 1';
COMMENT ON COLUMN vikalp_offers.offered_fare IS 'Total fare for all required seats (or single fare)';
COMMENT ON COLUMN vikalp_offers.offer_status IS 'pending, accepted, declined, expired';
COMMENT ON COLUMN vikalp_offers.expires_at IS 'MIN(NOW() + user_window, vikalp_requests.expires_at, journey_date - 2 hours)';
COMMENT ON COLUMN vikalp_offers.decline_reason IS 'Optional reason when user declines offer';

-- ================================================================================
-- CREATE INDEXES
-- ================================================================================

CREATE INDEX IF NOT EXISTS idx_vikalp_offers_pending ON vikalp_offers(vikalp_id, offer_status, expires_at);
CREATE INDEX IF NOT EXISTS idx_vikalp_offers_expires_at ON vikalp_offers(expires_at) WHERE offer_status = 'pending';

-- ================================================================================
-- UNIQUE CONSTRAINT (Prevent duplicate offers for same bus)
-- ================================================================================

CREATE UNIQUE INDEX IF NOT EXISTS idx_vikalp_offers_unique ON vikalp_offers (vikalp_id, offered_bus_id);