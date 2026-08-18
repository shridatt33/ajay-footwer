import os
from dotenv import load_dotenv

load_dotenv()

class Config:
    MONGO_URI = os.getenv("MONGO_URI", "mongodb+srv://kshridatt_db_user:Dattu123@cluster0.whstpkp.mongodb.net/?appName=Cluster0")
    DB_NAME = "ajayfw"
    PORT = int(os.getenv("PORT", 5000))
    DEBUG = True
