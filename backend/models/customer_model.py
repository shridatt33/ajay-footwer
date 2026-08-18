from datetime import datetime

class CustomerModel:
    @staticmethod
    def format_document(doc, purchase_history=None):
        if not doc:
            return None
        return {
            "customerId": doc.get("customerId", doc.get("id", "")),
            "customerName": doc.get("customerName", doc.get("name", "")),
            "shopName": doc.get("shopName", ""),
            "mobile": doc.get("mobile", ""),
            "address": doc.get("address", ""),
            "email": doc.get("email", ""),
            "gstNumber": doc.get("gstNumber", ""),
            "outstandingBalance": float(doc.get("outstandingBalance", 0.0)),
            "totalBills": int(doc.get("totalBills", 0)),
            "purchaseHistory": purchase_history or doc.get("purchaseHistory", []),
            "createdAt": doc.get("createdAt", datetime.utcnow().isoformat() + "Z")
        }
