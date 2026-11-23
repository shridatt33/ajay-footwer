import io
from flask import Blueprint, request, jsonify, send_file
from datetime import datetime

try:
    import barcode
    from barcode.writer import ImageWriter, SVGWriter
    HAVE_BARCODE = True
except ImportError:
    barcode = None
    ImageWriter = None
    SVGWriter = None
    HAVE_BARCODE = False

from database import Database
from models.product_model import ProductModel

products_bp = Blueprint("products", __name__)

def _generate_product_id():
    coll = Database.get_collection("products")
    count = coll.count_documents({})
    # Ensure sequential SWA-000001 format
    max_num = count
    for doc in coll.find({}, {"productId": 1}):
        pid = doc.get("productId", "")
        if pid.startswith("SWA-"):
            try:
                num = int(pid.split("-")[1])
                if num > max_num:
                    max_num = num
            except ValueError:
                pass
    next_num = max_num + 1
    return f"SWA-{next_num:06d}"

@products_bp.route("/products", methods=["GET"])
def get_products():
    try:
        coll = Database.get_collection("products")
        docs = list(coll.find().sort("createdAt", -1))
        formatted = [ProductModel.format_document(d) for d in docs]
        return jsonify({"status": "success", "count": len(formatted), "data": formatted}), 200
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500

@products_bp.route("/products/<product_id>", methods=["GET"])
def get_product_by_id(product_id):
    try:
        coll = Database.get_collection("products")
        doc = coll.find_one({"productId": product_id})
        if not doc:
            return jsonify({"status": "error", "message": "Product not found"}), 404
        return jsonify({"status": "success", "data": ProductModel.format_document(doc)}), 200
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500

@products_bp.route("/products/barcode/<barcode_val>", methods=["GET"])
def get_product_by_barcode(barcode_val):
    try:
        coll = Database.get_collection("products")
        doc = coll.find_one({"$or": [{"barcode": barcode_val}, {"productId": barcode_val}, {"qrData": barcode_val}]})
        if not doc:
            return jsonify({"status": "error", "message": f"Product with barcode '{barcode_val}' not found"}), 404
        return jsonify({"status": "success", "data": ProductModel.format_document(doc)}), 200
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500

@products_bp.route("/products/<product_id>/barcode-image", methods=["GET"])
def get_product_barcode_image(product_id):
    try:
        if not HAVE_BARCODE:
            return jsonify({
                "status": "error",
                "message": "python-barcode is not installed in this environment. Run: pip install python-barcode pillow"
            }), 501

        coll = Database.get_collection("products")
        doc = coll.find_one({"productId": product_id})
        if not doc:
            return jsonify({"status": "error", "message": "Product not found"}), 404
        
        barcode_val = doc.get("barcode") or doc.get("qrData") or doc.get("productId")
        fmt = request.args.get("format", "png").lower()

        if fmt == "svg":
            code128 = barcode.get("code128", barcode_val, writer=SVGWriter())
            buffer = io.BytesIO()
            code128.write(buffer)
            buffer.seek(0)
            return send_file(buffer, mimetype="image/svg+xml", as_attachment=False, download_name=f"{barcode_val}.svg")
        else:
            code128 = barcode.get("code128", barcode_val, writer=ImageWriter())
            buffer = io.BytesIO()
            code128.write(buffer, options={"write_text": True, "text_distance": 4, "font_size": 10})
            buffer.seek(0)
            return send_file(buffer, mimetype="image/png", as_attachment=False, download_name=f"{barcode_val}.png")
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500

@products_bp.route("/products", methods=["POST"])
def create_product():
    try:
        data = request.get_json() or {}
        coll = Database.get_collection("products")

        product_id = data.get("productId") or _generate_product_id()
        product_name = data.get("productName", "").strip()
        selling_price = float(data.get("sellingPrice", data.get("price", 0)))
        size_stock = data.get("sizeStock", {})
        category_id = data.get("categoryId", "").strip()
        category_name = data.get("categoryName", "").strip()
        barcode_val = (data.get("barcode") or data.get("qrData") or product_id).strip()

        if not product_name:
            return jsonify({"status": "error", "message": "Product name is required"}), 400

        # Prevent duplicate barcode
        existing_barcode = coll.find_one({"barcode": barcode_val})
        if existing_barcode:
            return jsonify({
                "status": "error",
                "message": f"Barcode '{barcode_val}' is already in use by product '{existing_barcode.get('productName', '')}' ({existing_barcode.get('productId', '')})"
            }), 400

        now_iso = datetime.utcnow().isoformat() + "Z"
        new_doc = {
            "productId": product_id,
            "productName": product_name,
            "categoryId": category_id,
            "categoryName": category_name,
            "sellingPrice": selling_price,
            "sizeStock": size_stock,
            "barcode": barcode_val,
            "qrData": barcode_val,
            "createdAt": now_iso
        }

        coll.insert_one(new_doc)
        formatted = ProductModel.format_document(new_doc)
        return jsonify({"status": "success", "message": "Product created successfully", "data": formatted}), 201
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500

@products_bp.route("/products/<product_id>", methods=["PUT"])
def update_product(product_id):
    try:
        data = request.get_json() or {}
        coll = Database.get_collection("products")

        existing = coll.find_one({"productId": product_id})
        if not existing:
            return jsonify({"status": "error", "message": "Product not found"}), 404

        update_fields = {}
        if "productName" in data:
            update_fields["productName"] = data["productName"].strip()
        if "sellingPrice" in data:
            update_fields["sellingPrice"] = float(data["sellingPrice"])
        elif "price" in data:
            update_fields["sellingPrice"] = float(data["price"])
        if "sizeStock" in data:
            update_fields["sizeStock"] = data["sizeStock"]
        if "categoryId" in data:
            update_fields["categoryId"] = data["categoryId"].strip()
        if "categoryName" in data:
            update_fields["categoryName"] = data["categoryName"].strip()

        # Handle barcode update if explicitly requested
        if "barcode" in data and data["barcode"]:
            new_barcode = data["barcode"].strip()
            if new_barcode != existing.get("barcode"):
                duplicate = coll.find_one({"barcode": new_barcode, "productId": {"$ne": product_id}})
                if duplicate:
                    return jsonify({
                        "status": "error",
                        "message": f"Barcode '{new_barcode}' is already in use by product '{duplicate.get('productName', '')}' ({duplicate.get('productId', '')})"
                    }), 400
                update_fields["barcode"] = new_barcode
                update_fields["qrData"] = new_barcode

        if update_fields:
            coll.update_one({"productId": product_id}, {"$set": update_fields})

        updated_doc = coll.find_one({"productId": product_id})
        return jsonify({"status": "success", "message": "Product updated successfully", "data": ProductModel.format_document(updated_doc)}), 200
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500

@products_bp.route("/products/<product_id>", methods=["DELETE"])
def delete_product(product_id):
    try:
        coll = Database.get_collection("products")
        result = coll.delete_one({"productId": product_id})
        if result.deleted_count == 0:
            return jsonify({"status": "error", "message": "Product not found"}), 404
        return jsonify({"status": "success", "message": "Product deleted successfully"}), 200
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500
