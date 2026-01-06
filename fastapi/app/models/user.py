# ==================================================
# Program Name   : user.py
# Purpose        : User-related helpers/services (user identity, mapping, and shared user logic)
# Developer      : Miss. Yap Shuet Khey
# Student ID     : TP074066
# Course         : Bachelor of Software Engineering (Hons)
# Created Date   : 22 August 2025
# Last Modified  : 05 December 2025
# ==================================================

from beanie import Document, Indexed
from pydantic import EmailStr, Field
from datetime import datetime
from typing import Optional, Dict, Any

class User(Document):
    email: Indexed(EmailStr, unique=True)
    hashed_password: Optional[str] = Field(default=None, alias="password_hash")
    display_name: Optional[str] = None
    created_at: datetime = Field(default_factory=datetime.utcnow)
    last_login: Optional[datetime] = None
    preferences: Optional[Dict[str, Any]] = None
    coins: int = Field(default=0)

    class Settings:
        name = "users"
