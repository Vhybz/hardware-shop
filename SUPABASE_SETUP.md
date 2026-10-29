# Supabase Setup Guide - Adom Mmoroso ENT. POS

This guide details the database architecture and setup for the **Adom Mmoroso ENT. Point of Sale & Inventory Management System** (Building Materials & Hardware Enterprise).

---

## 🚀 Quick Setup Instructions

1. Log in to your **Supabase Dashboard** ([https://app.supabase.com](https://app.supabase.com)).
2. Select or create your project.
3. Open the **SQL Editor** tab in the sidebar.
4. Run the database setup script to create tables, security policies (RLS), indexes, and functions.
5. Copy your **Supabase URL** and **Anon Key** from `Project Settings -> API` into [`assets/.env`](./assets/.env):

```env
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key-here
ARKESEL_API_KEY=your-arkesel-api-key
ARKESEL_SENDER_ID=AdomHardware
ADMIN_PHONE=0542562486
```

---

## 🗄️ Core Database Schema Summary

The application interacts with the following core tables in Supabase:

### 1. `branches`
Stores physical store locations and registration codes.
- `id` (UUID, Primary Key)
- `code` (VARCHAR, Unique - Branch Code)
- `name` (VARCHAR)
- `location` (VARCHAR)
- `latitude` (NUMERIC)
- `longitude` (NUMERIC)
- `radius_meters` (NUMERIC, Default 500)
- `created_at` (TIMESTAMPTZ)

### 2. `users`
System user accounts, roles, security passcodes, and payroll details.
- `id` (UUID, Primary Key)
- `email` (VARCHAR, Unique)
- `first_name` (VARCHAR), `surname` (VARCHAR)
- `phone` (VARCHAR)
- `role` (VARCHAR - `superadmin`, `admin`, `cashier`, `stock_manager`)
- `branch_code` (VARCHAR, Foreign Key -> `branches.code`)
- `passcode` (VARCHAR, Encrypted PIN)
- `is_passcode_enabled` (BOOLEAN)
- `status` (VARCHAR - `approved`, `pending`, `suspended`)
- `base_salary` (NUMERIC)
- `hourly_rate` (NUMERIC)

### 3. `products`
Hardware & building materials catalog, pricing, packaging options, and stock levels.
- `id` (UUID, Primary Key)
- `branch_code` (VARCHAR)
- `name` (VARCHAR)
- `category` (VARCHAR - `BUILDING MATERIALS`, `STEEL & REBAR`, `PLUMBING & PVC`, `ELECTRICALS`, `PAINTS & FINISHES`, `ROOFING & TIMBER`, `TOOLS & FASTENERS`)
- `unit` (VARCHAR - `bags`, `bundles`, `lengths`, `buckets`, `litres`, `kg`, `metres`, `rolls`, `pcs`, `packs`, `boxes`)
- `retail_price` (NUMERIC)
- `wholesale_price` (NUMERIC)
- `cost_price` (NUMERIC)
- `stock_quantity` (NUMERIC - Shop floor stock)
- `warehouse_quantity` (NUMERIC - Central warehouse stock)
- `min_store_stock` (NUMERIC - Reorder alert threshold)
- `sku` (VARCHAR, Barcode / SKU)
- `brand` (VARCHAR)
- `has_packs` (BOOLEAN), `pcs_per_pack` (NUMERIC)
- `has_boxes` (BOOLEAN), `packs_per_box` (NUMERIC)
- `is_unlimited` (BOOLEAN)
- `allow_retail` (BOOLEAN), `allow_wholesale` (BOOLEAN)
- `is_deleted` (BOOLEAN)

### 4. `sales`
Sales transactions, invoice records, and customer payment breakdowns.
- `id` (VARCHAR / UUID, Primary Key)
- `branch_code` (VARCHAR)
- `cashier_id` (UUID), `cashier_name` (VARCHAR)
- `customer_id` (UUID), `customer_name` (VARCHAR), `customer_phone` (VARCHAR)
- `total_amount` (NUMERIC), `amount_paid` (NUMERIC), `balance` (NUMERIC)
- `discount_amount` (NUMERIC)
- `status` (VARCHAR - `completed`, `credit_sale`, `refunded`, `awaiting_deposit`)
- `payments` (JSONB - Payment methods breakdown: Cash, MoMo, Bank Transfer, Card)
- `items` (JSONB - Line items sold)
- `timestamp` (TIMESTAMPTZ)

### 5. `expenses`
Operational expenses, hardware logistics, fuel, offloading, and CEO withdrawals.
- `id` (UUID, Primary Key)
- `branch_code` (VARCHAR)
- `title` (VARCHAR)
- `category` (VARCHAR - `Truck Fuel & Loading`, `Offloading Wages`, `Offsite Delivery`, `Utilities`, `GRA Tax`, `Rent`, `Equipment Maintenance`, `Supplies`, `Other`)
- `amount` (NUMERIC)
- `date` (TIMESTAMPTZ)
- `notes` (TEXT)
- `receipt_url` (TEXT)

### 6. `customers`
Customer CRM records, wholesale account flags, and credit tracking.
- `id` (UUID, Primary Key)
- `branch_code` (VARCHAR)
- `name` (VARCHAR)
- `phone` (VARCHAR), `phone2` (VARCHAR)
- `is_wholesale` (BOOLEAN)
- `total_spent` (NUMERIC), `outstanding_balance` (NUMERIC)

### 7. `stock_transfers` / `warehouse_dispatches`
Inter-branch transfers and warehouse-to-store stock dispatches.
- `id` (UUID, Primary Key)
- `dispatch_number` (VARCHAR)
- `source_location` (VARCHAR)
- `destination_store` (VARCHAR)
- `items` (JSONB)
- `dispatched_by` (VARCHAR)
- `is_confirmed` (BOOLEAN)
- `created_at` (TIMESTAMPTZ)

### 8. `audit_logs`
System action logs for compliance and security audits.
- `id` (UUID, Primary Key)
- `user_id` (UUID), `user_name` (VARCHAR)
- `action` (VARCHAR)
- `entity_type` (VARCHAR), `entity_id` (VARCHAR)
- `new_data` (JSONB)
- `timestamp` (TIMESTAMPTZ)

---

## ⚡ Stored Functions (RPC)

### Stock Increment Function (`increment_stock`)
Handles high-concurrency stock adjustments and offline queue sync safely:

```sql
CREATE OR REPLACE FUNCTION increment_stock(p_id UUID, p_amount NUMERIC)
RETURNS VOID AS $$
BEGIN
  UPDATE products
  SET stock_quantity = COALESCE(stock_quantity, 0) + p_amount
  WHERE id = p_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

---

## 🔒 Storage Buckets

Configure the following public storage buckets in your Supabase project (`Storage -> Create a new bucket` marked as **Public**):

1. **`user-profiles`**: User profile photos, staff avatars, and profile pictures (used by `supabase_user_service.dart`).
2. **`product-images`**: Hardware catalog photos and product images (used by `supabase_product_service.dart`).
3. **`documents`**: PDF files, vouchers, and uploaded business documents (used by `supabase_document_service.dart`).
4. **`receipts`**: Expense receipt images and bill attachments (used by `supabase_expense_service.dart`).
5. **`bank_receipts`**: Bank transfer deposit slips uploaded by cashiers or customers.
