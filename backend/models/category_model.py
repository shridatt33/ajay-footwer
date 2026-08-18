from datetime import datetime


class CategoryModel:
    @staticmethod
    def format_document(doc):
        if not doc:
            return None
        return {
            "categoryId": doc.get("categoryId", ""),
            "categoryName": doc.get("categoryName", ""),
            "sizes": doc.get("sizes", []),
            "createdAt": doc.get("createdAt", datetime.utcnow().isoformat() + "Z"),
            "updatedAt": doc.get("updatedAt", datetime.utcnow().isoformat() + "Z"),
        }
