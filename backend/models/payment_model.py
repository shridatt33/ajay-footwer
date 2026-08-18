from datetime import datetime


class PaymentModel:
    @staticmethod
    def format_document(doc):
        if not doc:
            return None
        return {
            "paymentId": doc.get("paymentId", str(doc.get("_id", ""))),
            "customerId": doc.get("customerId", ""),
            "customerName": doc.get("customerName", ""),
            "customerShopName": doc.get("customerShopName", ""),
            "amount": float(doc.get("amount", 0.0)),
            "paymentDate": doc.get("paymentDate", ""),
            "paymentMode": doc.get("paymentMode", "Cash"),
            "reference": doc.get("reference", ""),
            "note": doc.get("note", ""),
            "previousOutstanding": float(doc.get("previousOutstanding", 0.0)),
            "balanceAfter": float(doc.get("balanceAfter", 0.0)),
            "createdAt": doc.get("createdAt", datetime.utcnow().isoformat() + "Z"),
        }
