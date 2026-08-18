from flask import Blueprint, jsonify
from datetime import datetime, timezone, timedelta
from database import Database

dashboard_bp = Blueprint("dashboard", __name__)

# India Standard Time = UTC+5:30
_IST = timezone(timedelta(hours=5, minutes=30))


def _today_ist_range():
    """Return (start_utc_iso, end_utc_iso) for today in IST as UTC ISO strings."""
    now_ist = datetime.now(_IST)
    today_start_ist = now_ist.replace(hour=0, minute=0, second=0, microsecond=0)
    today_end_ist = now_ist.replace(hour=23, minute=59, second=59, microsecond=999999)
    # Convert to UTC
    start_utc = today_start_ist.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.%f") + "Z"
    end_utc = today_end_ist.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.%f") + "Z"
    return start_utc, end_utc


@dashboard_bp.route("/dashboard/summary", methods=["GET"])
def get_dashboard_summary():
    try:
        products_coll = Database.get_collection("products")
        customers_coll = Database.get_collection("customers")
        bills_coll = Database.get_collection("bills")

        # ── 1. Total Products ─────────────────────────────────────────────────
        total_products = products_coll.count_documents({})
        print(f"[GET /dashboard/summary] Total products: {total_products}")

        # ── 2. Total Retailers (customers) ────────────────────────────────────
        total_retailers = customers_coll.count_documents({})
        print(f"[GET /dashboard/summary] Total retailers: {total_retailers}")

        # ── 3. Today's Sales (IST) ────────────────────────────────────────────
        start_utc, end_utc = _today_ist_range()
        today_pipeline = [
            {
                "$match": {
                    "createdAt": {"$gte": start_utc, "$lte": end_utc},
                    "status": {"$nin": ["Cancelled", "Failed", "Draft"]},
                }
            },
            {
                "$group": {
                    "_id": None,
                    "totalSales": {"$sum": "$grandTotal"},
                }
            },
        ]
        today_result = list(bills_coll.aggregate(today_pipeline))
        today_sales = today_result[0]["totalSales"] if today_result else 0.0
        print(f"[GET /dashboard/summary] Today's sales (IST {start_utc} to {end_utc}): {today_sales}")

        # ── 4. Stock Value = sum(sellingPrice × total_sizeStock_qty) ─────────
        stock_pipeline = [
            {
                "$project": {
                    "sellingPrice": {"$ifNull": ["$sellingPrice", 0]},
                    "sizeStockValues": {"$objectToArray": {"$ifNull": ["$sizeStock", {}]}},
                }
            },
            {
                "$project": {
                    "sellingPrice": 1,
                    "totalQty": {"$sum": "$sizeStockValues.v"},
                }
            },
            {
                "$project": {
                    "lineValue": {"$multiply": ["$sellingPrice", "$totalQty"]},
                }
            },
            {
                "$group": {
                    "_id": None,
                    "stockValue": {"$sum": "$lineValue"},
                }
            },
        ]
        stock_result = list(products_coll.aggregate(stock_pipeline))
        stock_value = stock_result[0]["stockValue"] if stock_result else 0.0
        print(f"[GET /dashboard/summary] Stock value: {stock_value}")

        return jsonify({
            "status": "success",
            "data": {
                "todaySales": round(float(today_sales), 2),
                "totalProducts": int(total_products),
                "retailers": int(total_retailers),
                "stockValue": round(float(stock_value), 2),
            },
        }), 200

    except Exception as e:
        print(f"[GET /dashboard/summary] ERROR: {e}")
        return jsonify({"status": "error", "message": str(e)}), 500
