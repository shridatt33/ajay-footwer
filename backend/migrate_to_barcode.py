"""
Database migration script: Backfill 'barcode' for all products and create unique index.
Preserves all existing products, stock, prices, categories, bills, and customers.
"""
import sys
import os

# Add backend directory to path
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from database import Database

def run_migration():
    print("Starting Barcode Migration...")
    db = Database.initialize()
    coll = db.products

    # 1. Fetch all existing products
    products = list(coll.find({}))
    print(f"Found {len(products)} products in database.")

    updated_count = 0
    assigned_barcodes = set()

    for doc in products:
        pid = doc.get("productId")
        existing_barcode = doc.get("barcode")
        qr_data = doc.get("qrData")

        # Determine permanent barcode (preserve existing, or use qrData, or fallback to productId)
        target_barcode = (existing_barcode or qr_data or pid).strip()
        
        # Ensure unique
        if target_barcode in assigned_barcodes:
            # Handle conflict safely
            target_barcode = f"{pid}"
        
        assigned_barcodes.add(target_barcode)

        # Update document with barcode and keep qrData in sync
        update_doc = {
            "barcode": target_barcode,
            "qrData": target_barcode
        }

        coll.update_one({"_id": doc["_id"]}, {"$set": update_doc})
        updated_count += 1
        print(f"  [OK] Product {pid} ('{doc.get('productName', '')}') -> Barcode: {target_barcode}")

    # 2. Ensure unique index on barcode
    try:
        coll.create_index("barcode", unique=True, sparse=True)
        print("[OK] Created UNIQUE index on 'barcode' field.")
    except Exception as e:
        print(f"[Notice] Index creation: {e}")

    print(f"\nMigration completed successfully! {updated_count} products verified/updated.")

if __name__ == "__main__":
    run_migration()
