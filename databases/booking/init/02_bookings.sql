-- ================================================================================
-- BOOKINGS TABLE – v1.5
-- Database: koshiv_bus_booking
-- Author: Koushal Jha
-- Date: May 2026
-- Project: KOSHIV BUS BOOKING SYSTEM
-- Compliance: IT Act 2000, Indian Financial Regulations
-- ================================================================================
-- VERSION HISTORY:
-- v1.0 – Initial structure
-- v1.1 – Added passenger age/gender encryption, PNR as 10 digits
-- v1.2 – Removed passenger_email, device_fingerprint; added auto_upgrade
-- v1.3 – Final as per original discussion
-- v1.4 – Added cancellation_policy_snapshot, payment_deadline, departure_time, arrival_time, booking_ip, booking_user_agent
-- v1.5 – Added charting_status, is_operator_cancelled, bus_delayed_minutes
-- ================================================================================

-- ================================================================================
-- CREATE SEQUENCE FOR PNR (10-digit, starts at 1000000000)
-- ================================================================================

CREATE SEQUENCE IF NOT EXISTS seq_pnr START 1000000000 INCREMENT 1;

-- ================================================================================
-- CREATE BOOKINGS TABLE
-- ================================================================================

CREATE TABLE IF NOT EXISTS bookings (
    -- Core Identifiers
    booking_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    bus_id UUID NOT NULL,
    seat_id UUID,
    pnr TEXT UNIQUE NOT NULL,
    
    -- Journey and Stations
    from_highway_station TEXT NOT NULL,
    to_highway_station TEXT NOT NULL,
    journey_date DATE NOT NULL,
    departure_time TIME,
    arrival_time TIME,
    pickup_city TEXT NOT NULL,
    drop_city TEXT NOT NULL,
    
    -- Passenger Information (Encrypted PII)
    passenger_name TEXT NOT NULL,
    passenger_age INTEGER NOT NULL,
    passenger_gender TEXT NOT NULL,
    passenger_mobile TEXT NOT NULL,
    
    -- Preferences & Special Category
    seat_preference TEXT,
    special_category TEXT,
    
    -- Quota and Ticket Type
    quota_type TEXT NOT NULL DEFAULT 'general',
    ticket_type TEXT NOT NULL DEFAULT 'Adult',
    
    -- Fare and Charges
    base_fare DECIMAL(10,2) NOT NULL,
    convenience_fee DECIMAL(10,2) NOT NULL DEFAULT 0,
    tatkal_charge DECIMAL(10,2) NOT NULL DEFAULT 0,
    tax_amount DECIMAL(10,2) NOT NULL,
    total_fare DECIMAL(10,2) GENERATED ALWAYS AS (base_fare + convenience_fee + tatkal_charge + tax_amount) STORED,
    
    -- Payment References
    payment_id TEXT,
    payment_status TEXT NOT NULL DEFAULT 'pending',
    payment_deadline TIMESTAMPTZ,
    
    -- Booking Status Lifecycle
    booking_status TEXT NOT NULL DEFAULT 'pending',
    
    -- Timestamps
    booking_time TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    confirmed_at TIMESTAMPTZ,
    cancellation_time TIMESTAMPTZ,
    cancellation_requested_at TIMESTAMPTZ,
    seat_assigned_at TIMESTAMPTZ,
    
    -- Cancellation & Refund
    cancelled_by UUID,
    cancellation_fee DECIMAL(10,2) DEFAULT 0,
    refund_amount DECIMAL(10,2) DEFAULT 0,
    refund_status TEXT DEFAULT 'none',
    refund_initiated_at TIMESTAMPTZ,
    refund_completed_at TIMESTAMPTZ,
    cancellation_policy_snapshot JSONB,
    
    -- Waitlist
    waitlist_position INTEGER,
    
    -- Auto Upgrade
    auto_upgrade BOOLEAN NOT NULL DEFAULT FALSE,
    
    -- Special Cases (v1.5)
    charting_status TEXT DEFAULT 'pending',
    is_operator_cancelled BOOLEAN DEFAULT FALSE,
    bus_delayed_minutes INTEGER DEFAULT 0,
    
    -- Source & Metadata & Legal Audit
    booking_ip INET,
    booking_user_agent TEXT,
    booking_source TEXT NOT NULL DEFAULT 'web',
    extra_data JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- Constraints
    CONSTRAINT journey_date_check CHECK (journey_date >= CURRENT_DATE),
    CONSTRAINT passenger_age_check CHECK (passenger_age BETWEEN 0 AND 120),
    CONSTRAINT fare_positive CHECK (base_fare >= 0 AND convenience_fee >= 0 AND tatkal_charge >= 0 AND tax_amount >= 0),
    CONSTRAINT booking_status_check CHECK (booking_status IN ('pending', 'confirmed', 'cancelled', 'failed', 'waitlisted')),
    CONSTRAINT payment_status_check CHECK (payment_status IN ('pending', 'success', 'failed', 'refunded')),
    CONSTRAINT refund_status_check CHECK (refund_status IN ('none', 'initiated', 'processing', 'completed', 'failed')),
    CONSTRAINT quota_type_check CHECK (quota_type IN ('general', 'ladies', 'tatkal', 'lower_berth', 'disabled', 'duty_pass')),
    CONSTRAINT ticket_type_check CHECK (ticket_type IN ('Adult', 'Child', 'Senior', 'Student')),
    CONSTRAINT booking_source_check CHECK (booking_source IN ('web', 'admin', 'app')),
    CONSTRAINT seat_preference_check CHECK (seat_preference IN ('window', 'aisle', 'middle', 'lower', 'upper', 'none')),
    CONSTRAINT special_category_check CHECK (special_category IN ('medical', 'serviceman', 'none')),
    CONSTRAINT pnr_format_check CHECK (pnr ~ '^[0-9]{10}$'),
    CONSTRAINT passenger_gender_check CHECK (passenger_gender IN ('M', 'F', 'O')),
    CONSTRAINT charting_status_check CHECK (charting_status IN ('pending', 'generated', 'printed')),
    CONSTRAINT bus_delayed_minutes_check CHECK (bus_delayed_minutes >= 0)
);

-- ================================================================================
-- TABLE COMMENTS
-- ================================================================================

COMMENT ON TABLE bookings IS 'Stores all bus booking transactions for KOSHIV system';
COMMENT ON COLUMN bookings.booking_id IS 'Unique identifier (UUID)';
COMMENT ON COLUMN bookings.user_id IS 'References users.user_id (local table). ON DELETE RESTRICT';
COMMENT ON COLUMN bookings.bus_id IS 'Reference to koshiv_bus_operations.buses.bus_id (no FK, app enforced)';
COMMENT ON COLUMN bookings.seat_id IS 'Reference to koshiv_bus_operations.seats.seat_id (allocated after payment)';
COMMENT ON COLUMN bookings.pnr IS '10-digit numeric only (e.g., 1000000000)';
COMMENT ON COLUMN bookings.from_highway_station IS 'e.g., Darbhanga Highway Station';
COMMENT ON COLUMN bookings.to_highway_station IS 'e.g., New Delhi Highway Station';
COMMENT ON COLUMN bookings.journey_date IS 'Must be >= CURRENT_DATE';
COMMENT ON COLUMN bookings.departure_time IS 'Snapshot of scheduled departure time (v1.4)';
COMMENT ON COLUMN bookings.arrival_time IS 'Snapshot of scheduled arrival time (v1.4)';
COMMENT ON COLUMN bookings.pickup_city IS 'City where cab picks up passenger';
COMMENT ON COLUMN bookings.drop_city IS 'City where cab drops passenger';
COMMENT ON COLUMN bookings.passenger_name IS 'Encrypted PII (AES-256 at application layer)';
COMMENT ON COLUMN bookings.passenger_age IS 'Encrypted PII, 0-120';
COMMENT ON COLUMN bookings.passenger_gender IS 'Encrypted PII: M, F, O';
COMMENT ON COLUMN bookings.passenger_mobile IS 'Encrypted PII, 10 digits';
COMMENT ON COLUMN bookings.seat_preference IS 'window, aisle, middle, lower, upper, none';
COMMENT ON COLUMN bookings.special_category IS 'medical, serviceman, none';
COMMENT ON COLUMN bookings.quota_type IS 'general, ladies, tatkal, lower_berth, disabled, duty_pass';
COMMENT ON COLUMN bookings.ticket_type IS 'Adult, Child, Senior, Student';
COMMENT ON COLUMN bookings.base_fare IS 'Includes bus fare + cab fare + all inclusive';
COMMENT ON COLUMN bookings.payment_id IS 'Gateway transaction ID';
COMMENT ON COLUMN bookings.payment_deadline IS 'Expiry for pending booking (v1.4)';
COMMENT ON COLUMN bookings.cancellation_policy_snapshot IS 'Stored rules for refund calculation (v1.4)';
COMMENT ON COLUMN bookings.charting_status IS 'pending, generated, printed (v1.5)';
COMMENT ON COLUMN bookings.is_operator_cancelled IS 'True if bus operator cancels trip (v1.5)';
COMMENT ON COLUMN bookings.bus_delayed_minutes IS 'Minutes of delay at departure (v1.5)';
COMMENT ON COLUMN bookings.booking_ip IS 'IP address of booking request (v1.4)';
COMMENT ON COLUMN bookings.booking_user_agent IS 'Browser/device info for legal audit (v1.4)';

-- ================================================================================
-- CREATE INDEXES
-- ================================================================================

CREATE UNIQUE INDEX IF NOT EXISTS idx_bookings_pnr ON bookings(pnr);
CREATE INDEX IF NOT EXISTS idx_bookings_user_id ON bookings(user_id);
CREATE INDEX IF NOT EXISTS idx_bookings_user_date ON bookings(user_id, journey_date);
CREATE INDEX IF NOT EXISTS idx_bookings_journey_date ON bookings(journey_date);
CREATE INDEX IF NOT EXISTS idx_bookings_bus_id ON bookings(bus_id);
CREATE INDEX IF NOT EXISTS idx_bookings_status ON bookings(booking_status);
CREATE INDEX IF NOT EXISTS idx_bookings_payment_status ON bookings(payment_status);
CREATE INDEX IF NOT EXISTS idx_bookings_payment_deadline ON bookings(payment_deadline) WHERE payment_deadline IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_bookings_created_at ON bookings(created_at);
CREATE INDEX IF NOT EXISTS idx_bookings_charting_status ON bookings(charting_status);
CREATE INDEX IF NOT EXISTS idx_bookings_operator_cancelled ON bookings(is_operator_cancelled) WHERE is_operator_cancelled = true;

-- ================================================================================
-- TRIGGER FUNCTIONS
-- ================================================================================

-- Trigger: Set booking_time if null
CREATE OR REPLACE FUNCTION trigger_set_booking_time()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.booking_time IS NULL THEN
        NEW.booking_time = NOW();
    END IF;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Trigger: Generate 10-digit sequential PNR
CREATE OR REPLACE FUNCTION trigger_generate_pnr()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.pnr IS NULL THEN
        NEW.pnr = LPAD(NEXTVAL('seq_pnr')::TEXT, 10, '0');
    END IF;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Trigger: Set payment_deadline for pending bookings (v1.4)
CREATE OR REPLACE FUNCTION trigger_set_payment_deadline()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.booking_status = 'pending' AND NEW.payment_deadline IS NULL THEN
        NEW.payment_deadline = NOW() + INTERVAL '15 minutes';
    END IF;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Trigger: Update updated_at timestamp
CREATE OR REPLACE FUNCTION trigger_update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- ================================================================================
-- CREATE TRIGGERS
-- ================================================================================

DROP TRIGGER IF EXISTS trg_set_booking_time ON bookings;
CREATE TRIGGER trg_set_booking_time
    BEFORE INSERT ON bookings
    FOR EACH ROW
    EXECUTE FUNCTION trigger_set_booking_time();

DROP TRIGGER IF EXISTS trg_generate_pnr ON bookings;
CREATE TRIGGER trg_generate_pnr
    BEFORE INSERT ON bookings
    FOR EACH ROW
    EXECUTE FUNCTION trigger_generate_pnr();

DROP TRIGGER IF EXISTS trg_set_payment_deadline ON bookings;
CREATE TRIGGER trg_set_payment_deadline
    BEFORE INSERT ON bookings
    FOR EACH ROW
    EXECUTE FUNCTION trigger_set_payment_deadline();

DROP TRIGGER IF EXISTS trg_update_updated_at ON bookings;
CREATE TRIGGER trg_update_updated_at
    BEFORE UPDATE ON bookings
    FOR EACH ROW
    EXECUTE FUNCTION trigger_update_updated_at();

-- ================================================================================
-- VERIFICATION QUERY
-- ================================================================================
-- SELECT column_name, data_type, is_nullable FROM information_schema.columns WHERE table_name = 'bookings' ORDER BY ordinal_position;