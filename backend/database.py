import certifi
from pymongo import MongoClient
from config import Config

class Database:
    client = None
    db = None

    @classmethod
    def initialize(cls):
        if cls.client is None:
            connected = False
            # Attempt 1: standard TLS with updated certifi CA bundle
            for kwargs in [
                dict(tlsCAFile=certifi.where()),
                dict(tlsInsecure=True),          # Attempt 2: skip cert verification
                dict(tls=False),                  # Attempt 3: no TLS (only works if Atlas allows)
            ]:
                try:
                    client = MongoClient(
                        Config.MONGO_URI,
                        serverSelectionTimeoutMS=12000,
                        connectTimeoutMS=12000,
                        socketTimeoutMS=12000,
                        **kwargs,
                    )
                    client.admin.command('ping')
                    cls.client = client
                    connected = True
                    print(f"[DB] Connected to MongoDB Atlas: {Config.DB_NAME} (opts={list(kwargs.keys())})")
                    break
                except Exception as e:
                    print(f"[DB] Connection attempt failed ({list(kwargs.keys())}): {e}")

            if not connected:
                raise RuntimeError(
                    "Cannot connect to MongoDB Atlas. "
                    "Check that your IP is whitelisted in Atlas Network Access "
                    "and that port 27017 is not blocked by your firewall."
                )

            cls.db = cls.client[Config.DB_NAME]
            cls._create_indexes()
        return cls.db

    @classmethod
    def _create_indexes(cls):
        try:
            cls.db.products.create_index("productId", unique=True)
            cls.db.products.create_index("barcode", unique=True, sparse=True)
            cls.db.customers.create_index("customerId", unique=True)
            cls.db.bills.create_index("invoiceNo", unique=True)
            cls.db.users.create_index("email", unique=True, sparse=True)
            cls.db.categories.create_index("categoryId", unique=True)
        except Exception as e:
            print(f"[DB] Index creation notice: {e}")

    @classmethod
    def get_collection(cls, name):
        if cls.db is None:
            cls.initialize()
        return cls.db[name]
