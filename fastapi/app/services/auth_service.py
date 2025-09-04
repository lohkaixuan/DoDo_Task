# app/services/auth_service.py
from datetime import datetime, timedelta, timezone
from typing import Dict, Any, Optional

from jose import jwt, JWTError, ExpiredSignatureError
from passlib.context import CryptContext
from passlib.exc import UnknownHashError
from bson import ObjectId

from app.db import get_db
from app.config import settings

pwd = CryptContext(schemes=["bcrypt"], deprecated="auto")


# ---------- helpers ----------
def _hash(pw: str) -> str:
    return pwd.hash(pw)


def _verify(pw: str, hashed: str) -> bool:
    """
    Safe verify:
    - returns False if hash missing/invalid instead of throwing
    - handles legacy docs gracefully
    """
    if not hashed:
        return False
    try:
        return pwd.verify(pw, hashed)
    except (ValueError, UnknownHashError):
        return False


def _make_token(*, user_id: str, email: str, ver: int) -> str:
    now = datetime.now(timezone.utc)
    exp = now + timedelta(minutes=settings.TOKEN_EXPIRE_MINUTES)
    payload = {
        "sub": user_id,
        "email": email,
        "ver": ver,            # token version for rotation
        "iat": int(now.timestamp()),
        "exp": exp,
        "type": "access",      # single rotating token
    }
    return jwt.encode(payload, settings.JWT_SECRET, algorithm=settings.JWT_ALG)


def _decode(token: str, *, ignore_exp: bool = False) -> Dict[str, Any]:
    try:
        return jwt.decode(
            token,
            settings.JWT_SECRET,
            algorithms=[settings.JWT_ALG],
            options={"verify_exp": not ignore_exp},
        )
    except ExpiredSignatureError as e:
        if ignore_exp:
            # allow reading claims for rotation flow
            return jwt.get_unverified_claims(token)  # type: ignore
        raise e
    except JWTError as e:
        raise ValueError(str(e)) from e


async def _rotate_and_issue(user: Dict[str, Any]) -> Dict[str, Any]:
    """
    Increment token_version, set last_login_at, return {token, user}.
    Only the newest token (highest version) remains valid.
    """
    db = get_db()  # NOTE: no await
    new_ver = int(user.get("token_version") or 0) + 1
    await db.users.update_one(
        {"_id": user["_id"]},
        {"$set": {"token_version": new_ver, "last_login_at": datetime.now(timezone.utc)}},
    )
    token = _make_token(user_id=str(user["_id"]), email=user["email"], ver=new_ver)
    return {
        "token": token,
        "token_type": "bearer",
        "user": {
            "id": str(user["_id"]),
            "email": user["email"],
            "display_name": user.get("display_name") or "",
        },
    }


# ---------- public API ----------
async def register_user(email: str, password: str, display_name: Optional[str]) -> Dict[str, Any]:
    db = get_db()  # NOTE: no await
    if await db.users.find_one({"email": email}):
        from fastapi import HTTPException
        raise HTTPException(status_code=409, detail="Email already registered")

    doc = {
        "email": email,
        "display_name": display_name or "",
        "password_hash": _hash(password),  # canonical field name
        "token_version": 0,
        "created_at": datetime.now(timezone.utc),
    }
    res = await db.users.insert_one(doc)
    return {"id": res.inserted_id, "email": email, "display_name": display_name or ""}


async def login_email_password(email: str, password: str) -> Dict[str, Any]:
    db = get_db()  # NOTE: no await
    user = await db.users.find_one({"email": email})
    # Support both legacy 'hashed_password' and new 'password_hash'
    stored = (user or {}).get("password_hash") or (user or {}).get("hashed_password") or ""

    if not user or not _verify(password, stored):
        from fastapi import HTTPException
        raise HTTPException(status_code=401, detail="Invalid email or password")

    # Migrate legacy docs to 'password_hash' on the fly
    if "hashed_password" in user and "password_hash" not in user:
        await db.users.update_one(
            {"_id": user["_id"]},
            {"$set": {"password_hash": user["hashed_password"]}, "$unset": {"hashed_password": ""}},
        )
        user["password_hash"] = user.pop("hashed_password", None)

    return await _rotate_and_issue(user)


async def login_with_token(token: str) -> Dict[str, Any]:
    # Accept valid or expired token to allow rotation on app open
    try:
        claims = _decode(token, ignore_exp=True)
    except ValueError as e:
        from fastapi import HTTPException
        raise HTTPException(status_code=401, detail=f"Invalid token: {e}")

    uid = claims.get("sub")
    if not uid:
        from fastapi import HTTPException
        raise HTTPException(status_code=401, detail="Invalid token payload")

    db = get_db()  # NOTE: no await
    user = await db.users.find_one({"_id": ObjectId(uid)})
    if not user:
        from fastapi import HTTPException
        raise HTTPException(status_code=404, detail="User not found")

    return await _rotate_and_issue(user)


async def verify_token_and_get_user(token: str) -> Dict[str, Any]:
    """
    Use in protected endpoints.
    Valid only if token_version matches the user's current version.
    """
    try:
        claims = _decode(token)
    except (ExpiredSignatureError, ValueError) as e:
        from fastapi import HTTPException
        raise HTTPException(status_code=401, detail=f"Invalid/expired token: {e}")

    db = get_db()  # NOTE: no await
    user = await db.users.find_one({"_id": ObjectId(claims["sub"])})
    if not user:
        from fastapi import HTTPException
        raise HTTPException(status_code=404, detail="User not found")

    if int(user.get("token_version") or 0) != int(claims.get("ver") or -1):
        from fastapi import HTTPException
        raise HTTPException(status_code=401, detail="Token is no longer valid (rotated)")

    return user
