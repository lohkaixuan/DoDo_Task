# app/routers/balance.py
from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel
from app.models.user import User
from app.deps import get_current_user 

router = APIRouter()

class SpendRequest(BaseModel):
    amount: int
    item_name: str

# 💰 1. 查余额
@router.get("/balance", tags=["Gamification"])
# 👇 注意这里类型改成 User，直接拿到用户对象
async def get_balance(user: User = Depends(get_current_user)):
    return {
        "email": user.email,
        "coins": user.coins,
        # "username": user.display_name # 注意：你的 User 模型里好像是 display_name 不是 username
    }

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
        "remaining_coins": user.coins
    }