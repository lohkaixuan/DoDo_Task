# app/deps.py
from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from jose import jwt, JWTError
from bson import ObjectId

from app.config import settings
from app.models.user import User

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/auth/login")

async def get_current_user(token: str = Depends(oauth2_scheme)) -> User:
    try:
        payload = jwt.decode(token, settings.JWT_SECRET, algorithms=[settings.JWT_ALG])
        uid = payload.get("sub")  # ✅ sub = user_id
        if not uid:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid token payload",
                headers={"WWW-Authenticate": "Bearer"},
            )
    except JWTError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid/expired token",
            headers={"WWW-Authenticate": "Bearer"},
        )

    try:
        oid = ObjectId(uid)
    except Exception:
        raise HTTPException(status_code=401, detail="Invalid user id in token")

    # ✅ Beanie: query by id
    user = await User.find_one(User.id == oid)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    return user
