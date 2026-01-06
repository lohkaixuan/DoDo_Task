# ==================================================
# Program Name   : users.py
# Purpose        : User profile endpoints (fetch current user, update profile, preferences) and user utilities
# Developer      : Miss. Yap Shuet Khey
# Student ID     : TP074066
# Course         : Bachelor of Software Engineering (Hons)
# Created Date   : 22 August 2025
# Last Modified  : 12 December 2025
# ==================================================

from fastapi import APIRouter, Depends
from bson import ObjectId
from app.db import get_db
from app.schemas.response import Envelope
from app.utils.response_utils import ok
from app.services.auth_service import require_user_id

router = APIRouter(prefix="/users", tags=["users"])

def _to_oid(s: str):
    try:
        return ObjectId(s)
    except Exception:
        return None

@router.get("/me", response_model=Envelope[dict])
async def get_me(
    db=Depends(get_db),
    user_id: str = Depends(require_user_id),
):
    oid = _to_oid(user_id)

    # ✅ allow either ObjectId or string id (兼容两种存法)
    q = {"_id": oid} if oid else {"_id": user_id}

    user = await db.users.find_one(q, {"password_hash": 0})
    if not user:
        return ok({}, message="User not found")

    user["_id"] = str(user["_id"])
    return ok({
        "user_id": user["_id"],
        "email": user.get("email"),
        "display_name": user.get("display_name"),
        "coins": user.get("coins", 0),
    }, message="User profile")
