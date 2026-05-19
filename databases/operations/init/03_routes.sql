-- ================================================================================
-- ROUTES TABLE – v1.0
-- Database: koshiv_bus_operations (Server 2)
-- Author: Koushal Jha
-- Date: May 2026
-- Project: KOSHIV BUS BOOKING SYSTEM
-- Compliance: IT Act 2000, Indian Financial Regulations
-- ================================================================================
-- VERSION HISTORY:
-- v1.0 (May 2026) – Initial release
-- ================================================================================

-- ================================================================================
-- CREATE ROUTES TABLE
-- ================================================================================

CREATE TABLE IF NOT EXISTS routes (
    route_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    route_code TEXT UNIQUE NOT NULL,
    from_station_id UUID NOT NULL,
    to_station_id UUID NOT NULL,
    departure_time TIME NOT NULL,
    arrival_time TIME NOT NULL,
    distance_km INTEGER NOT NULL,
    base_fare DECIMAL(10,2) NOT NULL,
    direction TEXT NOT NULL,
    valid_days TEXT[] NOT NULL DEFAULT ARRAY['Mon','Tue','Wed','Thu','Fri','Sat','Sun'],
    priority TEXT NOT NULL DEFAULT 'Normal',
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- Constraints
    CONSTRAINT distance_positive CHECK (distance_km > 0),
    CONSTRAINT base_fare_positive CHECK (base_fare >= 0),
    CONSTRAINT direction_check CHECK (direction IN ('UP', 'DOWN')),
    CONSTRAINT priority_check CHECK (priority IN ('Normal', 'Express', 'Superfast'))
);

-- ================================================================================
-- FOREIGN KEYS (to highway_stations - same database)
-- ================================================================================

ALTER TABLE routes DROP CONSTRAINT IF EXISTS fk_routes_from_station;
ALTER TABLE routes ADD CONSTRAINT fk_routes_from_station
    FOREIGN KEY (from_station_id) REFERENCES highway_stations(station_id) ON DELETE RESTRICT;

ALTER TABLE routes DROP CONSTRAINT IF EXISTS fk_routes_to_station;
ALTER TABLE routes ADD CONSTRAINT fk_routes_to_station
    FOREIGN KEY (to_station_id) REFERENCES highway_stations(station_id) ON DELETE RESTRICT;

-- ================================================================================
-- TABLE COMMENTS
-- ================================================================================

COMMENT ON TABLE routes IS 'Master route data for bus operations - defines from/to stations, schedule, distance, fare, direction, valid days, and priority';
COMMENT ON COLUMN routes.route_id IS 'Internal unique identifier for the route';
COMMENT ON COLUMN routes.route_code IS 'Human-readable code for admin use (e.g., DL-DB-UP-101) - not shown to passengers';
COMMENT ON COLUMN routes.from_station_id IS 'References highway_stations(station_id) - departure highway station';
COMMENT ON COLUMN routes.to_station_id IS 'References highway_stations(station_id) - arrival highway station';
COMMENT ON COLUMN routes.departure_time IS 'Scheduled departure time from from_station (IST)';
COMMENT ON COLUMN routes.arrival_time IS 'Scheduled arrival time at to_station (IST)';
COMMENT ON COLUMN routes.distance_km IS 'Distance between from_station and to_station in kilometers';
COMMENT ON COLUMN routes.base_fare IS 'Base fare for this route (excludes convenience fee, tatkal charge, tax)';
COMMENT ON COLUMN routes.direction IS 'UP or DOWN - must be consistent with bus_direction when assigning bus to this route';
COMMENT ON COLUMN routes.valid_days IS 'Array of days this route operates - Mon, Tue, Wed, Thu, Fri, Sat, Sun';
COMMENT ON COLUMN routes.priority IS 'Normal, Express, Superfast - used by control room for signalling';
COMMENT ON COLUMN routes.is_active IS 'Soft delete - inactive routes not shown in search';

-- ================================================================================
-- CREATE INDEXES
-- ================================================================================

CREATE UNIQUE INDEX IF NOT EXISTS idx_route_code ON routes(route_code);
CREATE INDEX IF NOT EXISTS idx_route_stations ON routes(from_station_id, to_station_id);
CREATE INDEX IF NOT EXISTS idx_route_valid_days ON routes(valid_days);
CREATE INDEX IF NOT EXISTS idx_route_active ON routes(is_active);

-- ================================================================================
-- TRIGGER FUNCTION FOR UPDATED_AT
-- ================================================================================

CREATE OR REPLACE FUNCTION trigger_routes_update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- ================================================================================
-- CREATE TRIGGER
-- ================================================================================

DROP TRIGGER IF EXISTS trg_routes_update_updated_at ON routes;
CREATE TRIGGER trg_routes_update_updated_at
    BEFORE UPDATE ON routes
    FOR EACH ROW
    EXECUTE FUNCTION trigger_routes_update_updated_at();

-- ================================================================================
-- SAMPLE INSERT DATA (For testing purposes only)
-- ================================================================================

-- INSERT INTO routes (
--     route_id, route_code, from_station_id, to_station_id, departure_time, arrival_time,
--     distance_km, base_fare, direction, valid_days, priority, is_active
-- ) VALUES (
--     gen_random_uuid(), 'DL-DB-UP-101', 
--     (SELECT station_id FROM highway_stations WHERE station_code = 'DL'), 
--     (SELECT station_id FROM highway_stations WHERE station_code = 'DBG'), 
--     '22:00:00', '06:00:00', 1200, 800.00, 'UP', 
--     ARRAY['Mon','Wed','Fri'], 'Superfast', TRUE
-- );