# app/db.py
import os
from dotenv import load_dotenv
from motor.motor_asyncio import AsyncIOMotorClient
from pymongo.errors import ServerSelectionTimeoutError
from beanie import init_beanie
import certifi

load_dotenv()

MONGO_URI = os.getenv("MONGO_URI")
MONGO_DB  = os.getenv("MONGO_DB", "dodotask")

from .models.user import User

_client: AsyncIOMotorClient | None = None

async def init_db():
    global _client

    # 👇 如果是 Atlas（mongodb+srv://），启用 TLS + certifi；否则（本地）不加 TLS
    if MONGO_URI and MONGO_URI.startswith("mongodb+srv://"):
        _client = AsyncIOMotorClient(
            MONGO_URI,
            uuidRepresentation="standard",
            serverSelectionTimeoutMS=5000,
            tls=True,
            tlsCAFile=certifi.where(),
        )
    else:
        _client = AsyncIOMotorClient(
            MONGO_URI,
            uuidRepresentation="standard",
            serverSelectionTimeoutMS=5000,
        )

    db = _client[MONGO_DB]

    # ping 一下，确保连接可用
    try:
        await db.command({"ping": 1})
    except ServerSelectionTimeoutError as e:
        raise RuntimeError(
            f"Cannot connect to Mongo at {MONGO_URI}. "
            f"Check local service for mongodb://... or Atlas IP allowlist for mongodb+srv://. Original: {e}"
        ) from e

    # Beanie 文档（目前只有 User）
    await init_beanie(database=db, document_models=[User])

    # 常用索引
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
    if _client is None:
        raise RuntimeError("DB not initialized — call init_db() at startup.")
    return _client[MONGO_DB]
