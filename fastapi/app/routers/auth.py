# app/routers/auth.py
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, EmailStr
from typing import Optional

from app.schemas.response import Envelope
from fastapi.app.utils.response_utils import ok, created
from app.services.auth_service import (
    register_user,
    login_email_password,
    login_with_token,
)

router = APIRouter(prefix="/auth", tags=["auth"])

# ---------- Schemas ----------
class RegisterIn(BaseModel):
    email: EmailStr
    password: str
    display_name: Optional[str] = None

class RegisterOut(BaseModel):
    id: str
    email: EmailStr
    display_name: Optional[str] = None

class LoginIn(BaseModel):
    # EITHER email+password OR token (rotating single token)
    email: Optional[EmailStr] = None
    password: Optional[str] = None
    token: Optional[str] = None

class TokenOut(BaseModel):
    token: str
    token_type: str = "bearer"
    user: dict  # {id, email, display_name}

# ---------- Routes ----------
@router.post("/register", response_model=Envelope[RegisterOut])
async def register_route(body: RegisterIn):
    u = await register_user(body.email, body.password, body.display_name)
    return created(
        RegisterOut(id=str(u["id"]), email=u["email"], display_name=u.get("display_name")),
        message="Register success",
    )

@router.post("/login", response_model=Envelope[TokenOut])
async def login_route(body: LoginIn):
    if body.token:  # token login -> rotate to a new token
        data = await login_with_token(body.token)
        return ok(data, message="Token refreshed")
    if body.email and body.password:  # email+password -> issue new token
        data = await login_email_password(body.email, body.password)
        return ok(data, message="Login success")
    raise HTTPException(status_code=422, detail="Provide either token or email & password")
