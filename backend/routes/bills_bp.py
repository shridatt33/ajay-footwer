from flask import Blueprint, request, jsonify
from datetime import datetime, timezone, timedelta
from database import Database
from models.bill_model import BillModel

bills_bp = Blueprint("bills", __name__)

_IST = timezone(timedelta(hours=5, minutes=30))


# ── Invoice number generator (backend-authoritative) ─────────────────────────

def _generate_invoice_no():
    """Generate a unique INV-YYYY-NNNNNN invoice number from MongoDB."""
    coll = Database.get_collection("bills")
    year = datetime.now(_IST).year
    prefix = f"INV-{year}-"
    max_num = 0
    for doc in coll.find({}, {"invoiceNo": 1}):
        inv = doc.get("invoiceNo", "")
        if inv.startswith(prefix):
            try:
                num = int(inv[len(prefix):])
                if num > max_num:
                    max_num = num
            except ValueError:
                pass
    next_num = max_num + 1
    return f"{prefix}{next_num:06d}"


# ── GET /bills ────────────────────────────────────────────────────────────────

@bills_bp.route("/bills", methods=["GET"])
def get_bills():
    """Return all bills sorted newest-first. Supports ?search= and ?status= filters."""
    try:
        coll = Database.get_collection("bills")
        query = {}

        search = request.args.get("search", "").strip()
        if search:
            query["$or"] = [
                {"invoiceNo": {"$regex": search, "$options": "i"}},
                {"customerName": {"$regex": search, "$options": "i"}},
                {"customerMobile": {"$regex": search, "$options": "i"}},
            ]

        status_filter = request.args.get("status", "").strip()
        if status_filter:
            query["status"] = {"$regex": f"^{status_filter}$", "$options": "i"}

        docs = list(coll.find(query).sort("createdAt", -1))
        formatted = [BillModel.format_document(d) for d in docs]
        print(f"[GET /bills] Returning {len(formatted)} bills")
        return jsonify({"status": "success", "count": len(formatted), "data": formatted}), 200
    except Exception as e:
        print(f"[GET /bills] ERROR: {e}")
        return jsonify({"status": "error", "message": str(e)}), 500


# ── GET /bills/<invoice_no> ───────────────────────────────────────────────────

@bills_bp.route("/bills/<invoice_no>", methods=["GET"])
def get_bill_by_id(invoice_no):
    try:
        coll = Database.get_collection("bills")
        doc = coll.find_one({"invoiceNo": invoice_no})
        if not doc:
            return jsonify({"status": "error", "message": "Bill not found"}), 404
        return jsonify({"status": "success", "data": BillModel.format_document(doc)}), 200
    except Exception as e:
        print(f"[GET /bills/{invoice_no}] ERROR: {e}")
        return jsonify({"status": "error", "message": str(e)}), 500


# ── POST /bills ───────────────────────────────────────────────────────────────

@bills_bp.route("/bills", methods=["POST"])
def create_bill():
    """
    Create a bill and atomically deduct stock.
    Flow:
      1. Validate input
      2. Validate stock availability
      3. Generate invoice number (backend-authoritative)
      4. Save bill to MongoDB
      5. Deduct stock
      6. Update customer totals
      7. Return saved bill
    """
    try:
        data = request.get_json() or {}
        print(f"[POST /bills] Received payload keys: {list(data.keys())}")

        bills_coll = Database.get_collection("bills")
        products_coll = Database.get_collection("products")
        customers_coll = Database.get_collection("customers")

        # ── 1. Extract & validate ─────────────────────────────────────────────
        customer_id = str(data.get("customerId", "")).strip()
        customer_name = str(data.get("customerName", "")).strip()
        customer_shop_name = str(data.get("customerShopName", "")).strip()
        customer_mobile = str(data.get("customerMobile", "")).strip()
        raw_products = data.get("products", [])
        payment_status = str(data.get("status", "Paid")).strip()
        business_profile_snap = data.get("businessProfile", {})

        if not raw_products:
            return jsonify({"status": "error", "message": "Bill products list cannot be empty"}), 400
        if not customer_name:
            return jsonify({"status": "error", "message": "Customer name is required"}), 400

        # ── 2. Validate & recalculate totals server-side ──────────────────────
        validated_products = []
        recalculated_subtotal = 0.0

        for p in raw_products:
            pid = str(p.get("productId", "")).strip()
            size = str(p.get("size", "")).strip()
            qty = int(p.get("quantity", 1))
            unit_price = float(p.get("unitPrice", p.get("sellingPrice", 0)))
            product_name = str(p.get("productName", "")).strip()

            if qty <= 0 or unit_price <= 0:
                return jsonify({"status": "error",
                                "message": f"Invalid quantity or price for product {pid}"}), 400

            # Validate stock if productId + size provided
            if pid and size:
                prod_doc = products_coll.find_one({"productId": pid}, {"sizeStock": 1})
                if prod_doc:
                    available = prod_doc.get("sizeStock", {}).get(size, 0)
                    if available < qty:
                        return jsonify({
                            "status": "error",
                            "message": f"Insufficient stock for {product_name} size {size}. "
                                       f"Available: {available}, Requested: {qty}"
                        }), 400

            line_total = round(unit_price * qty, 2)
            recalculated_subtotal += line_total

            validated_products.append({
                "productId": pid,
                "productName": product_name,
                "size": size,
                "quantity": qty,
                "unitPrice": unit_price,
                "lineTotal": line_total,
            })

        discount = float(data.get("discount", 0.0))
        tax = float(data.get("tax", 0.0))
        grand_total = round(recalculated_subtotal - discount + tax, 2)

        # ── 3. Generate invoice number (server-authoritative) ─────────────────
        invoice_no = _generate_invoice_no()
        print(f"[POST /bills] Generated invoice: {invoice_no}")

        # ── 4. Save bill ──────────────────────────────────────────────────────
        now_iso = datetime.utcnow().isoformat() + "Z"
        new_doc = {
            "invoiceNo": invoice_no,
            "customerId": customer_id,
            "customerName": customer_name,
            "customerShopName": customer_shop_name,
            "customerMobile": customer_mobile,
            "products": validated_products,
            "subtotal": round(recalculated_subtotal, 2),
            "discount": discount,
            "tax": tax,
            "grandTotal": grand_total,
            "status": payment_status,
            "businessProfile": business_profile_snap,
            "createdAt": now_iso,
        }

        result = bills_coll.insert_one(new_doc)
        print(f"[POST /bills] Bill inserted: {result.inserted_id}")

        # ── 5. Deduct stock ───────────────────────────────────────────────────
        for p in validated_products:
            pid = p["productId"]
            size = p["size"]
            qty = p["quantity"]
            if pid and size:
                products_coll.update_one(
                    {"productId": pid},
                    {"$inc": {f"sizeStock.{size}": -qty}},
                )

        # ── 6. Update customer totals ─────────────────────────────────────────
        if customer_id:
            inc_op = {"totalBills": 1}
            if payment_status.lower() == "pending":
                inc_op["outstandingBalance"] = grand_total
            customers_coll.update_one({"customerId": customer_id}, {"$inc": inc_op})

        formatted = BillModel.format_document(new_doc)
        return jsonify({
            "status": "success",
            "message": "Bill saved in MongoDB successfully",
            "data": formatted,
        }), 201

    except Exception as e:
        print(f"[POST /bills] ERROR: {e}")
        return jsonify({"status": "error", "message": str(e)}), 500
