-- ================================================================================
-- SERVER CREDENTIALS TABLE
-- ================================================================================
-- Version: 1.0.0
-- Author: Koushal Jha
-- Date: May 2026
-- Project: KOSHIV BUS BOOKING SYSTEM
-- Description: Stores connection credentials for all KOSHIV database servers
-- Compliance: IT Act 2000, Indian Financial Regulations
-- ================================================================================

-- ================================================================================
-- DROP TABLE IF EXISTS (for clean re-run)
-- ================================================================================

DROP TABLE IF EXISTS server_credentials CASCADE;

-- ================================================================================
-- CREATE SERVER CREDENTIALS TABLE
-- ================================================================================

CREATE TABLE server_credentials (
    credential_id         SERIAL PRIMARY KEY,
    server_name           VARCHAR(50) NOT NULL UNIQUE,
    host                  INET NOT NULL,
    port                  INTEGER NOT NULL,
    database_name         VARCHAR(100) NOT NULL,
    username              VARCHAR(100) NOT NULL,
    password              TEXT NOT NULL,
    is_active             BOOLEAN DEFAULT TRUE,
    created_at            TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at            TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT valid_server_name CHECK (
        server_name IN (
            'koshiv_bus_admin_server',
            'koshiv_bus_booking_server',
            'koshiv_bus_operations_server'
        )
    ),
    CONSTRAINT valid_port CHECK (port BETWEEN 1024 AND 65535)
);

-- ================================================================================
-- CREATE INDEXES
-- ================================================================================

CREATE INDEX idx_server_credentials_server_name ON server_credentials(server_name);
CREATE INDEX idx_server_credentials_is_active ON server_credentials(is_active);

-- ================================================================================
-- INSERT INITIAL DATA (ADMIN SERVER ONLY)
-- ================================================================================

INSERT INTO server_credentials (
    server_name,
    host,
    port,
    database_name,
    username,
    password,
    is_active
) VALUES (
    'koshiv_bus_admin_server',
    '100.81.13.80',
    15434,
    'koshiv_bus_admin',
    'koushal',
    'Koushal@Admin2026#Secure',
    TRUE
);

-- ================================================================================
-- CREATE FUNCTION FOR AUTO-UPDATE TIMESTAMP
-- ================================================================================

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- ================================================================================
-- CREATE TRIGGER FOR UPDATED_AT
-- ================================================================================

CREATE TRIGGER update_server_credentials_updated_at
    BEFORE UPDATE ON server_credentials
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- ================================================================================
-- VERIFICATION QUERY
-- ================================================================================

-- Run this after container starts to verify:
-- SELECT server_name, host, port, database_name, username FROM server_credentials;