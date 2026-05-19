-- ================================================================================
-- PAYMENT TRANSACTIONS TABLE – v1.6
-- REFUND TRANSACTIONS TABLE – v1.0
-- Database: koshiv_bus_booking
-- Author: Koushal Jha
-- Date: May 2026
-- Project: KOSHIV BUS BOOKING SYSTEM
-- Compliance: IT Act 2000, Indian Financial Regulations, GST Audit
-- ================================================================================
-- VERSION HISTORY:
-- v1.0 – Initial release
-- v1.1 – Added payment_method, error_code, error_message, refund_reason, refund_initiated_by, metadata
-- v1.2 – Added gateway_fee, gst_on_fee, settlement_status, settlement_processed_at
-- v1.3 – Added foreign key for refund_initiated_by and CHECK constraint for payment_method
-- v1.4 – Added convenience_fee, gst_on_convenience_fee, client_ip, refund_gateway_fee, is_partial_refund, payment_expires_at, invoice_number, bank_reference_number, merchant_id, is_test_mode
-- v1.5 – Added webhook_signature_valid, refund_initiated_at index, CHECK on refund_gateway_fee, payment_expiry constraint
-- v1.6 – FINAL: Added CHECK constraint for non-refundable convenience fee, status state machine, client_ip INET, gateway_signature_header, child table refund_transactions, composite index for webhook, aggregate columns, trigger for aggregates
-- ================================================================================

-- ================================================================================
-- PAYMENT TRANSACTIONS TABLE
-- ================================================================================

CREATE TABLE IF NOT EXISTS payment_transactions (
    -- Primary identifier
    transaction_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Reference to booking (local to koshiv_bus_booking)
    booking_id UUID NOT NULL,
    
    -- Merchant identification
    merchant_id TEXT NOT NULL,
    
    -- Gateway information
    gateway_name TEXT NOT NULL,
    gateway_order_id TEXT NOT NULL,
    gateway_payment_id TEXT,
    payment_method TEXT,
    
    -- Test mode flag
    is_test_mode BOOLEAN DEFAULT FALSE,
    
    -- Amounts (customer paid)
    amount DECIMAL(10,2) NOT NULL,
    currency TEXT DEFAULT 'INR',
    
    -- Gateway charges (for cost accounting and GST input credit)
    gateway_fee DECIMAL(10,2) DEFAULT 0,
    gst_on_fee DECIMAL(10,2) DEFAULT 0,
    
    -- Platform convenience fee (non-refundable)
    convenience_fee DECIMAL(10,2) DEFAULT 0,
    gst_on_convenience_fee DECIMAL(10,2) DEFAULT 0,
    
    -- Net settlement amount (computed)
    net_settlement DECIMAL(10,2) GENERATED ALWAYS AS (
        amount - gateway_fee - gst_on_fee - COALESCE(total_refunded_amount, 0) - COALESCE(total_refund_gateway_fee, 0)
    ) STORED,
    
    -- Payment expiry (seat lock release)
    payment_expires_at TIMESTAMPTZ,
    
    -- Status (gateway-specific)
    status TEXT NOT NULL DEFAULT 'created',
    
    -- Idempotency (prevent duplicate processing)
    idempotency_key TEXT UNIQUE NOT NULL,
    
    -- Webhook data and retries
    gateway_response JSONB,
    gateway_signature_header TEXT,
    webhook_received_at TIMESTAMPTZ,
    webhook_processed_at TIMESTAMPTZ,
    webhook_retry_count INTEGER DEFAULT 0,
    webhook_signature_valid BOOLEAN DEFAULT FALSE,
    
    -- Failure details
    error_code TEXT,
    error_message TEXT,
    
    -- Aggregate refund tracking (summary from child table)
    total_refunded_amount DECIMAL(10,2) DEFAULT 0,
    total_refund_gateway_fee DECIMAL(10,2) DEFAULT 0,
    refund_status TEXT DEFAULT 'none',
    last_refund_processed_at TIMESTAMPTZ,
    
    -- Settlement reconciliation
    settlement_status TEXT DEFAULT 'pending',
    settlement_processed_at TIMESTAMPTZ,
    
    -- Client information (for legal audit)
    client_ip INET,
    client_user_agent TEXT,
    
    -- Bank reference (for reconciliation)
    bank_reference_number TEXT,
    
    -- Invoice reference (for GST audit)
    invoice_number TEXT,
    
    -- Additional metadata
    metadata JSONB,
    
    -- Timestamps
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- Constraints
    CONSTRAINT amount_positive CHECK (amount >= 0),
    CONSTRAINT gateway_fee_positive CHECK (gateway_fee >= 0 AND gst_on_fee >= 0),
    CONSTRAINT convenience_fee_positive CHECK (convenience_fee >= 0 AND gst_on_convenience_fee >= 0),
    CONSTRAINT refund_amounts_positive CHECK (total_refunded_amount >= 0 AND total_refund_gateway_fee >= 0),
    CONSTRAINT status_check CHECK (status IN ('created', 'authorized', 'captured', 'failed', 'refunded')),
    CONSTRAINT refund_status_check CHECK (refund_status IN ('none', 'partial', 'full', 'failed')),
    CONSTRAINT settlement_status_check CHECK (settlement_status IN ('pending', 'settled', 'failed')),
    CONSTRAINT currency_check CHECK (currency IN ('INR')),
    CONSTRAINT payment_method_check CHECK (payment_method IN ('UPI', 'Credit Card', 'Debit Card', 'NetBanking', 'Wallet')),
    CONSTRAINT payment_expiry_check CHECK (payment_expires_at IS NULL OR payment_expires_at <= created_at + INTERVAL '1 hour'),
    -- Non-refundable convenience fee protection
    CONSTRAINT non_refundable_convenience_fee CHECK (total_refunded_amount <= amount - (convenience_fee + gst_on_convenience_fee)),
    -- Status state machine (cannot refund failed/created payment)
    CONSTRAINT status_state_machine CHECK (NOT (status IN ('created', 'failed') AND refund_status NOT IN ('none')))
);

-- ================================================================================
-- FOREIGN KEY (booking_id references bookings table)
-- ================================================================================

ALTER TABLE payment_transactions DROP CONSTRAINT IF EXISTS fk_payment_transactions_booking;
ALTER TABLE payment_transactions ADD CONSTRAINT fk_payment_transactions_booking
    FOREIGN KEY (booking_id) REFERENCES bookings(booking_id) ON DELETE CASCADE;

-- ================================================================================
-- TABLE COMMENTS – PAYMENT_TRANSACTIONS
-- ================================================================================

COMMENT ON TABLE payment_transactions IS 'Stores all payment gateway interactions for bookings - supports GST audit, partial refunds, and legal compliance';
COMMENT ON COLUMN payment_transactions.transaction_id IS 'Unique identifier (UUID)';
COMMENT ON COLUMN payment_transactions.booking_id IS 'References bookings(booking_id) - ON DELETE CASCADE';
COMMENT ON COLUMN payment_transactions.merchant_id IS 'Identifies sub-merchant or branch';
COMMENT ON COLUMN payment_transactions.gateway_name IS 'razorpay, phonepe, paytm, etc.';
COMMENT ON COLUMN payment_transactions.gateway_order_id IS 'Order ID returned by gateway at creation';
COMMENT ON COLUMN payment_transactions.gateway_payment_id IS 'Final payment ID after capture (webhook)';
COMMENT ON COLUMN payment_transactions.payment_method IS 'UPI, Credit Card, Debit Card, NetBanking, Wallet';
COMMENT ON COLUMN payment_transactions.is_test_mode IS 'Sandbox vs production transaction';
COMMENT ON COLUMN payment_transactions.amount IS 'Amount paid by customer';
COMMENT ON COLUMN payment_transactions.gateway_fee IS 'Fee charged by payment gateway (MDR)';
COMMENT ON COLUMN payment_transactions.gst_on_fee IS 'GST component on gateway fee';
COMMENT ON COLUMN payment_transactions.convenience_fee IS 'Platform convenience fee - NON-REFUNDABLE';
COMMENT ON COLUMN payment_transactions.gst_on_convenience_fee IS 'GST on convenience fee - NON-REFUNDABLE';
COMMENT ON COLUMN payment_transactions.net_settlement IS 'Net expected settlement after fees and refunds (computed)';
COMMENT ON COLUMN payment_transactions.payment_expires_at IS 'If payment not captured by this time, release seat lock';
COMMENT ON COLUMN payment_transactions.status IS 'created, authorized, captured, failed, refunded';
COMMENT ON COLUMN payment_transactions.idempotency_key IS 'Prevents duplicate processing - unique';
COMMENT ON COLUMN payment_transactions.gateway_response IS 'Full raw webhook payload';
COMMENT ON COLUMN payment_transactions.gateway_signature_header IS 'Raw signature header from gateway (legal evidence)';
COMMENT ON COLUMN payment_transactions.webhook_signature_valid IS 'Whether webhook signature was verified';
COMMENT ON COLUMN payment_transactions.total_refunded_amount IS 'Sum of all refund_amount from refund_transactions';
COMMENT ON COLUMN payment_transactions.total_refund_gateway_fee IS 'Sum of refund_gateway_fee from refund_transactions';
COMMENT ON COLUMN payment_transactions.refund_status IS 'none, partial, full, failed';
COMMENT ON COLUMN payment_transactions.settlement_status IS 'pending, settled, failed';
COMMENT ON COLUMN payment_transactions.client_ip IS 'IP address of client at payment time (INET type)';
COMMENT ON COLUMN payment_transactions.bank_reference_number IS 'UTR (net banking) or RRN (UPI) - indexed';
COMMENT ON COLUMN payment_transactions.invoice_number IS 'GST invoice number linked to this payment';

-- ================================================================================
-- CREATE INDEXES – PAYMENT_TRANSACTIONS
-- ================================================================================

CREATE INDEX IF NOT EXISTS idx_payment_transactions_booking_id ON payment_transactions(booking_id);
CREATE INDEX IF NOT EXISTS idx_payment_transactions_gateway_order_id ON payment_transactions(gateway_order_id);
CREATE INDEX IF NOT EXISTS idx_payment_transactions_gateway_payment_id ON payment_transactions(gateway_payment_id);
CREATE INDEX IF NOT EXISTS idx_payment_transactions_gateway_payment_order ON payment_transactions(gateway_payment_id, gateway_order_id);
CREATE UNIQUE INDEX IF NOT EXISTS idx_payment_transactions_idempotency_key ON payment_transactions(idempotency_key);
CREATE INDEX IF NOT EXISTS idx_payment_transactions_status ON payment_transactions(status);
CREATE INDEX IF NOT EXISTS idx_payment_transactions_refund_status ON payment_transactions(refund_status);
CREATE INDEX IF NOT EXISTS idx_payment_transactions_settlement_status ON payment_transactions(settlement_status);
CREATE INDEX IF NOT EXISTS idx_payment_transactions_created_at ON payment_transactions(created_at);
CREATE INDEX IF NOT EXISTS idx_payment_transactions_payment_expires_at ON payment_transactions(payment_expires_at) WHERE status = 'created';
CREATE INDEX IF NOT EXISTS idx_payment_transactions_bank_reference ON payment_transactions(bank_reference_number);

-- ================================================================================
-- CREATE REFUND TRANSACTIONS TABLE (CHILD TABLE)
-- ================================================================================

CREATE TABLE IF NOT EXISTS refund_transactions (
    refund_event_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    parent_transaction_id UUID NOT NULL,
    refund_amount DECIMAL(10,2) NOT NULL,
    refund_gateway_fee DECIMAL(10,2) DEFAULT 0,
    gateway_refund_id TEXT,
    refund_reason TEXT,
    refund_initiated_by UUID,
    refund_initiated_at TIMESTAMPTZ DEFAULT NOW(),
    refund_processed_at TIMESTAMPTZ,
    refund_status TEXT DEFAULT 'pending',
    failure_reason TEXT,
    cancelled_item_ids JSONB,
    credit_note_number TEXT,
    metadata JSONB,
    
    -- Constraints
    CONSTRAINT refund_amount_positive CHECK (refund_amount >= 0),
    CONSTRAINT refund_gateway_fee_positive CHECK (refund_gateway_fee >= 0),
    CONSTRAINT refund_status_check CHECK (refund_status IN ('pending', 'processed', 'failed'))
);

-- ================================================================================
-- FOREIGN KEY – REFUND_TRANSACTIONS
-- ================================================================================

ALTER TABLE refund_transactions DROP CONSTRAINT IF EXISTS fk_refund_parent_transaction;
ALTER TABLE refund_transactions ADD CONSTRAINT fk_refund_parent_transaction
    FOREIGN KEY (parent_transaction_id) REFERENCES payment_transactions(transaction_id) ON DELETE CASCADE;

-- ================================================================================
-- TABLE COMMENTS – REFUND_TRANSACTIONS
-- ================================================================================

COMMENT ON TABLE refund_transactions IS 'Stores each individual refund event (partial or full) for audit trail - supports railway-style partial cancellations';
COMMENT ON COLUMN refund_transactions.refund_event_id IS 'Unique identifier for each refund event';
COMMENT ON COLUMN refund_transactions.parent_transaction_id IS 'References payment_transactions(transaction_id)';
COMMENT ON COLUMN refund_transactions.refund_amount IS 'Amount refunded in this event';
COMMENT ON COLUMN refund_transactions.refund_gateway_fee IS 'Gateway fee refunded (if any)';
COMMENT ON COLUMN refund_transactions.gateway_refund_id IS 'Refund ID from payment gateway';
COMMENT ON COLUMN refund_transactions.refund_reason IS 'Reason for refund';
COMMENT ON COLUMN refund_transactions.refund_initiated_by IS 'User ID who initiated refund (NULL = system)';
COMMENT ON COLUMN refund_transactions.cancelled_item_ids IS 'Seat numbers or passenger IDs being cancelled (railway model)';
COMMENT ON COLUMN refund_transactions.credit_note_number IS 'GST credit note for partial reversal';
COMMENT ON COLUMN refund_transactions.refund_status IS 'pending, processed, failed';

-- ================================================================================
-- CREATE INDEXES – REFUND_TRANSACTIONS
-- ================================================================================

CREATE INDEX IF NOT EXISTS idx_refund_parent ON refund_transactions(parent_transaction_id);
CREATE INDEX IF NOT EXISTS idx_refund_initiated_at ON refund_transactions(refund_initiated_at);
CREATE INDEX IF NOT EXISTS idx_refund_initiated_by ON refund_transactions(refund_initiated_by);

-- ================================================================================
-- TRIGGER FUNCTIONS
-- ================================================================================

-- Trigger: Update updated_at timestamp
CREATE OR REPLACE FUNCTION trigger_payment_update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Trigger: Set payment_expiry for created status
CREATE OR REPLACE FUNCTION trigger_set_payment_expiry()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.payment_expires_at IS NULL AND NEW.status = 'created' THEN
        NEW.payment_expires_at = NOW() + INTERVAL '15 minutes';
    END IF;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Trigger: Update aggregate refunds from child table
CREATE OR REPLACE FUNCTION trigger_update_aggregate_refunds()
RETURNS TRIGGER AS $$
DECLARE
    v_parent_id UUID;
    v_total_refunded DECIMAL;
    v_total_refund_fee DECIMAL;
    v_refund_status TEXT;
BEGIN
    -- Determine parent_transaction_id from NEW or OLD based on operation
    IF TG_OP = 'DELETE' THEN
        v_parent_id = OLD.parent_transaction_id;
    ELSE
        v_parent_id = NEW.parent_transaction_id;
    END IF;
    
    -- Calculate aggregates
    SELECT COALESCE(SUM(refund_amount), 0), COALESCE(SUM(refund_gateway_fee), 0)
    INTO v_total_refunded, v_total_refund_fee
    FROM refund_transactions
    WHERE parent_transaction_id = v_parent_id;
    
    -- Determine refund status
    IF v_total_refunded >= (SELECT amount - (convenience_fee + gst_on_convenience_fee) FROM payment_transactions WHERE transaction_id = v_parent_id) THEN
        v_refund_status = 'full';
    ELSIF v_total_refunded > 0 THEN
        v_refund_status = 'partial';
    ELSE
        v_refund_status = 'none';
    END IF;
    
    -- Update parent table
    UPDATE payment_transactions SET
        total_refunded_amount = v_total_refunded,
        total_refund_gateway_fee = v_total_refund_fee,
        refund_status = v_refund_status,
        last_refund_processed_at = NOW(),
        updated_at = NOW()
    WHERE transaction_id = v_parent_id;
    
    RETURN NULL;
END;
$$ language 'plpgsql';

-- ================================================================================
-- CREATE TRIGGERS
-- ================================================================================

DROP TRIGGER IF EXISTS trg_payment_update_updated_at ON payment_transactions;
CREATE TRIGGER trg_payment_update_updated_at
    BEFORE UPDATE ON payment_transactions
    FOR EACH ROW
    EXECUTE FUNCTION trigger_payment_update_updated_at();

DROP TRIGGER IF EXISTS trg_set_payment_expiry ON payment_transactions;
CREATE TRIGGER trg_set_payment_expiry
    BEFORE INSERT ON payment_transactions
    FOR EACH ROW
    EXECUTE FUNCTION trigger_set_payment_expiry();

DROP TRIGGER IF EXISTS trg_update_aggregate_refunds_insert ON refund_transactions;
CREATE TRIGGER trg_update_aggregate_refunds_insert
    AFTER INSERT ON refund_transactions
    FOR EACH ROW
    EXECUTE FUNCTION trigger_update_aggregate_refunds();

DROP TRIGGER IF EXISTS trg_update_aggregate_refunds_update ON refund_transactions;
CREATE TRIGGER trg_update_aggregate_refunds_update
    AFTER UPDATE ON refund_transactions
    FOR EACH ROW
    EXECUTE FUNCTION trigger_update_aggregate_refunds();

DROP TRIGGER IF EXISTS trg_update_aggregate_refunds_delete ON refund_transactions;
CREATE TRIGGER trg_update_aggregate_refunds_delete
    AFTER DELETE ON refund_transactions
    FOR EACH ROW
    EXECUTE FUNCTION trigger_update_aggregate_refunds();