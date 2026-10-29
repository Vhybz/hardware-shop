-- =============================================================================
-- ADOM MMOROSO ENT. - POS & INVENTORY MANAGEMENT SYSTEM
-- COMPLETE PRODUCTION SUPABASE DATABASE SCHEMA
-- Building Materials & Hardware Enterprise (Wholesale & Retail)
-- Location: Zongo One Way, Sunyani, Ghana
-- =============================================================================

-- Enable required Extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- =============================================================================
-- 1. BRANCHES TABLE
-- Stores physical store locations, GPS coordinates, and registration codes.
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.branches (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) UNIQUE NOT NULL,
    name VARCHAR(150) NOT NULL,
    location VARCHAR(255) DEFAULT 'Zongo One Way, Sunyani, Ghana',
    latitude NUMERIC(10, 7) DEFAULT 7.3349,
    longitude NUMERIC(10, 7) DEFAULT -2.3123,
    radius_meters NUMERIC(10, 2) DEFAULT 500.0,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Seed Default Main Branch
INSERT INTO public.branches (code, name, location, latitude, longitude, radius_meters)
VALUES ('HQ', 'Adom Mmoroso ENT. Main Branch', 'Zongo One Way, Sunyani, Ghana', 7.3349, -2.3123, 500.0)
ON CONFLICT (code) DO NOTHING;

-- =============================================================================
-- 2. USERS TABLE
-- Extended user profile linked to Supabase Auth (auth.users).
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.users (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email VARCHAR(255) UNIQUE NOT NULL,
    first_name VARCHAR(100) NOT NULL,
    surname VARCHAR(100) NOT NULL,
    phone VARCHAR(50),
    gender VARCHAR(20),
    dob DATE,
    photo_url TEXT,
    role VARCHAR(50) DEFAULT 'cashier', -- superadmin, admin, cashier, stock_manager
    branch_code VARCHAR(50) REFERENCES public.branches(code) ON DELETE SET NULL,
    secondary_roles JSONB DEFAULT '[]'::jsonb,
    shop_location VARCHAR(150),
    passcode VARCHAR(255),
    is_passcode_enabled BOOLEAN DEFAULT false,
    passcode_sent_at TIMESTAMPTZ,
    status VARCHAR(30) DEFAULT 'pending', -- approved, pending, suspended
    temp_role VARCHAR(50),
    temp_role_expires_at TIMESTAMPTZ,
    temp_role_granted_by VARCHAR(100),
    temporary_role VARCHAR(50),
    temp_role_start TIMESTAMPTZ,
    temp_role_end TIMESTAMPTZ,
    enabled_permissions JSONB DEFAULT '[]'::jsonb,
    newly_added_permissions JSONB DEFAULT '[]'::jsonb,
    base_salary NUMERIC(12, 2) DEFAULT 0.0,
    hourly_rate NUMERIC(12, 2) DEFAULT 0.0,
    salary_amount NUMERIC(12, 2) DEFAULT 0.0,
    salary_day INT DEFAULT 1,
    last_salary_date DATE,
    last_payment_was_advance BOOLEAN DEFAULT false,
    total_salary_paid NUMERIC(12, 2) DEFAULT 0.0,
    total_advances_taken NUMERIC(12, 2) DEFAULT 0.0,
    theme_mode VARCHAR(20) DEFAULT 'system',
    theme_primary_color INT,
    last_seen TIMESTAMPTZ,
    is_deleted BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_users_email ON public.users(email);
CREATE INDEX IF NOT EXISTS idx_users_phone ON public.users(phone);
CREATE INDEX IF NOT EXISTS idx_users_branch_code ON public.users(branch_code);
CREATE INDEX IF NOT EXISTS idx_users_status ON public.users(status);

-- =============================================================================
-- 3. CUSTOMERS TABLE
-- Customer relationship management (CRM) and debt records.
-- Created before sales table so sales can reference customer_id.
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.customers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    branch_code VARCHAR(50) REFERENCES public.branches(code) ON DELETE CASCADE,
    name VARCHAR(150) NOT NULL,
    phone VARCHAR(50),
    phone2 VARCHAR(50),
    email VARCHAR(255),
    address TEXT,
    business_name VARCHAR(150),
    is_wholesale BOOLEAN DEFAULT false,
    total_spent NUMERIC(12, 2) DEFAULT 0.0,
    outstanding_balance NUMERIC(12, 2) DEFAULT 0.0,
    custom_discount_percentage NUMERIC(5, 2) DEFAULT 0.0,
    notes TEXT,
    is_deleted BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_customers_phone ON public.customers(phone);
CREATE INDEX IF NOT EXISTS idx_customers_branch ON public.customers(branch_code);
CREATE INDEX IF NOT EXISTS idx_customers_is_deleted ON public.customers(is_deleted);

-- =============================================================================
-- 4. PRODUCTS TABLE
-- Hardware & building materials product catalog, stock levels, and prices.
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.products (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    branch_code VARCHAR(50) REFERENCES public.branches(code) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    retail_price NUMERIC(12, 2) DEFAULT 0.0,
    wholesale_price NUMERIC(12, 2) DEFAULT 0.0,
    cost_price NUMERIC(12, 2) DEFAULT 0.0,
    retail_brackets JSONB DEFAULT '[]'::jsonb,
    wholesale_brackets JSONB DEFAULT '[]'::jsonb,
    image_url TEXT DEFAULT '',
    category VARCHAR(100) NOT NULL, -- BUILDING MATERIALS, STEEL & REBAR, PLUMBING & PVC, ELECTRICALS, PAINTS & FINISHES, ROOFING & TIMBER, TOOLS & FASTENERS
    stock_quantity NUMERIC(12, 2) DEFAULT 0.0,
    warehouse_quantity NUMERIC(12, 2) DEFAULT 0.0,
    min_store_stock NUMERIC(12, 2) DEFAULT 5.0,
    sku VARCHAR(100),
    brand VARCHAR(100),
    size VARCHAR(100) DEFAULT 'Standard',
    warehouse_location VARCHAR(150),
    unit VARCHAR(50) DEFAULT 'pcs', -- bags, bundles, lengths, buckets, litres, kg, metres, rolls, pcs, packs, boxes
    has_packs BOOLEAN DEFAULT true,
    has_boxes BOOLEAN DEFAULT true,
    pcs_per_pack NUMERIC(10, 2) DEFAULT 12.0,
    packs_per_box NUMERIC(10, 2) DEFAULT 10.0,
    pcs_per_box NUMERIC(10, 2) DEFAULT 120.0,
    discount_percentage NUMERIC(5, 2) DEFAULT 0.0,
    promo_start_date TIMESTAMPTZ,
    promo_end_date TIMESTAMPTZ,
    promo_target VARCHAR(20) DEFAULT 'both',
    promo_customer_target VARCHAR(30) DEFAULT 'all',
    target_customer_id VARCHAR(100),
    is_deleted BOOLEAN DEFAULT false,
    is_unlimited BOOLEAN DEFAULT false,
    allow_retail BOOLEAN DEFAULT true,
    allow_wholesale BOOLEAN DEFAULT true,
    low_stock_threshold NUMERIC(12, 2) DEFAULT 10.0,
    daily_stock_added NUMERIC(12, 2) DEFAULT 0.0,
    last_stock_update TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_products_category ON public.products(category);
CREATE INDEX IF NOT EXISTS idx_products_branch_code ON public.products(branch_code);
CREATE INDEX IF NOT EXISTS idx_products_sku ON public.products(sku);
CREATE INDEX IF NOT EXISTS idx_products_is_deleted ON public.products(is_deleted);
CREATE INDEX IF NOT EXISTS idx_products_branch_is_deleted ON public.products(branch_code, is_deleted);

-- =============================================================================
-- 5. SALES TABLE
-- Sales transactions, invoices, items, and multi-payment breakdowns.
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.sales (
    id VARCHAR(100) PRIMARY KEY,
    branch_code VARCHAR(50) REFERENCES public.branches(code) ON DELETE CASCADE,
    cashier_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
    cashier_name VARCHAR(150) NOT NULL,
    customer_id UUID REFERENCES public.customers(id) ON DELETE SET NULL,
    customer_name VARCHAR(150),
    customer_phone VARCHAR(50),
    total_amount NUMERIC(12, 2) DEFAULT 0.0,
    amount_paid NUMERIC(12, 2) DEFAULT 0.0,
    balance NUMERIC(12, 2) DEFAULT 0.0,
    discount_amount NUMERIC(12, 2) DEFAULT 0.0,
    status VARCHAR(50) DEFAULT 'completed', -- completed, credit_sale, refunded, awaiting_deposit
    payments JSONB DEFAULT '[]'::jsonb,
    items JSONB DEFAULT '[]'::jsonb,
    timestamp TIMESTAMPTZ DEFAULT now(),
    is_active BOOLEAN DEFAULT true,
    bank_receipt_url TEXT,
    bank_receipt_id VARCHAR(100),
    is_verified BOOLEAN DEFAULT false,
    is_debt_cleared BOOLEAN DEFAULT false,
    cleared_at TIMESTAMPTZ,
    cleared_by VARCHAR(150),
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_sales_branch_code ON public.sales(branch_code);
CREATE INDEX IF NOT EXISTS idx_sales_cashier_id ON public.sales(cashier_id);
CREATE INDEX IF NOT EXISTS idx_sales_customer_id ON public.sales(customer_id);
CREATE INDEX IF NOT EXISTS idx_sales_timestamp ON public.sales(timestamp);
CREATE INDEX IF NOT EXISTS idx_sales_status ON public.sales(status);
CREATE INDEX IF NOT EXISTS idx_sales_is_active ON public.sales(is_active);
CREATE INDEX IF NOT EXISTS idx_sales_branch_timestamp ON public.sales(branch_code, timestamp);

-- =============================================================================
-- 6. EXPENSES TABLE
-- Operating and hardware logistics expense records.
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.expenses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    branch_code VARCHAR(50) REFERENCES public.branches(code) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    category VARCHAR(100) NOT NULL, -- Truck Fuel & Loading, Offloading Wages, Offsite Delivery, Utilities, GRA Tax, Rent, Equipment Maintenance, Supplies, Other
    amount NUMERIC(12, 2) DEFAULT 0.0,
    date TIMESTAMPTZ DEFAULT now(),
    notes TEXT,
    receipt_url TEXT,
    is_deleted BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_expenses_branch_code ON public.expenses(branch_code);
CREATE INDEX IF NOT EXISTS idx_expenses_category ON public.expenses(category);
CREATE INDEX IF NOT EXISTS idx_expenses_date ON public.expenses(date);

-- =============================================================================
-- 7. STOCK TRANSFERS TABLE
-- Inter-branch stock transfers.
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.stock_transfers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    transfer_number VARCHAR(100) UNIQUE NOT NULL,
    source_branch_code VARCHAR(50) NOT NULL,
    destination_branch_code VARCHAR(50) NOT NULL,
    items JSONB DEFAULT '[]'::jsonb,
    status VARCHAR(50) DEFAULT 'pending',
    sent_by VARCHAR(150),
    received_by VARCHAR(150),
    transfer_time TIMESTAMPTZ DEFAULT now(),
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_stock_transfers_source ON public.stock_transfers(source_branch_code);
CREATE INDEX IF NOT EXISTS idx_stock_transfers_destination ON public.stock_transfers(destination_branch_code);

-- =============================================================================
-- 8. WAREHOUSE DISPATCHES TABLE
-- Central warehouse dispatches to retail store.
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.warehouse_dispatches (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    dispatch_number VARCHAR(100) UNIQUE NOT NULL,
    source_location VARCHAR(150) DEFAULT 'Main HQ Warehouse',
    destination_store VARCHAR(150) DEFAULT 'Adom Mmoroso ENT.',
    items JSONB DEFAULT '[]'::jsonb,
    notes TEXT,
    dispatched_by VARCHAR(150),
    is_confirmed BOOLEAN DEFAULT true,
    date TIMESTAMPTZ DEFAULT now(),
    created_at TIMESTAMPTZ DEFAULT now()
);

-- =============================================================================
-- 9. WAREHOUSE BATCHES & INTAKES TABLE
-- Supplier shipment intake and batch tracking.
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.warehouse_batches (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    batch_number VARCHAR(100),
    supplier_name VARCHAR(150),
    category VARCHAR(100) DEFAULT 'BUILDING MATERIALS',
    warehouse_location VARCHAR(150) DEFAULT 'Main HQ Warehouse',
    date TIMESTAMPTZ DEFAULT now(),
    items JSONB DEFAULT '[]'::jsonb,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- =============================================================================
-- 10. SALARY RECORDS & PAYROLL TABLE
-- Staff salary payments and advance audit logs.
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.salary_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    user_name VARCHAR(150) NOT NULL,
    amount NUMERIC(12, 2) DEFAULT 0.0,
    is_advance BOOLEAN DEFAULT false,
    payment_date TIMESTAMPTZ DEFAULT now(),
    target_month DATE,
    notes TEXT,
    recorded_by VARCHAR(150),
    branch_code VARCHAR(50) REFERENCES public.branches(code) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_salary_records_user ON public.salary_records(user_id);
CREATE INDEX IF NOT EXISTS idx_salary_records_branch ON public.salary_records(branch_code);

-- =============================================================================
-- 11. TILL MOVEMENTS TABLE
-- Till cash-in, cash-out, CEO withdrawals, and daily sales closure records.
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.till_movements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    branch_code VARCHAR(50) REFERENCES public.branches(code) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    type VARCHAR(50) NOT NULL, -- cash_in, cash_out
    amount NUMERIC(12, 2) DEFAULT 0.0,
    running_balance NUMERIC(12, 2) DEFAULT 0.0,
    timestamp TIMESTAMPTZ DEFAULT now(),
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_till_movements_branch ON public.till_movements(branch_code);
CREATE INDEX IF NOT EXISTS idx_till_movements_timestamp ON public.till_movements(timestamp);

-- =============================================================================
-- 12. SALE RETURNS TABLE
-- Customer product returns and voucher logs.
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.sale_returns (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    return_number VARCHAR(100) UNIQUE NOT NULL,
    original_sale_id VARCHAR(100) REFERENCES public.sales(id) ON DELETE CASCADE,
    customer_name VARCHAR(150),
    customer_phone VARCHAR(50),
    items JSONB DEFAULT '[]'::jsonb,
    total_refund_amount NUMERIC(12, 2) DEFAULT 0.0,
    reason TEXT,
    processed_by VARCHAR(150),
    branch_code VARCHAR(50) REFERENCES public.branches(code) ON DELETE CASCADE,
    timestamp TIMESTAMPTZ DEFAULT now(),
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_sale_returns_original_sale ON public.sale_returns(original_sale_id);
CREATE INDEX IF NOT EXISTS idx_sale_returns_branch ON public.sale_returns(branch_code);

-- =============================================================================
-- 13. SUPPLIER RETURNS TABLE
-- Returns to hardware suppliers and manufacturers.
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.supplier_returns (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    return_number VARCHAR(100) UNIQUE NOT NULL,
    supplier_name VARCHAR(150) NOT NULL,
    items JSONB DEFAULT '[]'::jsonb,
    total_refund_amount NUMERIC(12, 2) DEFAULT 0.0,
    reason TEXT,
    processed_by VARCHAR(150),
    branch_code VARCHAR(50) REFERENCES public.branches(code) ON DELETE CASCADE,
    timestamp TIMESTAMPTZ DEFAULT now(),
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_supplier_returns_branch ON public.supplier_returns(branch_code);

-- =============================================================================
-- 14. RESTOCK REQUESTS TABLE
-- Customer stock availability requests.
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.restock_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_name VARCHAR(150) NOT NULL,
    customer_phone VARCHAR(50) NOT NULL,
    product_name VARCHAR(255) NOT NULL,
    variant_or_notes TEXT,
    branch_code VARCHAR(50) REFERENCES public.branches(code) ON DELETE CASCADE,
    is_notified BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_restock_requests_branch ON public.restock_requests(branch_code);

-- =============================================================================
-- 15. AUDIT LOGS TABLE
-- System action audit trails.
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID,
    user_name VARCHAR(150),
    action VARCHAR(100) NOT NULL,
    entity_type VARCHAR(100),
    entity_id VARCHAR(100),
    new_data JSONB,
    timestamp TIMESTAMPTZ DEFAULT now(),
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_audit_logs_user ON public.audit_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_action ON public.audit_logs(action);
CREATE INDEX IF NOT EXISTS idx_audit_logs_timestamp ON public.audit_logs(timestamp);

-- =============================================================================
-- 16. DOCUMENTS TABLE
-- Store document attachments and PDF metadata.
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.documents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title VARCHAR(255) NOT NULL,
    category VARCHAR(100) DEFAULT 'General',
    file_url TEXT NOT NULL,
    file_size_bytes BIGINT DEFAULT 0,
    uploaded_by VARCHAR(150),
    branch_code VARCHAR(50) REFERENCES public.branches(code) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_documents_branch ON public.documents(branch_code);

-- =============================================================================
-- 17. NOTIFICATIONS TABLE
-- Push notifications and system messages.
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    message TEXT NOT NULL,
    type VARCHAR(50) DEFAULT 'info',
    is_read BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_notifications_user_read ON public.notifications(user_id, is_read);

-- =============================================================================
-- STORED FUNCTIONS & RPCs
-- Atomic operations for offline sync and concurrency safety.
-- =============================================================================

-- Increment Store Stock RPC
CREATE OR REPLACE FUNCTION increment_stock(p_id UUID, p_amount NUMERIC)
RETURNS VOID AS $$
BEGIN
  UPDATE public.products
  SET stock_quantity = COALESCE(stock_quantity, 0) + p_amount,
      last_stock_update = now()
  WHERE id = p_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Decrement Store Stock RPC
CREATE OR REPLACE FUNCTION decrement_stock(p_id UUID, p_amount NUMERIC)
RETURNS VOID AS $$
BEGIN
  UPDATE public.products
  SET stock_quantity = GREATEST(0, COALESCE(stock_quantity, 0) - p_amount),
      last_stock_update = now()
  WHERE id = p_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Increment Warehouse Stock RPC
CREATE OR REPLACE FUNCTION increment_warehouse_stock(p_id UUID, p_amount NUMERIC)
RETURNS VOID AS $$
BEGIN
  UPDATE public.products
  SET warehouse_quantity = COALESCE(warehouse_quantity, 0) + p_amount,
      last_stock_update = now()
  WHERE id = p_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Decrement Warehouse Stock RPC
CREATE OR REPLACE FUNCTION decrement_warehouse_stock(p_id UUID, p_amount NUMERIC)
RETURNS VOID AS $$
BEGIN
  UPDATE public.products
  SET warehouse_quantity = GREATEST(0, COALESCE(warehouse_quantity, 0) - p_amount),
      last_stock_update = now()
  WHERE id = p_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Transfer Warehouse to Store Stock RPC
CREATE OR REPLACE FUNCTION transfer_warehouse_to_store_stock(p_id UUID, p_amount NUMERIC)
RETURNS VOID AS $$
BEGIN
  UPDATE public.products
  SET warehouse_quantity = GREATEST(0, COALESCE(warehouse_quantity, 0) - p_amount),
      stock_quantity = COALESCE(stock_quantity, 0) + p_amount,
      last_stock_update = now()
  WHERE id = p_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- Enable Row Level Security on all public tables
-- =============================================================================

ALTER TABLE public.branches ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sales ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.expenses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.stock_transfers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.warehouse_dispatches ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.warehouse_batches ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.salary_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.till_movements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sale_returns ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.supplier_returns ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.restock_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- Permissive public access policies (allows sign-up, offline sync & app operations)
CREATE POLICY "Allow public read/write on branches" ON public.branches FOR ALL TO public USING (true) WITH CHECK (true);
CREATE POLICY "Allow public read/write on users" ON public.users FOR ALL TO public USING (true) WITH CHECK (true);
CREATE POLICY "Allow public read/write on products" ON public.products FOR ALL TO public USING (true) WITH CHECK (true);
CREATE POLICY "Allow public read/write on customers" ON public.customers FOR ALL TO public USING (true) WITH CHECK (true);
CREATE POLICY "Allow public read/write on sales" ON public.sales FOR ALL TO public USING (true) WITH CHECK (true);
CREATE POLICY "Allow public read/write on expenses" ON public.expenses FOR ALL TO public USING (true) WITH CHECK (true);
CREATE POLICY "Allow public read/write on stock_transfers" ON public.stock_transfers FOR ALL TO public USING (true) WITH CHECK (true);
CREATE POLICY "Allow public read/write on warehouse_dispatches" ON public.warehouse_dispatches FOR ALL TO public USING (true) WITH CHECK (true);
CREATE POLICY "Allow public read/write on warehouse_batches" ON public.warehouse_batches FOR ALL TO public USING (true) WITH CHECK (true);
CREATE POLICY "Allow public read/write on salary_records" ON public.salary_records FOR ALL TO public USING (true) WITH CHECK (true);
CREATE POLICY "Allow public read/write on till_movements" ON public.till_movements FOR ALL TO public USING (true) WITH CHECK (true);
CREATE POLICY "Allow public read/write on sale_returns" ON public.sale_returns FOR ALL TO public USING (true) WITH CHECK (true);
CREATE POLICY "Allow public read/write on supplier_returns" ON public.supplier_returns FOR ALL TO public USING (true) WITH CHECK (true);
CREATE POLICY "Allow public read/write on restock_requests" ON public.restock_requests FOR ALL TO public USING (true) WITH CHECK (true);
CREATE POLICY "Allow public read/write on audit_logs" ON public.audit_logs FOR ALL TO public USING (true) WITH CHECK (true);
CREATE POLICY "Allow public read/write on documents" ON public.documents FOR ALL TO public USING (true) WITH CHECK (true);
CREATE POLICY "Allow public read/write on notifications" ON public.notifications FOR ALL TO public USING (true) WITH CHECK (true);

-- Allow anonymous read on products for customer catalog
CREATE POLICY "Allow anon read products" ON public.products FOR SELECT TO anon USING (is_deleted = false);

-- =============================================================================
-- HIGH-SPEED PERFORMANCE INDEXES & QUERY PLANNER OPTIMIZATIONS
-- Maximize query throughput and protect Supabase Free Tier IOPS/RAM budgets.
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_products_branch ON public.products (branch_code);
CREATE INDEX IF NOT EXISTS idx_products_category ON public.products (category);
CREATE INDEX IF NOT EXISTS idx_products_deleted ON public.products (is_deleted);

CREATE INDEX IF NOT EXISTS idx_sales_timestamp_desc ON public.sales (timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_sales_branch ON public.sales (branch_code);
CREATE INDEX IF NOT EXISTS idx_sales_cashier ON public.sales (cashier_id);
CREATE INDEX IF NOT EXISTS idx_sales_status ON public.sales (status);

CREATE INDEX IF NOT EXISTS idx_customers_phone ON public.customers (phone);
CREATE INDEX IF NOT EXISTS idx_customers_branch ON public.customers (branch_code);

CREATE INDEX IF NOT EXISTS idx_expenses_date_desc ON public.expenses (date DESC);
CREATE INDEX IF NOT EXISTS idx_expenses_branch ON public.expenses (branch_code);

CREATE INDEX IF NOT EXISTS idx_users_email ON public.users (email);
CREATE INDEX IF NOT EXISTS idx_users_phone ON public.users (phone);
CREATE INDEX IF NOT EXISTS idx_users_branch ON public.users (branch_code);

CREATE INDEX IF NOT EXISTS idx_audit_logs_timestamp_desc ON public.audit_logs (timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_audit_logs_branch ON public.audit_logs (entity_type);

-- Update query planner statistics for instantaneous execution
ANALYZE public.products;
ANALYZE public.sales;
ANALYZE public.customers;
ANALYZE public.users;
ANALYZE public.expenses;
ANALYZE public.audit_logs;

