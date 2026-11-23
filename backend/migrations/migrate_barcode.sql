-- ====================================================================
-- PostgreSQL Barcode Migration Script: Footwear Management Application
-- Preserves all existing tables, products, stock, prices, bills, customers.
-- Adds UNIQUE Code 128 barcode column and backfills existing records.
-- ====================================================================

-- 1. Add barcode column if not exists
ALTER TABLE IF EXISTS products 
ADD COLUMN IF NOT EXISTS barcode VARCHAR(100);

-- 2. Backfill existing products where barcode is NULL
-- Uses product_code / product_id as the initial permanent barcode
UPDATE products 
SET barcode = COALESCE(barcode, qr_data, product_code, product_id)
WHERE barcode IS NULL;

-- 3. Set NOT NULL constraint on barcode for products
ALTER TABLE IF EXISTS products 
ALTER COLUMN barcode SET NOT NULL;

-- 4. Create UNIQUE index and constraint on barcode
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'uq_products_barcode'
    ) THEN
        ALTER TABLE products ADD CONSTRAINT uq_products_barcode UNIQUE (barcode);
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_products_barcode ON products(barcode);

-- Verification Query:
-- SELECT product_id, product_name, barcode, selling_price, total_stock FROM products;
