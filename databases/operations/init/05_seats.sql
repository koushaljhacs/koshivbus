-- ================================================================================
-- SEATS TABLE – v1.1
-- Database: koshiv_bus_operations (Server 2)
-- Author: Koushal Jha
-- Date: May 2026
-- Project: KOSHIV BUS BOOKING SYSTEM
-- Compliance: IT Act 2000, Indian Financial Regulations
-- ================================================================================
-- VERSION HISTORY:
-- v1.0 (May 2026) – Initial release (with Lower, Upper, Side Lower, Side Upper)
-- v1.1 (May 2026) – Added 'Middle' seat type for sleeper buses (berth between Lower and Upper)
-- ================================================================================

CREATE TABLE IF NOT EXISTS seats (
    seat_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    bus_id UUID NOT NULL,
    seat_number INTEGER NOT NULL,
    seat_type TEXT NOT NULL,
    deck TEXT,
    is_window BOOLEAN NOT NULL DEFAULT FALSE,
    is_accessible BOOLEAN NOT NULL DEFAULT FALSE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    CONSTRAINT seat_number_positive CHECK (seat_number >= 1),
    CONSTRAINT seat_type_check CHECK (seat_type IN ('Seat', 'Lower', 'Middle', 'Upper', 'Side Lower', 'Side Upper')),
    CONSTRAINT deck_check CHECK (deck IN ('Lower', 'Upper', NULL))
);

ALTER TABLE seats DROP CONSTRAINT IF EXISTS fk_seats_bus;
ALTER TABLE seats ADD CONSTRAINT fk_seats_bus
    FOREIGN KEY (bus_id) REFERENCES buses(bus_id) ON DELETE CASCADE;

ALTER TABLE seats DROP CONSTRAINT IF EXISTS unique_bus_seat_number;
ALTER TABLE seats ADD CONSTRAINT unique_bus_seat_number UNIQUE (bus_id, seat_number);

COMMENT ON TABLE seats IS 'Static seat configuration for each bus - does NOT store daily availability (is_booked)';
COMMENT ON COLUMN seats.seat_id IS 'Unique identifier for the seat configuration';
COMMENT ON COLUMN seats.bus_id IS 'References buses(bus_id) - ON DELETE CASCADE';
COMMENT ON COLUMN seats.seat_number IS 'Sequential seat number (1 to total_seats of the bus)';
COMMENT ON COLUMN seats.seat_type IS 'Seat, Lower, Middle, Upper, Side Lower, Side Upper';
COMMENT ON COLUMN seats.deck IS 'For double-decker buses only - Lower, Upper, or NULL for single-deck';
COMMENT ON COLUMN seats.is_window IS 'Manually flagged by admin - true if seat is adjacent to window';
COMMENT ON COLUMN seats.is_accessible IS 'True if seat is designed for passengers with disabilities';
COMMENT ON COLUMN seats.is_active IS 'Soft delete flag - inactive seats not shown in seat map';

CREATE INDEX IF NOT EXISTS idx_seats_bus ON seats(bus_id);
CREATE UNIQUE INDEX IF NOT EXISTS idx_seats_bus_number ON seats(bus_id, seat_number);
CREATE INDEX IF NOT EXISTS idx_seats_window ON seats(bus_id, is_window) WHERE is_window = true;
CREATE INDEX IF NOT EXISTS idx_seats_type ON seats(seat_type);
CREATE INDEX IF NOT EXISTS idx_seats_active ON seats(is_active) WHERE is_active = true;

CREATE OR REPLACE FUNCTION trigger_seats_update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

DROP TRIGGER IF EXISTS trg_seats_update_updated_at ON seats;
CREATE TRIGGER trg_seats_update_updated_at
    BEFORE UPDATE ON seats
    FOR EACH ROW
    EXECUTE FUNCTION trigger_seats_update_updated_at();

-- ================================================================================
-- SAMPLE INSERT DATA (Sleeper bus with 3-tier berths - partial)
-- ================================================================================
-- INSERT INTO seats (seat_id, bus_id, seat_number, seat_type, deck, is_window, is_accessible, is_active) VALUES
--     (gen_random_uuid(), 'bus-456-uuid', 1, 'Lower', NULL, TRUE, FALSE, TRUE),
--     (gen_random_uuid(), 'bus-456-uuid', 2, 'Middle', NULL, FALSE, FALSE, TRUE),
--     (gen_random_uuid(), 'bus-456-uuid', 3, 'Upper', NULL, TRUE, FALSE, TRUE),
--     (gen_random_uuid(), 'bus-456-uuid', 4, 'Side Lower', NULL, TRUE, FALSE, TRUE),
--     (gen_random_uuid(), 'bus-456-uuid', 5, 'Side Upper', NULL, TRUE, FALSE, TRUE),
--     (gen_random_uuid(), 'bus-456-uuid', 40, 'Lower', NULL, FALSE, TRUE, TRUE);

-- ================================================================================
-- SAMPLE INSERT DATA (Chair bus with seats - partial)
-- ================================================================================
-- INSERT INTO seats (seat_id, bus_id, seat_number, seat_type, deck, is_window, is_accessible, is_active) VALUES
--     (gen_random_uuid(), 'bus-123-uuid', 1, 'Seat', NULL, TRUE, FALSE, TRUE),
--     (gen_random_uuid(), 'bus-123-uuid', 2, 'Seat', NULL, FALSE, FALSE, TRUE),
--     (gen_random_uuid(), 'bus-123-uuid', 110, 'Seat', NULL, TRUE, TRUE, TRUE);