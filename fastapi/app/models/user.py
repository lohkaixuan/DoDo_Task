from beanie import Document, Indexed
from pydantic import EmailStr, Field
from datetime import datetime

class User(Document):
    email: Indexed(EmailStr, unique=True)
    # ✅ accept DB field "password_hash", and don't crash if missing
    hashed_password: str | None = Field(default=None, alias="password_hash")
    display_name: str | None = None
    created_at: datetime = Field(default_factory=datetime.utcnow)
    last_login: datetime | None = None
    preferences: dict | None = None
    print("✅ User model loaded: hashed_password alias password_hash enabled")

    # ✅ keep this
    coins: int = Field(default=0)

    class Settings:
        name = "users"