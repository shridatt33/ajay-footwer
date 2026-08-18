from datetime import datetime

class ProductModel:
    @staticmethod
    def format_document(doc):
        if not doc:
            return None
        pid = doc.get("productId") or (str(doc["_id"]) if "_id" in doc else "")
        pname = doc.get("productName") or doc.get("name") or ""
        return {
            "productId": pid,
            "productName": pname,
            "categoryId": doc.get("categoryId", ""),
            "categoryName": doc.get("categoryName", ""),
            "sellingPrice": float(doc.get("sellingPrice", doc.get("price", 0))),
            "sizeStock": doc.get("sizeStock", {}),
            "qrData": doc.get("qrData") or pid,
            "createdAt": doc.get("createdAt") or datetime.utcnow().isoformat() + "Z"
        }
