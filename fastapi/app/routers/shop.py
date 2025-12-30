# app/routers/shop.py
from __future__ import annotations
from datetime import datetime
from typing import Dict, Any, Literal

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from bson import ObjectId

from app.db import get_db
from app.utils.response_utils import ok, created
from app.schemas.response import Envelope
from app.services.auth_service import require_user_id

router = APIRouter(prefix="/shop", tags=["shop"])

ItemType = Literal["food", "decor"]

# ----------------------------
# Inputs (TOKEN version: no user_id in body)
# ----------------------------
class PurchaseIn(BaseModel):
    item_id: str = Field(..., min_length=1)
    item_type: ItemType
    price: int = Field(..., ge=0)
    name: str = Field(..., min_length=1, max_length=60)

class ItemOnlyIn(BaseModel):
    item_id: str = Field(..., min_length=1)

# ----------------------------
# Inventory helpers
# ----------------------------
async def _ensure_inventory(db, user_id: str):
    inv = await db.user_inventory.find_one({"user_id": user_id})
    if inv:
        return inv
    doc = {
        "user_id": user_id,
        "foods": {},
        "decors": {},
        "active_decor": None,
        "updated_at": datetime.utcnow(),
    }
    await db.user_inventory.insert_one(doc)
    return doc

def _to_json(doc: dict) -> dict:
    doc = dict(doc)
    if "_id" in doc:
        doc["_id"] = str(doc["_id"])
    if "updated_at" in doc and hasattr(doc["updated_at"], "isoformat"):
        doc["updated_at"] = doc["updated_at"].isoformat()
    return doc

async def _get_inventory_payload(db, user_id: str) -> dict:
    inv = await _ensure_inventory(db, user_id)
    return {
        "foods": inv.get("foods", {}) or {},
        "decors": inv.get("decors", {}) or {},
        "active_decor": inv.get("active_decor"),
    }

# ----------------------------
# Read inventory (token)
# ----------------------------
@router.get("/inventory", response_model=Envelope[Dict[str, Any]])
async def get_inventory_token(
    db=Depends(get_db),
    user_id: str = Depends(require_user_id),
):
    inv = await _get_inventory_payload(db, user_id)
    return ok({"inventory": inv}, message="Inventory retrieved")

# ----------------------------
# Purchase (token)
# ----------------------------
@router.post("/purchase", response_model=Envelope[Dict[str, Any]])
async def purchase(
    body: PurchaseIn,
    db=Depends(get_db),
    user_id: str = Depends(require_user_id),
):
    await _ensure_inventory(db, user_id)

    # users._id is ObjectId
    try:
        oid = ObjectId(user_id)
    except Exception:
        raise HTTPException(422, "Invalid user id in token (must be ObjectId string)")

    user = await db.users.find_one({"_id": oid})
    if not user:
        raise HTTPException(404, "User not found")

    coins = int(user.get("coins", 0))
    if coins < body.price:
        raise HTTPException(400, "Not enough coins")

    new_coins = coins - body.price
    await db.users.update_one({"_id": oid}, {"$set": {"coins": new_coins}})

    # add to inventory
    if body.item_type == "food":
        await db.user_inventory.update_one(
            {"user_id": user_id},
            {"$inc": {f"foods.{body.item_id}": 1}, "$set": {"updated_at": datetime.utcnow()}},
        )
    else:
        await db.user_inventory.update_one(
            {"user_id": user_id},
            {"$set": {f"decors.{body.item_id}": True, "updated_at": datetime.utcnow()}},
        )

    inv = await _get_inventory_payload(db, user_id)
    return ok({
        "coins": new_coins,
        "inventory": inv,
        "item_id": body.item_id,
        "type": body.item_type,
    }, message="Purchased")

# ----------------------------
# Use food (token)
# ----------------------------
@router.post("/use-food", response_model=Envelope[Dict[str, Any]])
async def use_food(
    body: ItemOnlyIn,
    db=Depends(get_db),
    user_id: str = Depends(require_user_id),
):
    inv_doc = await _ensure_inventory(db, user_id)
    qty = int((inv_doc.get("foods") or {}).get(body.item_id, 0))
    if qty <= 0:
        raise HTTPException(400, "You don't own this food")

    await db.user_inventory.update_one(
        {"user_id": user_id},
        {"$inc": {f"foods.{body.item_id}": -1}, "$set": {"updated_at": datetime.utcnow()}},
    )

    inv = await _get_inventory_payload(db, user_id)
    return ok({"inventory": inv, "used": True, "item_id": body.item_id}, message="Food used")

# ----------------------------
# Equip decor (token)
# ----------------------------
@router.post("/equip-decor", response_model=Envelope[Dict[str, Any]])
async def equip_decor(
    body: ItemOnlyIn,
    db=Depends(get_db),
    user_id: str = Depends(require_user_id),
):
    inv_doc = await _ensure_inventory(db, user_id)
    owned = bool((inv_doc.get("decors") or {}).get(body.item_id, False))
    if not owned:
        raise HTTPException(400, "You don't own this decor")

    await db.user_inventory.update_one(
        {"user_id": user_id},
        {"$set": {"active_decor": body.item_id, "updated_at": datetime.utcnow()}},
    )

    inv = await _get_inventory_payload(db, user_id)
    return ok({"inventory": inv, "equipped": True, "active_decor": body.item_id}, message="Decor equipped")
