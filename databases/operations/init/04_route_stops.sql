-- ================================================================================
-- ROUTE STOPS TABLE – v1.0 (FINAL)
-- Database: koshiv_bus_operations (Server 2)
-- Author: Koushal Jha
-- Date: May 2026
-- Project: KOSHIV BUS BOOKING SYSTEM
-- Compliance: IT Act 2000, Indian Financial Regulations
-- ================================================================================
-- VERSION HISTORY:
-- v1.0 (May 2026) – Initial release
-- ================================================================================

CREATE TABLE IF NOT EXISTS route_stops (
    stop_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    route_id UUID NOT NULL,
    station_id UUID NOT NULL,
    station_code TEXT NOT NULL,
    stop_sequence INTEGER NOT NULL,
    arrival_time TIME,
    departure_time TIME,
    halt_minutes INTEGER DEFAULT 0,
    distance_from_prev INTEGER,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    CONSTRAINT stop_sequence_positive CHECK (stop_sequence >= 1),
    CONSTRAINT first_stop_arrival_null CHECK (
        (stop_sequence = 1 AND arrival_time IS NULL AND departure_time IS NOT NULL) OR
        (stop_sequence > 1)
    ),
    CONSTRAINT arrival_before_departure CHECK (
        arrival_time IS NULL OR departure_time IS NULL OR arrival_time < departure_time
    ),
    CONSTRAINT halt_minutes_non_negative CHECK (halt_minutes >= 0),
    CONSTRAINT distance_from_prev_positive CHECK (distance_from_prev >= 0 OR distance_from_prev IS NULL)
);

ALTER TABLE route_stops DROP CONSTRAINT IF EXISTS fk_route_stops_route;
ALTER TABLE route_stops ADD CONSTRAINT fk_route_stops_route
    FOREIGN KEY (route_id) REFERENCES routes(route_id) ON DELETE CASCADE;

ALTER TABLE route_stops DROP CONSTRAINT IF EXISTS fk_route_stops_station;
ALTER TABLE route_stops ADD CONSTRAINT fk_route_stops_station
    FOREIGN KEY (station_id) REFERENCES highway_stations(station_id) ON DELETE RESTRICT;

COMMENT ON TABLE route_stops IS 'Defines intermediate stops for a bus route - first stop is from_station, last stop is to_station';
COMMENT ON COLUMN route_stops.stop_id IS 'Unique identifier for each stop record';
COMMENT ON COLUMN route_stops.route_id IS 'References routes(route_id)';
COMMENT ON COLUMN route_stops.station_id IS 'References highway_stations - physical station where bus stops';
COMMENT ON COLUMN route_stops.station_code IS 'Short code displayed on ticket (e.g., NDLS, DBG)';
COMMENT ON COLUMN route_stops.stop_sequence IS 'Order of stops - first stop = 1, last stop = N';
COMMENT ON COLUMN route_stops.arrival_time IS 'Arrival time at this stop - NULL for first stop';
COMMENT ON COLUMN route_stops.departure_time IS 'Departure time from this stop - NULL for last stop';
COMMENT ON COLUMN route_stops.halt_minutes IS 'Duration of halt in minutes';
COMMENT ON COLUMN route_stops.distance_from_prev IS 'Distance in kilometers from previous stop - NULL for first stop';
COMMENT ON COLUMN route_stops.is_active IS 'Soft delete - inactive stops skipped in schedule display';

CREATE INDEX IF NOT EXISTS idx_route_stops_route ON route_stops(route_id, stop_sequence);
CREATE INDEX IF NOT EXISTS idx_route_stops_station ON route_stops(station_id);
CREATE INDEX IF NOT EXISTS idx_route_stops_code ON route_stops(station_code);
CREATE INDEX IF NOT EXISTS idx_route_stops_active ON route_stops(is_active) WHERE is_active = true;

CREATE OR REPLACE FUNCTION trigger_route_stops_update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

DROP TRIGGER IF EXISTS trg_route_stops_update_updated_at ON route_stops;
CREATE TRIGGER trg_route_stops_update_updated_at
    BEFORE UPDATE ON route_stops
    FOR EACH ROW
    EXECUTE FUNCTION trigger_route_stops_update_updated_at();