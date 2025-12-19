# app/routers/balance.py
from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel
from app.models.user import User
from app.deps import get_current_user 

router = APIRouter()

class SpendRequest(BaseModel):
    amount: int
    item_name: str

#少一個放進去database的

# 💰 1. 查余额
@router.get("/balance", tags=["Gamification"])
async def get_balance(user: User = Depends(get_current_user)):
    print("🧾 BALANCE CHECK:", user.email, user.coins)
    return {
        "email": user.email,
        "coins": int(user.coins or 0),
    }

#  🤑 2. 赚金币
class EarnRequest(BaseModel):
    amount: int
    reason: str | None = None

@router.post("/balance/earn", tags=["Gamification"])
async def earn_coins(req: EarnRequest, user: User = Depends(get_current_user)):
    user.coins = int(user.coins or 0) + int(req.amount)
    await user.save()
    return {"coins": int(user.coins or 0), "earned": int(req.amount)}

# 💸 2. 花钱
@router.post("/balance/spend", tags=["Gamification"])
async def spend_coins(
    request: SpendRequest, 
    user: User = Depends(get_current_user) # 👈 直接拿到 User
):
    # 🛑 检查钱够不够
    if user.coins < request.amount:
        raise HTTPException(status_code=400, detail="Not enough coins! Your pet is hungry🥺")

    # ✅ 扣钱
    user.coins -= request.amount
    await user.save()

    print(f"User {user.email} spent {request.amount} coins on {request.item_name}")

    return {
        "message": f"Successfully bought {request.item_name}",
        "coins": user.coins
    }