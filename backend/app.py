from flask import Flask, jsonify
from flask_cors import CORS
from datetime import datetime

from config import Config
from database import Database
from routes.products_bp import products_bp
from routes.customers_bp import customers_bp
from routes.bills_bp import bills_bp
from routes.dashboard_bp import dashboard_bp
from routes.business_profile_bp import business_profile_bp
from routes.categories_bp import categories_bp
from routes.payments_bp import payments_bp

app = Flask(__name__)
CORS(app)

# Initialize Database Connection
db = Database.initialize()

# Register Blueprints under /api prefix
app.register_blueprint(products_bp, url_prefix="/api")
app.register_blueprint(customers_bp, url_prefix="/api")
app.register_blueprint(bills_bp, url_prefix="/api")
app.register_blueprint(dashboard_bp, url_prefix="/api")
app.register_blueprint(business_profile_bp, url_prefix="/api")
app.register_blueprint(categories_bp, url_prefix="/api")
app.register_blueprint(payments_bp, url_prefix="/api")

# Also register without /api prefix for compatibility
app.register_blueprint(products_bp, url_prefix="", name="products_root")
app.register_blueprint(customers_bp, url_prefix="", name="customers_root")
app.register_blueprint(bills_bp, url_prefix="", name="bills_root")
app.register_blueprint(dashboard_bp, url_prefix="", name="dashboard_root")
app.register_blueprint(business_profile_bp, url_prefix="", name="business_profile_root")
app.register_blueprint(categories_bp, url_prefix="", name="categories_root")
app.register_blueprint(payments_bp, url_prefix="", name="payments_root")



@app.route("/")
def home():
    return jsonify({
        "status": "success",
        "message": "Swamidatta Agencies Billing ERP API Powered by Flask & MongoDB Atlas",
        "endpoints": {
            "products": "/api/products",
            "customers": "/api/customers",
            "bills": "/api/bills",
            "payments": "/api/payments"
        }
    })

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=Config.PORT, debug=Config.DEBUG)