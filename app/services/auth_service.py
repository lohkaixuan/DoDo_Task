from fastapi import HTTPException, status
from pydantic import EmailStr
from datetime import datetime
from ..models.user import User
from ..utils.security import hash_password, verify_password, make_access_token

async def register(email: EmailStr, password: str, display_name: str | None):
    if await User.find_one(User.email == email):
        raise HTTPException(status_code=400, detail="Email already registered")
    user = User(email=email, hashed_password=hash_password(password), display_name=display_name)
    return await user.insert()

async def login(email: EmailStr, password: str) -> str:
    user = await User.find_one(User.email == email)
    if not user or not verify_password(password, user.hashed_password):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid credentials")
    user.last_login = datetime.utcnow()
    await user.save()
    return make_access_token(str(user.id))
