from beanie import Document, Indexed
from pydantic import EmailStr, Field
from datetime import datetime

class User(Document):
    email: Indexed(EmailStr, unique=True)
    password_hash: str
    display_name: str | None = None
    created_at: datetime = Field(default_factory=datetime.utcnow)
    last_login: datetime | None = None
    preferences: dict | None = None

    # ✅ keep this
    coins: int = Field(default=0)

    class Settings:
        name = "users"