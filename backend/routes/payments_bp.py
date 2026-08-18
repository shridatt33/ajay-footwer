from flask import Blueprint, request, jsonify
from datetime import datetime
from database import Database
from models.payment_model import PaymentModel

payments_bp = Blueprint("payments", __name__)


def _generate_payment_id():
    """Generate a sequential payment ID like PAY-000001."""
    coll = Database.get_collection("payments")
    count = coll.count_documents({})
    max_num = count
    for doc in coll.find({}, {"paymentId": 1}):
        pid = doc.get("paymentId", "")
        if pid.startswith("PAY-"):
            try:
                num = int(pid.replace("PAY-", ""))
                if num > max_num:
                    max_num = num
            except ValueError:
                pass
    return f"PAY-{max_num + 1:06d}"


# ── POST /payments ──────────────────────────────────────────────────────────────

@payments_bp.route("/payments", methods=["POST"])
def create_payment():
    """
    Record a payment received from a customer.
    Body fields:
        customerId          (required)
        customerName        (required)
        customerShopName
        amount              (required, > 0)
        paymentMode         (Cash / UPI / Bank Transfer / Cheque / Other)
        reference
        note
        paymentDate         (ISO string; defaults to now)
        previousOutstanding (balance BEFORE this payment)
        balanceAfter        (balance AFTER this payment = previous - amount)
    Side-effect:
        Updates customers.outstandingBalance in MongoDB.
    """
    try:
        data = request.get_json() or {}
        print(f"[POST /payments] Payload: {data}")

        customer_id = data.get("customerId", "").strip()
        customer_name = data.get("customerName", "").strip()
        amount = float(data.get("amount", 0))

        if not customer_id:
            return jsonify({"status": "error", "message": "customerId is required"}), 400
        if not customer_name:
            return jsonify({"status": "error", "message": "customerName is required"}), 400
        if amount <= 0:
            return jsonify({"status": "error", "message": "amount must be greater than 0"}), 400

        # Fetch current customer to validate amount
        customers_coll = Database.get_collection("customers")
        customer_doc = customers_coll.find_one({"customerId": customer_id})
        if not customer_doc:
            return jsonify({"status": "error", "message": "Customer not found"}), 404

        current_outstanding = float(customer_doc.get("outstandingBalance", 0.0))

        if amount > current_outstanding + 0.001:  # small float tolerance
            return jsonify({
                "status": "error",
                "message": f"Payment ₹{amount} exceeds outstanding balance ₹{current_outstanding}"
            }), 400

        # Use the server-side outstanding as the true source of truth
        previous_outstanding = current_outstanding
        balance_after = max(0.0, current_outstanding - amount)

        now_iso = datetime.utcnow().isoformat() + "Z"
        payment_date = data.get("paymentDate", now_iso)
        payment_id = _generate_payment_id()

        new_payment = {
            "paymentId": payment_id,
            "customerId": customer_id,
            "customerName": customer_name,
            "customerShopName": data.get("customerShopName", ""),
            "amount": amount,
            "paymentDate": payment_date,
            "paymentMode": data.get("paymentMode", "Cash"),
            "reference": data.get("reference", ""),
            "note": data.get("note", ""),
            "previousOutstanding": previous_outstanding,
            "balanceAfter": balance_after,
            "createdAt": now_iso,
        }

        # Insert payment record
        payments_coll = Database.get_collection("payments")
        payments_coll.insert_one(new_payment)
        print(f"[POST /payments] Payment {payment_id} recorded for customer {customer_id}: "
              f"₹{amount}, prev={previous_outstanding}, after={balance_after}")

        # Update customer's outstanding balance
        customers_coll.update_one(
            {"customerId": customer_id},
            {"$set": {"outstandingBalance": balance_after}}
        )
        print(f"[POST /payments] Customer {customer_id} outstanding updated: "
              f"₹{previous_outstanding} → ₹{balance_after}")

        return jsonify({
            "status": "success",
            "message": "Payment recorded successfully",
            "data": PaymentModel.format_document(new_payment),
        }), 201

    except Exception as e:
        print(f"[POST /payments] ERROR: {e}")
        return jsonify({"status": "error", "message": str(e)}), 500


# ── GET /payments ───────────────────────────────────────────────────────────────

@payments_bp.route("/payments", methods=["GET"])
def get_payments():
    """
    Fetch payment records.
    Query params:
        customerId  (optional) — filter by customer
        search      (optional) — search by customerName or reference
    """
    try:
        coll = Database.get_collection("payments")

        query = {}
        customer_id = request.args.get("customerId", "").strip()
        search = request.args.get("search", "").strip()

        if customer_id:
            query["customerId"] = customer_id

        if search:
            query["$or"] = [
                {"customerName": {"$regex": search, "$options": "i"}},
                {"reference": {"$regex": search, "$options": "i"}},
                {"paymentMode": {"$regex": search, "$options": "i"}},
            ]

        docs = list(coll.find(query).sort("createdAt", -1))
        formatted = [PaymentModel.format_document(d) for d in docs]

        print(f"[GET /payments] Returning {len(formatted)} payments "
              f"(customerId={customer_id or 'all'}, search={search or 'none'})")

        return jsonify({
            "status": "success",
            "count": len(formatted),
            "data": formatted,
        }), 200

    except Exception as e:
        print(f"[GET /payments] ERROR: {e}")
        return jsonify({"status": "error", "message": str(e)}), 500


# ── GET /payments/<payment_id> ──────────────────────────────────────────────────

@payments_bp.route("/payments/<payment_id>", methods=["GET"])
def get_payment_by_id(payment_id):
    try:
        coll = Database.get_collection("payments")
        doc = coll.find_one({"paymentId": payment_id})
        if not doc:
            return jsonify({"status": "error", "message": "Payment not found"}), 404
        return jsonify({"status": "success", "data": PaymentModel.format_document(doc)}), 200
    except Exception as e:
        print(f"[GET /payments/{payment_id}] ERROR: {e}")
        return jsonify({"status": "error", "message": str(e)}), 500
