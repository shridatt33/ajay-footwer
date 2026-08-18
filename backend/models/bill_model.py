from datetime import datetime


class BillModel:
    @staticmethod
    def format_document(doc):
        if not doc:
            return None
        return {
            "invoiceNo": doc.get("invoiceNo", ""),
            "customerId": doc.get("customerId", ""),
            "customerName": doc.get("customerName", ""),
            "customerShopName": doc.get("customerShopName", ""),
            "customerMobile": doc.get("customerMobile", ""),
            "products": doc.get("products", []),
            "grandTotal": float(doc.get("grandTotal", 0.0)),
            "subtotal": float(doc.get("subtotal", doc.get("grandTotal", 0.0))),
            "discount": float(doc.get("discount", 0.0)),
            "tax": float(doc.get("tax", 0.0)),
            "status": doc.get("status", "Paid"),
            "businessProfile": doc.get("businessProfile", {}),
            "createdAt": doc.get("createdAt", datetime.utcnow().isoformat() + "Z"),
        }
