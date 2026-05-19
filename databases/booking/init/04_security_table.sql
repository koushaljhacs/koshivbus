-- ================================================================================
-- SECURITY TABLES – v1.0.0
-- Database: koshiv_bus_user (Server 1)
-- Author: Koushal Jha
-- Date: May 2026
-- Project: KOSHIV BUS BOOKING SYSTEM
-- Compliance: IT Act 2000, Indian Financial Regulations
-- ================================================================================
-- VERSION HISTORY:
-- v1.0.0 (May 2026) – Initial release: login_audit, trusted_devices, ip_blacklist, 
--                     account_lock_history, user_session_tracker
-- ================================================================================

-- ================================================================================
-- TABLE 1: login_audit
-- ================================================================================

CREATE TABLE IF NOT EXISTS login_audit (
    audit_id BIGSERIAL PRIMARY KEY,
    user_id UUID,
    ip_address INET,
    device_fingerprint VARCHAR(255),
    attempt_time TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    success BOOLEAN NOT NULL,
    failure_reason VARCHAR(100),
    captcha_solved BOOLEAN NOT NULL DEFAULT FALSE,
    response_time_ms INTEGER,
    
    CONSTRAINT fk_login_audit_user FOREIGN KEY (user_id) 
        REFERENCES users(user_id) ON DELETE SET NULL
);

COMMENT ON TABLE login_audit IS 'Logs every login attempt (success/failure) for security analysis';
COMMENT ON COLUMN login_audit.audit_id IS 'Auto-increment identifier';
COMMENT ON COLUMN login_audit.user_id IS 'User who attempted login - NULL for non-existent user attempts';
COMMENT ON COLUMN login_audit.ip_address IS 'Client IP address';
COMMENT ON COLUMN login_audit.device_fingerprint IS 'SHA-256 hash of device info';
COMMENT ON COLUMN login_audit.attempt_time IS 'Login attempt timestamp';
COMMENT ON COLUMN login_audit.success IS 'Whether login succeeded';
COMMENT ON COLUMN login_audit.failure_reason IS 'INVALID_PASSWORD, ACCOUNT_LOCKED, etc.';
COMMENT ON COLUMN login_audit.captcha_solved IS 'Whether CAPTCHA was solved';
COMMENT ON COLUMN login_audit.response_time_ms IS 'Time taken to respond in milliseconds';

CREATE INDEX IF NOT EXISTS idx_login_audit_user ON login_audit(user_id);
CREATE INDEX IF NOT EXISTS idx_login_audit_time ON login_audit(attempt_time);
CREATE INDEX IF NOT EXISTS idx_login_audit_ip ON login_audit(ip_address);

-- ================================================================================
-- TABLE 2: trusted_devices
-- ================================================================================

CREATE TABLE IF NOT EXISTS trusted_devices (
    user_id UUID NOT NULL,
    device_fingerprint VARCHAR(255) NOT NULL,
    device_name VARCHAR(100),
    registered_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_used_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    
    PRIMARY KEY (user_id, device_fingerprint),
    CONSTRAINT fk_trusted_devices_user FOREIGN KEY (user_id) 
        REFERENCES users(user_id) ON DELETE CASCADE
);

COMMENT ON TABLE trusted_devices IS 'Stores devices that user has marked as trusted (skip additional OTP)';
COMMENT ON COLUMN trusted_devices.user_id IS 'User who owns the device';
COMMENT ON COLUMN trusted_devices.device_fingerprint IS 'SHA-256 hash of device';
COMMENT ON COLUMN trusted_devices.device_name IS 'User-provided name (e.g., My iPhone)';
COMMENT ON COLUMN trusted_devices.registered_at IS 'When device was registered';
COMMENT ON COLUMN trusted_devices.last_used_at IS 'Last activity timestamp';
COMMENT ON COLUMN trusted_devices.is_active IS 'Whether device is trusted';

CREATE INDEX IF NOT EXISTS idx_trusted_devices_fingerprint ON trusted_devices(device_fingerprint);
CREATE INDEX IF NOT EXISTS idx_trusted_devices_last_used ON trusted_devices(last_used_at);

-- ================================================================================
-- TABLE 3: ip_blacklist
-- ================================================================================

CREATE TABLE IF NOT EXISTS ip_blacklist (
    ip_address INET PRIMARY KEY,
    reason VARCHAR(200) NOT NULL,
    blocked_until TIMESTAMPTZ,
    blocked_by VARCHAR(50) NOT NULL DEFAULT 'system',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE ip_blacklist IS 'Manually or automatically block malicious IP addresses';
COMMENT ON COLUMN ip_blacklist.ip_address IS 'IP address to block';
COMMENT ON COLUMN ip_blacklist.reason IS 'BRUTE_FORCE, DDoS, MALICIOUS_SCAN, etc.';
COMMENT ON COLUMN ip_blacklist.blocked_until IS 'When block expires - NULL = permanent';
COMMENT ON COLUMN ip_blacklist.blocked_by IS 'system or admin';
COMMENT ON COLUMN ip_blacklist.created_at IS 'When block was created';

CREATE INDEX IF NOT EXISTS idx_ip_blacklist_expiry ON ip_blacklist(blocked_until) WHERE blocked_until IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_ip_blacklist_created ON ip_blacklist(created_at);

-- ================================================================================
-- TABLE 4: account_lock_history
-- ================================================================================

CREATE TABLE IF NOT EXISTS account_lock_history (
    lock_id BIGSERIAL PRIMARY KEY,
    user_id UUID NOT NULL,
    lock_type VARCHAR(50) NOT NULL,
    lock_duration_minutes INTEGER NOT NULL,
    reason VARCHAR(200) NOT NULL,
    locked_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    unlocked_at TIMESTAMPTZ,
    unlocked_by VARCHAR(50),
    
    CONSTRAINT fk_lock_history_user FOREIGN KEY (user_id) 
        REFERENCES users(user_id) ON DELETE CASCADE,
    CONSTRAINT lock_type_check CHECK (lock_type IN ('IP', 'DEVICE', 'ACCOUNT', 'GEO', 'TIME')),
    CONSTRAINT lock_duration_positive CHECK (lock_duration_minutes > 0)
);

COMMENT ON TABLE account_lock_history IS 'Tracks all account lock events (IP lock, device lock, account lock)';
COMMENT ON COLUMN account_lock_history.lock_id IS 'Auto-increment identifier';
COMMENT ON COLUMN account_lock_history.user_id IS 'User who was locked';
COMMENT ON COLUMN account_lock_history.lock_type IS 'IP, DEVICE, ACCOUNT, GEO, TIME';
COMMENT ON COLUMN account_lock_history.lock_duration_minutes IS 'Duration of lock in minutes';
COMMENT ON COLUMN account_lock_history.reason IS 'Why lock was applied';
COMMENT ON COLUMN account_lock_history.locked_at IS 'When lock started';
COMMENT ON COLUMN account_lock_history.unlocked_at IS 'When lock ended - NULL if still locked';
COMMENT ON COLUMN account_lock_history.unlocked_by IS 'system, admin, timeout';

CREATE INDEX IF NOT EXISTS idx_lock_history_user ON account_lock_history(user_id);
CREATE INDEX IF NOT EXISTS idx_lock_history_locked_at ON account_lock_history(locked_at);
CREATE INDEX IF NOT EXISTS idx_lock_history_type ON account_lock_history(lock_type);

-- ================================================================================
-- TABLE 5: user_session_tracker
-- ================================================================================

CREATE TABLE IF NOT EXISTS user_session_tracker (
    session_id VARCHAR(255) PRIMARY KEY,
    user_id UUID NOT NULL,
    device_fingerprint VARCHAR(255) NOT NULL,
    ip_address INET,
    user_agent TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMPTZ NOT NULL,
    last_activity_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    
    CONSTRAINT fk_session_user FOREIGN KEY (user_id) 
        REFERENCES users(user_id) ON DELETE CASCADE
);

COMMENT ON TABLE user_session_tracker IS 'Tracks active user sessions for concurrent session limiting and blacklisting';
COMMENT ON COLUMN user_session_tracker.session_id IS 'JWT jti claim or session ID';
COMMENT ON COLUMN user_session_tracker.user_id IS 'User who owns the session';
COMMENT ON COLUMN user_session_tracker.device_fingerprint IS 'Device identifier';
COMMENT ON COLUMN user_session_tracker.ip_address IS 'Session IP address';
COMMENT ON COLUMN user_session_tracker.user_agent IS 'Browser/device info';
COMMENT ON COLUMN user_session_tracker.created_at IS 'Session start timestamp';
COMMENT ON COLUMN user_session_tracker.expires_at IS 'Session expiry timestamp';
COMMENT ON COLUMN user_session_tracker.last_activity_at IS 'Last API call timestamp';
COMMENT ON COLUMN user_session_tracker.is_active IS 'Whether session is active';

CREATE INDEX IF NOT EXISTS idx_session_user ON user_session_tracker(user_id);
CREATE INDEX IF NOT EXISTS idx_session_expires ON user_session_tracker(expires_at) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_session_fingerprint ON user_session_tracker(device_fingerprint);

-- ================================================================================
-- VERIFICATION QUERIES
-- ================================================================================

-- Check all tables exist
-- SELECT tablename FROM pg_tables WHERE schemaname = 'public' AND tablename IN (
--     'login_audit', 'trusted_devices', 'ip_blacklist', 'account_lock_history', 'user_session_tracker'
-- );

-- Check columns of login_audit
-- SELECT column_name, data_type FROM information_schema.columns 
-- WHERE table_name = 'login_audit' ORDER BY ordinal_position;