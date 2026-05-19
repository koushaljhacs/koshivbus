-- ================================================================================
-- WAITLIST TABLE – v1.0
-- Database: koshiv_bus_operations (Server 2)
-- Author: Koushal Jha
-- Date: May 2026
-- Project: KOSHIV BUS BOOKING SYSTEM
-- Compliance: IT Act 2000, Indian Financial Regulations
-- ================================================================================
-- VERSION HISTORY:
-- v1.0 (May 2026) – Initial release. Supports RAC (sleeper only), WL, TQWL with
--                   auto-confirmation and auto-expiry logic.
-- ================================================================================

CREATE TABLE IF NOT EXISTS waitlist (
    waitlist_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    booking_id UUID NOT NULL,
    route_id UUID NOT NULL,
    journey_date DATE NOT NULL,
    bus_id UUID NOT NULL,
    quota_type TEXT NOT NULL DEFAULT 'general',
    waitlist_type TEXT NOT NULL,
    position INTEGER NOT NULL,
    status TEXT NOT NULL DEFAULT 'waiting',
    confirmed_seat_id UUID,
    confirmed_at TIMESTAMPTZ,
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- Constraints
    CONSTRAINT journey_date_check CHECK (journey_date >= CURRENT_DATE),
    CONSTRAINT quota_type_check CHECK (quota_type IN ('general', 'tatkal', 'ladies', 'disabled', 'staff', 'duty_pass')),
    CONSTRAINT waitlist_type_check CHECK (waitlist_type IN ('RAC', 'WL', 'TQWL')),
    CONSTRAINT status_check CHECK (status IN ('waiting', 'confirmed', 'expired', 'cancelled_by_user')),
    CONSTRAINT position_positive CHECK (position >= 1)
);

-- ================================================================================
-- FOREIGN KEYS (within same database)
-- ================================================================================

ALTER TABLE waitlist DROP CONSTRAINT IF EXISTS fk_waitlist_route;
ALTER TABLE waitlist ADD CONSTRAINT fk_waitlist_route
    FOREIGN KEY (route_id) REFERENCES routes(route_id) ON DELETE CASCADE;

ALTER TABLE waitlist DROP CONSTRAINT IF EXISTS fk_waitlist_bus;
ALTER TABLE waitlist ADD CONSTRAINT fk_waitlist_bus
    FOREIGN KEY (bus_id) REFERENCES buses(bus_id) ON DELETE CASCADE;

-- ================================================================================
-- UNIQUE CONSTRAINT
-- ================================================================================

ALTER TABLE waitlist DROP CONSTRAINT IF EXISTS unique_waitlist_position;
ALTER TABLE waitlist ADD CONSTRAINT unique_waitlist_position UNIQUE (route_id, journey_date, waitlist_type, position);

-- ================================================================================
-- TABLE COMMENTS
-- ================================================================================

COMMENT ON TABLE waitlist IS 'Stores waitlist entries for passengers when no seats are available - supports RAC (sleeper only), WL, TQWL';
COMMENT ON COLUMN waitlist.waitlist_id IS 'Unique identifier for each waitlist entry';
COMMENT ON COLUMN waitlist.user_id IS 'References users.user_id in koshiv_bus_booking - NO FK (cross-database) - application must validate';
COMMENT ON COLUMN waitlist.booking_id IS 'References bookings.booking_id in koshiv_bus_booking - NO FK (cross-database) - application must validate';
COMMENT ON COLUMN waitlist.route_id IS 'References routes(route_id) - ON DELETE CASCADE';
COMMENT ON COLUMN waitlist.journey_date IS 'Date of travel - must be >= CURRENT_DATE';
COMMENT ON COLUMN waitlist.bus_id IS 'References buses(bus_id) - used to determine bus_type for RAC eligibility';
COMMENT ON COLUMN waitlist.quota_type IS 'general, tatkal, ladies, disabled, staff, duty_pass';
COMMENT ON COLUMN waitlist.waitlist_type IS 'RAC, WL, TQWL - RAC only allowed for sleeper buses';
COMMENT ON COLUMN waitlist.position IS 'Position number within same waitlist_type, route, and journey_date';
COMMENT ON COLUMN waitlist.status IS 'waiting, confirmed, expired, cancelled_by_user';
COMMENT ON COLUMN waitlist.confirmed_seat_id IS 'Seat_id from seats table when seat allocated - NULL until confirmed';
COMMENT ON COLUMN waitlist.confirmed_at IS 'Timestamp when passenger was confirmed (seat allocated)';
COMMENT ON COLUMN waitlist.expires_at IS 'Auto-cancel time - e.g., 4 hours before journey_date + departure_time';
COMMENT ON COLUMN waitlist.created_at IS 'When the waitlist entry was created';
COMMENT ON COLUMN waitlist.updated_at IS 'Last update timestamp';

-- ================================================================================
-- CREATE INDEXES
-- ================================================================================

CREATE INDEX IF NOT EXISTS idx_waitlist_route_date ON waitlist(route_id, journey_date);
CREATE INDEX IF NOT EXISTS idx_waitlist_type_position ON waitlist(waitlist_type, position);
CREATE INDEX IF NOT EXISTS idx_waitlist_user ON waitlist(user_id);
CREATE INDEX IF NOT EXISTS idx_waitlist_status ON waitlist(status);
CREATE INDEX IF NOT EXISTS idx_waitlist_expires_at ON waitlist(expires_at) WHERE status = 'waiting';
CREATE INDEX IF NOT EXISTS idx_waitlist_booking ON waitlist(booking_id);

-- ================================================================================
-- TRIGGER FUNCTION FOR UPDATED_AT
-- ================================================================================

CREATE OR REPLACE FUNCTION trigger_waitlist_update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- ================================================================================
-- CREATE TRIGGER
-- ================================================================================

DROP TRIGGER IF EXISTS trg_waitlist_update_updated_at ON waitlist;
CREATE TRIGGER trg_waitlist_update_updated_at
    BEFORE UPDATE ON waitlist
    FOR EACH ROW
    EXECUTE FUNCTION trigger_waitlist_update_updated_at();

-- ================================================================================
-- BUSINESS RULES (Application must enforce)
-- ================================================================================
-- 1. RAC only for sleeper buses: Check buses.bus_type before inserting RAC
-- 2. Positions per (route_id, journey_date, waitlist_type) - recompute after changes
-- 3. Auto-confirmation when seat available: RAC → WL → TQWL priority order
-- 4. Waitlist expiry: expires_at = journey_date + departure_time - 4 hours
-- 5. User cancellation: Full refund, adjust positions
-- 6. Cross-database: No foreign keys to koshiv_bus_booking - application validates user_id, booking_id
-- 7. Position recomputation: After confirm/expire/cancel, positions restart from 1
-- ================================================================================

-- ================================================================================
-- SAMPLE INSERT DATA (Sleeper bus with RAC and WL)
-- ================================================================================
-- INSERT INTO waitlist (waitlist_id, user_id, booking_id, route_id, journey_date, bus_id, quota_type, waitlist_type, position, status, expires_at) VALUES
--     (gen_random_uuid(), 'user-123-uuid', 'book-456-uuid', 'route-789-uuid', '2026-06-15', 'bus-sleeper-101-uuid', 'general', 'RAC', 1, 'waiting', '2026-06-15 18:00:00+00'),
--     (gen_random_uuid(), 'user-124-uuid', 'book-457-uuid', 'route-789-uuid', '2026-06-15', 'bus-sleeper-101-uuid', 'general', 'RAC', 2, 'waiting', '2026-06-15 18:00:00+00'),
--     (gen_random_uuid(), 'user-125-uuid', 'book-458-uuid', 'route-789-uuid', '2026-06-15', 'bus-sleeper-101-uuid', 'general', 'WL', 1, 'waiting', '2026-06-15 18:00:00+00');

-- ================================================================================
-- SAMPLE INSERT DATA (Chair bus – only WL, no RAC)
-- ================================================================================
-- INSERT INTO waitlist (waitlist_id, user_id, booking_id, route_id, journey_date, bus_id, quota_type, waitlist_type, position, status, expires_at) VALUES
--     (gen_random_uuid(), 'user-126-uuid', 'book-459-uuid', 'route-790-uuid', '2026-06-16', 'bus-chair-202-uuid', 'general', 'WL', 1, 'waiting', '2026-06-16 17:00:00+00');