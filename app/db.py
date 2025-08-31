from beanie import init_beanie
from motor.motor_asyncio import AsyncIOMotorClient
from .config import settings
from .models.user import User

client: AsyncIOMotorClient | None = None

async def init_db():
    global client
    client = AsyncIOMotorClient(settings.MONGO_URI)
    db = client[settings.MONGO_DB]
    await init_beanie(database=db, document_models=[User])
