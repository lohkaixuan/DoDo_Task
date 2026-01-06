# ==================================================
# Program Name   : db.py
# Purpose        : Initialize and manage MongoDB database connection,
#                  including Beanie ODM setup and connection health check.
# Developer      : Miss. Yap Shuet Khey
# Student ID     : TP074066
# Course         : Bachelor of Software Engineering (Hons)
# Created Date   : 20 August 2025
# Last Modified  : 12 December 2025
# ==================================================

import os
from dotenv import load_dotenv
from motor.motor_asyncio import AsyncIOMotorClient
from pymongo.errors import ServerSelectionTimeoutError
from beanie import init_beanie
import certifi

from app.models.user import User
from app.models.models import Task

load_dotenv()

MONGO_URI = os.getenv("MONGO_URI")
MONGO_DB  = os.getenv("MONGO_DB", "dodotask")

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

    # 2. Ping 测试
    try:
        await db.command({"ping": 1})
        print("✅ MongoDB Connected!")
    except ServerSelectionTimeoutError as e:
        raise RuntimeError(f"❌ Cannot connect to Mongo: {e}") from e

    # 3. 初始化 Beanie (只写一次！)
    await init_beanie(
        database=db, 
        document_models=[User, Task]
    )
    return db

def get_db():
    if _client is None:
        raise RuntimeError("DB not initialized.")
    return _client[MONGO_DB]
