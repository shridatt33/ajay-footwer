from flask import Blueprint, request, jsonify
from datetime import datetime
from database import Database
from models.customer_model import CustomerModel

customers_bp = Blueprint("customers", __name__)


def _generate_customer_id():
    coll = Database.get_collection("customers")
    count = coll.count_documents({})
    max_num = count
    for doc in coll.find({}, {"customerId": 1}):
        cid = doc.get("customerId", "")
        if cid.startswith("CUS-") or cid.startswith("CUST-"):
            try:
                num = int(cid.replace("CUS-", "").replace("CUST-", ""))
                if num > max_num:
                    max_num = num
            except ValueError:
                pass
    next_num = max_num + 1
    return f"CUS-{next_num:06d}"


def _get_customer_purchase_history(customer_id):
    bills_coll = Database.get_collection("bills")
    docs = list(bills_coll.find({"customerId": customer_id}).sort("createdAt", -1))
    history = []
    for d in docs:
        products_list = d.get("products", [])
        items_summary = ", ".join(
            [f"{p.get('productName', 'Product')} (x{p.get('quantity', 1)})" for p in products_list]
        )
        history.append({
            "invoiceNumber": d.get("invoiceNo", ""),
            "date": d.get("createdAt", "")[:10],
            "amount": float(d.get("grandTotal", 0.0)),
            "status": d.get("status", "Paid"),
            "itemsSummary": items_summary or "Footwear order",
        })
    return history


@customers_bp.route("/customers", methods=["GET"])
def get_customers():
    try:
        coll = Database.get_collection("customers")
        docs = list(coll.find().sort("createdAt", -1))
        print(f"[GET /customers] Returning {len(docs)} customers from MongoDB ajayfw.customers")
        formatted = []
        for d in docs:
            cid = d.get("customerId", d.get("id", ""))
            history = _get_customer_purchase_history(cid)
            formatted.append(CustomerModel.format_document(d, purchase_history=history))
        return jsonify({"status": "success", "count": len(formatted), "data": formatted}), 200
    except Exception as e:
        print(f"[GET /customers] ERROR: {e}")
        return jsonify({"status": "error", "message": str(e)}), 500


@customers_bp.route("/customers/<customer_id>", methods=["GET"])
def get_customer_by_id(customer_id):
    try:
        coll = Database.get_collection("customers")
        doc = coll.find_one({"customerId": customer_id})
        if not doc:
            return jsonify({"status": "error", "message": "Customer not found"}), 404
        history = _get_customer_purchase_history(customer_id)
        return jsonify(
            {"status": "success", "data": CustomerModel.format_document(doc, purchase_history=history)}
        ), 200
    except Exception as e:
        print(f"[GET /customers/{customer_id}] ERROR: {e}")
        return jsonify({"status": "error", "message": str(e)}), 500


@customers_bp.route("/customers", methods=["POST"])
def create_customer():
    try:
        data = request.get_json() or {}
        print(f"[POST /customers] Received payload: {data}")

        coll = Database.get_collection("customers")

        customer_id = data.get("customerId") or _generate_customer_id()
        customer_name = data.get("customerName", data.get("name", "")).strip()
        shop_name = data.get("shopName", "").strip()
        mobile = data.get("mobile", "").strip()

        if not customer_name:
            return jsonify({"status": "error", "message": "Customer name is required"}), 400

        now_iso = datetime.utcnow().isoformat() + "Z"
        new_doc = {
            "customerId": customer_id,
            "customerName": customer_name,
            "shopName": shop_name,
            "mobile": mobile,
            "address": data.get("address", "").strip(),
            "email": data.get("email", "").strip(),
            "gstNumber": data.get("gstNumber", "").strip(),
            "outstandingBalance": float(data.get("outstandingBalance", 0.0)),
            "totalBills": int(data.get("totalBills", 0)),
            "createdAt": now_iso,
        }

        print(f"[POST /customers] Inserting customer into ajayfw.customers: {customer_id} - {customer_name}")
        result = coll.insert_one(new_doc)
        print(f"[POST /customers] Customer inserted with _id: {result.inserted_id}")

        formatted = CustomerModel.format_document(new_doc, purchase_history=[])
        return jsonify({"status": "success", "message": "Customer created successfully", "data": formatted}), 201
    except Exception as e:
        print(f"[POST /customers] ERROR: {e}")
        return jsonify({"status": "error", "message": str(e)}), 500


@customers_bp.route("/customers/<customer_id>", methods=["PUT"])
def update_customer(customer_id):
    try:
        data = request.get_json() or {}
        print(f"[PUT /customers/{customer_id}] Received payload: {data}")

        coll = Database.get_collection("customers")
        existing = coll.find_one({"customerId": customer_id})
        if not existing:
            return jsonify({"status": "error", "message": "Customer not found"}), 404

        update_fields = {}
        field_map = {
            "customerName": ["customerName", "name"],
            "shopName": ["shopName"],
            "mobile": ["mobile"],
            "address": ["address"],
            "email": ["email"],
            "gstNumber": ["gstNumber"],
        }
        for db_field, payload_keys in field_map.items():
            for key in payload_keys:
                if key in data:
                    update_fields[db_field] = str(data[key]).strip()
                    break

        if "outstandingBalance" in data:
            update_fields["outstandingBalance"] = float(data["outstandingBalance"])
        if "totalBills" in data:
            update_fields["totalBills"] = int(data["totalBills"])

        if update_fields:
            coll.update_one({"customerId": customer_id}, {"$set": update_fields})
            print(f"[PUT /customers/{customer_id}] Updated fields: {list(update_fields.keys())}")

        updated_doc = coll.find_one({"customerId": customer_id})
        history = _get_customer_purchase_history(customer_id)
        return jsonify(
            {
                "status": "success",
                "message": "Customer updated successfully",
                "data": CustomerModel.format_document(updated_doc, purchase_history=history),
            }
        ), 200
    except Exception as e:
        print(f"[PUT /customers/{customer_id}] ERROR: {e}")
        return jsonify({"status": "error", "message": str(e)}), 500


@customers_bp.route("/customers/<customer_id>", methods=["DELETE"])
def delete_customer(customer_id):
    try:
        print(f"[DELETE /customers/{customer_id}] Deleting customer from MongoDB")
        coll = Database.get_collection("customers")
        result = coll.delete_one({"customerId": customer_id})
        if result.deleted_count == 0:
            return jsonify({"status": "error", "message": "Customer not found"}), 404
        print(f"[DELETE /customers/{customer_id}] Customer deleted successfully")
        return jsonify({"status": "success", "message": "Customer deleted successfully"}), 200
    except Exception as e:
        print(f"[DELETE /customers/{customer_id}] ERROR: {e}")
        return jsonify({"status": "error", "message": str(e)}), 500
