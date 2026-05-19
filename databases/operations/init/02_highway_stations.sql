-- ================================================================================
-- HIGHWAY STATIONS TABLE – v1.0
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
-- CREATE HIGHWAY STATIONS TABLE
-- ================================================================================

CREATE TABLE IF NOT EXISTS highway_stations (
    station_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    station_name TEXT UNIQUE NOT NULL,
    station_code TEXT UNIQUE NOT NULL,
    latitude DECIMAL(10,8),
    longitude DECIMAL(11,8),
    address TEXT,
    is_pickup_allowed BOOLEAN NOT NULL DEFAULT TRUE,
    is_drop_allowed BOOLEAN NOT NULL DEFAULT TRUE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- Constraints
    CONSTRAINT station_code_format CHECK (station_code ~ '^[A-Z]{3,5}$')
);

-- ================================================================================
-- TABLE COMMENTS
-- ================================================================================

COMMENT ON TABLE highway_stations IS 'Physical highway bus stops where bus actually halts - passengers board/alight only at these stations';
COMMENT ON COLUMN highway_stations.station_id IS 'Internal unique identifier for the highway station';
COMMENT ON COLUMN highway_stations.station_name IS 'Public name of the station (e.g., New Delhi Highway Station) - must be unique';
COMMENT ON COLUMN highway_stations.station_code IS 'Short code like railway station code (e.g., NDLS, DBG) - 3-5 uppercase letters only';
COMMENT ON COLUMN highway_stations.latitude IS 'GPS latitude for map display';
COMMENT ON COLUMN highway_stations.longitude IS 'GPS longitude for map display';
COMMENT ON COLUMN highway_stations.address IS 'Full street address of the station';
COMMENT ON COLUMN highway_stations.is_pickup_allowed IS 'Whether passengers can board from this station';
COMMENT ON COLUMN highway_stations.is_drop_allowed IS 'Whether passengers can alight at this station';
COMMENT ON COLUMN highway_stations.is_active IS 'Soft delete flag - inactive stations not shown in search or route selection';

-- ================================================================================
-- CREATE INDEXES
-- ================================================================================

CREATE UNIQUE INDEX IF NOT EXISTS idx_highway_stations_code ON highway_stations(station_code);
CREATE UNIQUE INDEX IF NOT EXISTS idx_highway_stations_name ON highway_stations(station_name);
CREATE INDEX IF NOT EXISTS idx_highway_stations_active ON highway_stations(is_active) WHERE is_active = true;

-- ================================================================================
-- TRIGGER FUNCTION FOR UPDATED_AT
-- ================================================================================

CREATE OR REPLACE FUNCTION trigger_highway_stations_update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- ================================================================================
-- CREATE TRIGGER
-- ================================================================================

DROP TRIGGER IF EXISTS trg_highway_stations_update_updated_at ON highway_stations;
CREATE TRIGGER trg_highway_stations_update_updated_at
    BEFORE UPDATE ON highway_stations
    FOR EACH ROW
    EXECUTE FUNCTION trigger_highway_stations_update_updated_at();

-- ================================================================================
-- INSERT INITIAL DATA (MVP Stations)
-- ================================================================================

INSERT INTO highway_stations (station_id, station_name, station_code, latitude, longitude, address, is_pickup_allowed, is_drop_allowed, is_active) VALUES
    (gen_random_uuid(), 'New Delhi Highway Station', 'NDLS', 28.6139, 77.2090, 'Delhi - Jaipur Highway, Near Mahipalpur, New Delhi', TRUE, TRUE, TRUE),
    (gen_random_uuid(), 'Agra Highway Station', 'AGC', 27.1767, 78.0081, 'Yamuna Expressway, Near Agra', TRUE, TRUE, TRUE),
    (gen_random_uuid(), 'Lucknow Highway Station', 'LKO', 26.8467, 80.9462, 'Lucknow - Kanpur Highway, Near Transport Nagar', TRUE, TRUE, TRUE),
    (gen_random_uuid(), 'Gorakhpur Highway Station', 'GKP', 26.7606, 83.3732, 'Gorakhpur Bypass, Near Gorakhpur', TRUE, TRUE, TRUE),
    (gen_random_uuid(), 'Muzaffarpur Highway Station', 'MFP', 26.1209, 85.3645, 'Muzaffarpur Bypass, Near Muzaffarpur', TRUE, TRUE, TRUE),
    (gen_random_uuid(), 'Samastipur Highway Station', 'SPJ', 25.8613, 85.7790, 'Samastipur Bypass, Near Samastipur', TRUE, TRUE, TRUE),
    (gen_random_uuid(), 'Darbhanga Highway Station', 'DBG', 26.1542, 85.8918, 'Darbhanga Bypass, Near Darbhanga', TRUE, TRUE, TRUE)
ON CONFLICT (station_code) DO NOTHING;

-- ================================================================================
-- VERIFICATION QUERY
-- ================================================================================
-- SELECT station_name, station_code, is_pickup_allowed, is_drop_allowed FROM highway_stations ORDER BY station_name;
-- ================================================================================