# app/deps.py

from typing import Union, Any
from datetime import datetime
from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from jose import jwt, JWTError
from pydantic import ValidationError

# 👇 引用你的 User 模型
from app.models.user import User
# 👇 引用你的配置 (假设你的密钥在这个文件里)
from app.config import settings 

# 这是定义 Token 从哪里来 (通常是 Authorization: Bearer <token>)
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/auth/login")

# 👮‍♂️ 这就是我们要找的保安函数！
async def get_current_user(token: str = Depends(oauth2_scheme)) -> User:
    try:
        # 1. 解密 Token
        payload = jwt.decode(
            token, 
            settings.JWT_SECRET_KEY, 
            algorithms=[settings.ALGORITHM]
        )
        token_data = payload
        
        # 2. 拿到邮箱 (sub 通常存的是 email 或 id)
        user_email = token_data.get("sub")
        if user_email is None:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Could not validate credentials",
                headers={"WWW-Authenticate": "Bearer"},
            )
            
    except (JWTError, ValidationError):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Could not validate credentials",
            headers={"WWW-Authenticate": "Bearer"},
        )
        
    # 3. 去数据库查有没有这个人
    user = await User.find_one(User.email == user_email)
    
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found",
        )
        
    return user