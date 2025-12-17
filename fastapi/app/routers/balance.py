# app/routers/balance.py
from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel

# 👇👇👇 关键一步：直接从隔壁房间把 User 模型抓过来用！
from app.models.models import User 
# 假设你的获取当前用户逻辑在这里
from app.auth import get_current_user 

router = APIRouter()

# 定义一个简单的请求体，用来接收花钱的参数
class SpendRequest(BaseModel):
    amount: int
    item_name: str

# 💰 1. 查余额 (Check Balance)
@router.get("/balance", tags=["Gamification"])
async def get_balance(current_user: dict = Depends(get_current_user)):
    # 这里的 current_user 是鉴权通过后解密出来的 token 数据
    user = await User.find_one(User.email == current_user["email"])
    
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    return {
        "email": user.email,
        "coins": user.coins,
        "username": user.username
    }

# 💸 2. 花钱 (Spend Coins)
@router.post("/balance/spend", tags=["Gamification"])
async def spend_coins(
    request: SpendRequest, 
    current_user: dict = Depends(get_current_user)
):
    user = await User.find_one(User.email == current_user["email"])
    
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

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