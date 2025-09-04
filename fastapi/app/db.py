# app/db.py
import os
from dotenv import load_dotenv
from motor.motor_asyncio import AsyncIOMotorClient
from pymongo.errors import ServerSelectionTimeoutError
from beanie import init_beanie

# 🔹 load .env first
load_dotenv()

# 🔹 envs (supports both names just in case)
MONGO_URI = os.getenv("MONGO_URI") 
MONGO_DB  = os.getenv("MONGO_DB", "dodotask")

# 🔹 import your Beanie Document(s)
#    If your file is app/models/user.py with class User(Document),
#    this path is correct. If it's app/user.py, change to: from .user import User
from .models.user import User

_client: AsyncIOMotorClient | None = None

async def init_db():
    """
    Init Mongo client, verify connection, init Beanie for User,
    and create helpful indexes for CRUD collections.
    """
    global _client
    _client = AsyncIOMotorClient(
        MONGO_URI,
        uuidRepresentation="standard",   # good for UUIDs
        serverSelectionTimeoutMS=5000,   # fast fail if misconfigured
    )
    db = _client[MONGO_DB]

    # ✅ verify Atlas/local is reachable
    try:
        await db.command({"ping": 1})
    except ServerSelectionTimeoutError as e:
        raise RuntimeError(
            f"Cannot connect to Mongo at {MONGO_URI}. "
            f"Check Atlas IP allowlist / credentials (and install dnspython). Original: {e}"
        ) from e

    # ✅ Beanie ODM for documents that need it (only User for now)
    await init_beanie(database=db, document_models=[User])

    # ✅ Indexes for fast queries & constraints
    await db.tasks.create_index([("user_id", 1), ("due_date", 1)])
    await db.tasks.create_index([("user_id", 1), ("status", 1)])
    await db.pets.create_index("user_id", unique=True)
    await db.events.create_index([("user_id", 1), ("ts", 1)])
    await db.mood_logs.create_index([("user_id", 1), ("ts", 1)])
    await db.focus_sessions.create_index([("user_id", 1), ("started_at", 1)])
    await db.usage_stats_daily.create_index([("user_id", 1), ("date", 1)], unique=True)
    await db.stress_risk_scores.create_index([("user_id", 1), ("ts", 1)])
    await db.interventions.create_index([("user_id", 1), ("ts", 1)])

    return db

def get_db():
    """Return Motor database (for CRUD-only usage in routers)."""
    if _client is None:
        raise RuntimeError("DB not initialized — call init_db() at startup.")
    return _client[MONGO_DB]
