CREATE TABLE IF NOT EXISTS users (
    user_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    username TEXT UNIQUE NOT NULL,
    email TEXT UNIQUE NOT NULL,
    mobile TEXT UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    full_name TEXT,
    date_of_birth DATE NOT NULL,
    address TEXT,
    gender TEXT,
    nationality TEXT DEFAULT 'Indian',
    profile_photo_url TEXT,
    terms_accepted_at TIMESTAMPTZ NOT NULL,
    marketing_consent BOOLEAN NOT NULL DEFAULT FALSE,
    registration_source TEXT NOT NULL DEFAULT 'web',
    is_verified BOOLEAN NOT NULL DEFAULT FALSE,
    email_verified_at TIMESTAMPTZ,
    mobile_verified_at TIMESTAMPTZ,
    is_locked BOOLEAN NOT NULL DEFAULT FALSE,
    is_two_factor_enabled BOOLEAN NOT NULL DEFAULT FALSE,
    failed_login_attempts INTEGER NOT NULL DEFAULT 0,
    last_password_change TIMESTAMPTZ,
    last_mobile_number_change TIMESTAMPTZ,
    last_email_change TIMESTAMPTZ,
    account_closure_requested_at TIMESTAMPTZ,
    deleted_at TIMESTAMPTZ,
    preferred_contact_method TEXT DEFAULT 'email',
    preferred_language TEXT DEFAULT 'en',
    timezone TEXT DEFAULT 'Asia/Kolkata',
    reset_token TEXT,
    reset_token_expiry TIMESTAMPTZ,
    extra_data JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_login_at TIMESTAMPTZ,
    last_login_ip INET,
    CONSTRAINT valid_gender CHECK (gender IN ('Male', 'Female', 'Other', 'Prefer not to say')),
    CONSTRAINT valid_contact_method CHECK (preferred_contact_method IN ('email', 'sms', 'both')),
    CONSTRAINT valid_registration_source CHECK (registration_source IN ('web', 'mobile_app', 'admin'))
);

CREATE INDEX IF NOT EXISTS idx_users_username ON users(username);
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_mobile ON users(mobile);
CREATE INDEX IF NOT EXISTS idx_users_active ON users(user_id) WHERE is_locked = false AND deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_users_deleted ON users(deleted_at) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_users_terms ON users(terms_accepted_at);
CREATE INDEX IF NOT EXISTS idx_users_registration_source ON users(registration_source);
CREATE INDEX IF NOT EXISTS idx_users_created_at ON users(created_at);

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

DROP TRIGGER IF EXISTS update_users_updated_at ON users;

CREATE TRIGGER update_users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();