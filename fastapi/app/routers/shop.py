# app/routers/shop.py
from __future__ import annotations
from datetime import datetime
from typing import Literal, Dict, Any

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from bson import ObjectId

from app.db import get_db
from app.utils.response_utils import ok
from app.schemas.response import Envelope

router = APIRouter(prefix="/shop", tags=["shop"])

ItemType = Literal["food", "decor"]

class PurchaseIn(BaseModel):
    user_id: str = Field(..., min_length=1)   # store ObjectId string from app
    item_id: str = Field(..., min_length=1)
    item_type: ItemType
    price: int = Field(..., ge=0)
    name: str = Field(..., min_length=1, max_length=60)

class UseFoodIn(BaseModel):
    user_id: str
    item_id: str

class EquipDecorIn(BaseModel):
    user_id: str
    item_id: str


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


@router.get("/inventory/{user_id}", response_model=Envelope[Dict[str, Any]])
async def get_inventory(user_id: str, db=Depends(get_db)):
    inv = await _ensure_inventory(db, user_id)
    return ok({
        "user_id": user_id,
        "foods": inv.get("foods", {}),
        "decors": inv.get("decors", {}),
        "active_decor": inv.get("active_decor"),
    })


@router.post("/purchase", response_model=Envelope[Dict[str, Any]])
async def purchase(body: PurchaseIn, db=Depends(get_db)):
    await _ensure_inventory(db, body.user_id)

    # ✅ FIX: find user by _id (ObjectId)
    try:
        oid = ObjectId(body.user_id)
    except Exception:
        raise HTTPException(422, "Invalid user_id (must be ObjectId string)")

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
            {"user_id": body.user_id},
            {"$inc": {f"foods.{body.item_id}": 1}, "$set": {"updated_at": datetime.utcnow()}},
        )
    else:
        await db.user_inventory.update_one(
            {"user_id": body.user_id},
            {"$set": {f"decors.{body.item_id}": True, "updated_at": datetime.utcnow()}},
        )

    return ok({"coins": new_coins, "item_id": body.item_id, "type": body.item_type})


@router.post("/use-food", response_model=Envelope[Dict[str, Any]])
async def use_food(body: UseFoodIn, db=Depends(get_db)):
    inv = await _ensure_inventory(db, body.user_id)
    qty = int(inv.get("foods", {}).get(body.item_id, 0))
    if qty <= 0:
        raise HTTPException(400, "You don't own this food")

    await db.user_inventory.update_one(
        {"user_id": body.user_id},
        {"$inc": {f"foods.{body.item_id}": -1}, "$set": {"updated_at": datetime.utcnow()}},
    )
    return ok({"used": True, "item_id": body.item_id})


@router.post("/equip-decor", response_model=Envelope[Dict[str, Any]])
async def equip_decor(body: EquipDecorIn, db=Depends(get_db)):
    inv = await _ensure_inventory(db, body.user_id)
    owned = bool(inv.get("decors", {}).get(body.item_id, False))
    if not owned:
        raise HTTPException(400, "You don't own this decor")

    await db.user_inventory.update_one(
        {"user_id": body.user_id},
        {"$set": {"active_decor": body.item_id, "updated_at": datetime.utcnow()}},
    )
    return ok({"equipped": True, "active_decor": body.item_id})
