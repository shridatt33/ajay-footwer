from flask import Blueprint, request, jsonify
from datetime import datetime
from database import Database
from models.category_model import CategoryModel

categories_bp = Blueprint("categories", __name__)


def _generate_category_id():
    coll = Database.get_collection("categories")
    max_num = 0
    for doc in coll.find({}, {"categoryId": 1}):
        cid = doc.get("categoryId", "")
        if cid.startswith("CAT-"):
            try:
                num = int(cid.replace("CAT-", ""))
                if num > max_num:
                    max_num = num
            except ValueError:
                pass
    next_num = max_num + 1
    return f"CAT-{next_num:06d}"


@categories_bp.route("/categories", methods=["GET"])
def get_categories():
    try:
        coll = Database.get_collection("categories")
        docs = list(coll.find().sort("createdAt", -1))
        print(f"[GET /categories] Returning {len(docs)} categories")
        formatted = [CategoryModel.format_document(d) for d in docs]
        return jsonify({"status": "success", "count": len(formatted), "data": formatted}), 200
    except Exception as e:
        print(f"[GET /categories] ERROR: {e}")
        return jsonify({"status": "error", "message": str(e)}), 500


@categories_bp.route("/categories", methods=["POST"])
def create_category():
    try:
        data = request.get_json() or {}
        print(f"[POST /categories] Received payload: {data}")

        coll = Database.get_collection("categories")

        category_name = data.get("categoryName", "").strip()
        if not category_name:
            return jsonify({"status": "error", "message": "Category name is required"}), 400

        sizes = data.get("sizes", [])
        if not isinstance(sizes, list) or len(sizes) < 1:
            return jsonify({"status": "error", "message": "At least one size is required"}), 400

        category_id = data.get("categoryId") or _generate_category_id()
        now_iso = datetime.utcnow().isoformat() + "Z"

        new_doc = {
            "categoryId": category_id,
            "categoryName": category_name,
            "sizes": sizes,
            "createdAt": now_iso,
            "updatedAt": now_iso,
        }

        print(f"[POST /categories] Inserting category: {category_id} - {category_name}")
        result = coll.insert_one(new_doc)
        print(f"[POST /categories] Category inserted with _id: {result.inserted_id}")

        formatted = CategoryModel.format_document(new_doc)
        return jsonify({"status": "success", "message": "Category created successfully", "data": formatted}), 201
    except Exception as e:
        print(f"[POST /categories] ERROR: {e}")
        return jsonify({"status": "error", "message": str(e)}), 500


@categories_bp.route("/categories/<category_id>", methods=["PUT"])
def update_category(category_id):
    try:
        data = request.get_json() or {}
        print(f"[PUT /categories/{category_id}] Received payload: {data}")

        coll = Database.get_collection("categories")
        existing = coll.find_one({"categoryId": category_id})
        if not existing:
            return jsonify({"status": "error", "message": "Category not found"}), 404

        update_fields = {}
        if "categoryName" in data:
            category_name = data["categoryName"].strip()
            if category_name:
                update_fields["categoryName"] = category_name
        if "sizes" in data:
            sizes = data["sizes"]
            if isinstance(sizes, list) and len(sizes) >= 1:
                update_fields["sizes"] = sizes
            else:
                return jsonify({"status": "error", "message": "At least one size is required"}), 400

        if update_fields:
            update_fields["updatedAt"] = datetime.utcnow().isoformat() + "Z"
            coll.update_one({"categoryId": category_id}, {"$set": update_fields})
            print(f"[PUT /categories/{category_id}] Updated fields: {list(update_fields.keys())}")

        updated_doc = coll.find_one({"categoryId": category_id})
        return jsonify({
            "status": "success",
            "message": "Category updated successfully",
            "data": CategoryModel.format_document(updated_doc),
        }), 200
    except Exception as e:
        print(f"[PUT /categories/{category_id}] ERROR: {e}")
        return jsonify({"status": "error", "message": str(e)}), 500


@categories_bp.route("/categories/<category_id>", methods=["DELETE"])
def delete_category(category_id):
    try:
        print(f"[DELETE /categories/{category_id}] Checking if category is in use")

        products_coll = Database.get_collection("products")
        product_count = products_coll.count_documents({"categoryId": category_id})
        if product_count > 0:
            print(f"[DELETE /categories/{category_id}] Blocked: used by {product_count} products")
            return jsonify({
                "status": "error",
                "message": f"This category is used by {product_count} products. Please reassign or delete those products first.",
            }), 400

        coll = Database.get_collection("categories")
        result = coll.delete_one({"categoryId": category_id})
        if result.deleted_count == 0:
            return jsonify({"status": "error", "message": "Category not found"}), 404

        print(f"[DELETE /categories/{category_id}] Category deleted successfully")
        return jsonify({"status": "success", "message": "Category deleted successfully"}), 200
    except Exception as e:
        print(f"[DELETE /categories/{category_id}] ERROR: {e}")
        return jsonify({"status": "error", "message": str(e)}), 500
