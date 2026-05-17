-- ================================================================================
-- SERVER CREDENTIALS TABLE
-- ================================================================================
-- Version: 1.0.1
-- Author: Koushal Jha
-- Date: May 2026
-- Project: KOSHIV BUS BOOKING SYSTEM
-- Description: Stores connection credentials for all KOSHIV database servers
-- Compliance: IT Act 2000, Indian Financial Regulations
-- ================================================================================
-- VERSION HISTORY:
-- ================================================================================
-- v1.0.0 (Initial Release):
--   - Basic table structure with SERIAL primary key
--   - server_name values: koshiv_bus_admin_server, koshiv_bus_booking_server, koshiv_bus_operations_server
--   - Basic constraints: valid_server_name CHECK, valid_port CHECK
--   - Indexes on server_name and is_active
--   - Auto-update timestamp function and trigger
--   - Initial data for admin server only
--
-- v1.0.1 (Current Version):
--   - Changed credential_id from SERIAL to UUID
--   - Added pgcrypto extension for UUID generation
--   - Added REVOKE PUBLIC and GRANT statements for security
--   - Added table and column comments for documentation
--   - Added note about password encryption at application layer (AES-256)
-- ================================================================================

-- ================================================================================
-- REVOKE DEFAULT PUBLIC ACCESS (Security)
-- ================================================================================

REVOKE ALL ON SCHEMA public FROM PUBLIC;
GRANT USAGE ON SCHEMA public TO koushal;

-- ================================================================================
-- DROP TABLE IF EXISTS (for clean re-run)
-- ================================================================================

DROP TABLE IF EXISTS server_credentials CASCADE;

-- ================================================================================
-- CREATE EXTENSION FOR UUID (if not already enabled)
-- ================================================================================

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ================================================================================
-- CREATE SERVER CREDENTIALS TABLE
-- ================================================================================

CREATE TABLE server_credentials (
    credential_id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
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
-- TABLE AND COLUMN COMMENTS
-- ================================================================================

COMMENT ON TABLE server_credentials IS 'Stores encrypted connection credentials for all database servers';
COMMENT ON COLUMN server_credentials.credential_id IS 'Unique identifier (UUID)';
COMMENT ON COLUMN server_credentials.server_name IS 'Server name: koshiv_bus_admin_server, koshiv_bus_booking_server, koshiv_bus_operations_server';
COMMENT ON COLUMN server_credentials.host IS 'IP address or hostname of the database server';
COMMENT ON COLUMN server_credentials.port IS 'Port number (1024-65535)';
COMMENT ON COLUMN server_credentials.database_name IS 'Database name to connect to';
COMMENT ON COLUMN server_credentials.username IS 'Database user name';
COMMENT ON COLUMN server_credentials.password IS 'Encrypted password (AES-256 at application layer)';
COMMENT ON COLUMN server_credentials.is_active IS 'If false, this connection is not used';
COMMENT ON COLUMN server_credentials.created_at IS 'Record creation timestamp';
COMMENT ON COLUMN server_credentials.updated_at IS 'Record last update timestamp';

-- ================================================================================
-- CREATE INDEXES
-- ================================================================================

CREATE INDEX idx_server_credentials_server_name ON server_credentials(server_name);
CREATE INDEX idx_server_credentials_is_active ON server_credentials(is_active);

-- ================================================================================
-- INSERT INITIAL DATA (ADMIN SERVER ONLY)
-- ================================================================================
-- Note: Password will be encrypted by application before insert.
-- The value shown is plain text for reference. Application must encrypt.
-- ================================================================================

INSERT INTO server_credentials (
    credential_id,
    server_name,
    host,
    port,
    database_name,
    username,
    password,
    is_active
) VALUES (
    gen_random_uuid(),
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
-- GRANT PRIVILEGES
-- ================================================================================

GRANT SELECT, INSERT, UPDATE, DELETE ON server_credentials TO koushal;