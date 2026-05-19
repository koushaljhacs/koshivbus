-- ================================================================================
-- CANCELLATION POLICIES TABLE – v1.0
-- Database: koshiv_bus_booking
-- Author: Koushal Jha
-- Date: May 2026
-- Project: KOSHIV BUS BOOKING SYSTEM
-- Compliance: IT Act 2000, Indian Financial Regulations
-- ================================================================================
-- VERSION HISTORY:
-- v1.0 (May 2026) – Initial release
-- ================================================================================

-- ================================================================================
-- CREATE CANCELLATION POLICIES TABLE
-- ================================================================================

CREATE TABLE IF NOT EXISTS cancellation_policies (
    policy_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    policy_name TEXT NOT NULL,
    applicable_bus_types TEXT[],
    applicable_quota_types TEXT[],
    rules JSONB NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    effective_from TIMESTAMPTZ NOT NULL,
    effective_to TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Constraints
    CONSTRAINT effective_date_check CHECK (effective_to IS NULL OR effective_to > effective_from)
);

-- ================================================================================
-- TABLE COMMENTS
-- ================================================================================

COMMENT ON TABLE cancellation_policies IS 'Defines flexible cancellation rules based on time before departure, class of travel, quota type, and waitlist status';
COMMENT ON COLUMN cancellation_policies.policy_id IS 'Unique identifier (UUID)';
COMMENT ON COLUMN cancellation_policies.policy_name IS 'e.g., Standard Cancellation, Tatkal Cancellation';
COMMENT ON COLUMN cancellation_policies.applicable_bus_types IS 'Array of bus classes - empty means all types';
COMMENT ON COLUMN cancellation_policies.applicable_quota_types IS 'Array of quotas - empty means all quotas';
COMMENT ON COLUMN cancellation_policies.rules IS 'JSONB storing time bands and waitlist rule. Structure: {"bands": [{"min_hours": 48, "max_hours": null, "deduction_type": "percentage", "deduction_value": 10}], "waitlist_rule": {"deduction_type": "fixed", "deduction_value": 20}}';
COMMENT ON COLUMN cancellation_policies.is_active IS 'If true, this policy is available for new bookings';
COMMENT ON COLUMN cancellation_policies.effective_from IS 'Policy effective start date';
COMMENT ON COLUMN cancellation_policies.effective_to IS 'Policy effective end date - NULL means no expiry';
COMMENT ON COLUMN cancellation_policies.created_at IS 'Record creation timestamp';
COMMENT ON COLUMN cancellation_policies.updated_at IS 'Record last update timestamp';

-- ================================================================================
-- CREATE INDEXES
-- ================================================================================

CREATE INDEX IF NOT EXISTS idx_cancellation_policies_active ON cancellation_policies(is_active, effective_from, effective_to);
CREATE INDEX IF NOT EXISTS idx_cancellation_policies_applicability ON cancellation_policies(applicable_bus_types, applicable_quota_types);

-- ================================================================================
-- TRIGGER FUNCTION FOR UPDATED_AT
-- ================================================================================

CREATE OR REPLACE FUNCTION trigger_cancellation_policies_update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- ================================================================================
-- CREATE TRIGGER
-- ================================================================================

DROP TRIGGER IF EXISTS trg_cancellation_policies_update_updated_at ON cancellation_policies;
CREATE TRIGGER trg_cancellation_policies_update_updated_at
    BEFORE UPDATE ON cancellation_policies
    FOR EACH ROW
    EXECUTE FUNCTION trigger_cancellation_policies_update_updated_at();

-- ================================================================================
-- SAMPLE INSERT DATA (For reference - application will insert actual policies)
-- ================================================================================

INSERT INTO cancellation_policies (
    policy_id,
    policy_name,
    applicable_bus_types,
    applicable_quota_types,
    rules,
    is_active,
    effective_from,
    effective_to
) VALUES (
    gen_random_uuid(),
    'Standard Cancellation',
    NULL,
    NULL,
    '{
        "bands": [
            {"min_hours": 48, "max_hours": null, "deduction_type": "percentage", "deduction_value": 10},
            {"min_hours": 12, "max_hours": 48, "deduction_type": "percentage", "deduction_value": 25},
            {"min_hours": 4, "max_hours": 12, "deduction_type": "percentage", "deduction_value": 50},
            {"min_hours": 0, "max_hours": 4, "deduction_type": "fixed", "deduction_value": 180}
        ],
        "waitlist_rule": {"deduction_type": "fixed", "deduction_value": 20}
    }'::JSONB,
    TRUE,
    '2026-01-01 00:00:00+05:30',
    NULL
) ON CONFLICT DO NOTHING;

INSERT INTO cancellation_policies (
    policy_id,
    policy_name,
    applicable_bus_types,
    applicable_quota_types,
    rules,
    is_active,
    effective_from,
    effective_to
) VALUES (
    gen_random_uuid(),
    'Tatkal Cancellation',
    NULL,
    ARRAY['tatkal'],
    '{
        "bands": [
            {"min_hours": 48, "max_hours": null, "deduction_type": "percentage", "deduction_value": 25},
            {"min_hours": 12, "max_hours": 48, "deduction_type": "percentage", "deduction_value": 50},
            {"min_hours": 4, "max_hours": 12, "deduction_type": "percentage", "deduction_value": 75},
            {"min_hours": 0, "max_hours": 4, "deduction_type": "fixed", "deduction_value": 300}
        ],
        "waitlist_rule": {"deduction_type": "fixed", "deduction_value": 50}
    }'::JSONB,
    TRUE,
    '2026-01-01 00:00:00+05:30',
    NULL
) ON CONFLICT DO NOTHING;