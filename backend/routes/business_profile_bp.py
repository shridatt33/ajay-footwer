from flask import Blueprint, request, jsonify
from datetime import datetime, timezone
from database import Database

business_profile_bp = Blueprint("business_profile", __name__)

_PROFILE_COLLECTION = "business_profile"
# Singleton document identifier
_PROFILE_FILTER = {"profileType": "main"}


def _format_profile(doc):
    if not doc:
        return {}
    return {
        "shopName": doc.get("shopName", ""),
        "ownerName": doc.get("ownerName", ""),
        "mobileNumber": doc.get("mobileNumber", ""),
        "email": doc.get("email", ""),
        "gstNumber": doc.get("gstNumber", ""),
        "shopAddress": doc.get("shopAddress", ""),
        "businessHours": doc.get("businessHours", ""),
        "updatedAt": doc.get("updatedAt", ""),
    }


@business_profile_bp.route("/business-profile", methods=["GET"])
def get_business_profile():
    try:
        coll = Database.get_collection(_PROFILE_COLLECTION)
        doc = coll.find_one(_PROFILE_FILTER)
        print(f"[GET /business-profile] Found: {bool(doc)}")
        return jsonify({
            "status": "success",
            "data": _format_profile(doc) if doc else {},
        }), 200
    except Exception as e:
        print(f"[GET /business-profile] ERROR: {e}")
        return jsonify({"status": "error", "message": str(e)}), 500


@business_profile_bp.route("/business-profile", methods=["PUT"])
def update_business_profile():
    try:
        data = request.get_json() or {}
        print(f"[PUT /business-profile] Payload: {data}")

        coll = Database.get_collection(_PROFILE_COLLECTION)

        now_iso = datetime.now(timezone.utc).isoformat()
        update_doc = {
            "profileType": "main",
            "shopName": data.get("shopName", "").strip(),
            "ownerName": data.get("ownerName", "").strip(),
            "mobileNumber": data.get("mobileNumber", "").strip(),
            "email": data.get("email", "").strip(),
            "gstNumber": data.get("gstNumber", "").strip(),
            "shopAddress": data.get("shopAddress", "").strip(),
            "businessHours": data.get("businessHours", "").strip(),
            "updatedAt": now_iso,
        }

        # upsert=True: creates the document if it doesn't exist yet
        coll.update_one(
            _PROFILE_FILTER,
            {"$set": update_doc},
            upsert=True,
        )
        print(f"[PUT /business-profile] Saved successfully")

        saved = coll.find_one(_PROFILE_FILTER)
        return jsonify({
            "status": "success",
            "message": "Business profile updated successfully",
            "data": _format_profile(saved),
        }), 200
    except Exception as e:
        print(f"[PUT /business-profile] ERROR: {e}")
        return jsonify({"status": "error", "message": str(e)}), 500
