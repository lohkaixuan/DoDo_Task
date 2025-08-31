from datetime import datetime, timedelta
from jose import jwt
from passlib.context import CryptContext
from ..config import settings

pwd_ctx = CryptContext(schemes=["bcrypt"], deprecated="auto")

def hash_password(raw: str) -> str:
    return pwd_ctx.hash(raw)

def verify_password(raw: str, hashed: str) -> bool:
    return pwd_ctx.verify(raw, hashed)

def make_access_token(sub: str) -> str:
    payload = {
        "sub": sub,
        "exp": datetime.utcnow() + timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES),
    }
    return jwt.encode(payload, settings.JWT_SECRET, algorithm=settings.JWT_ALG)
