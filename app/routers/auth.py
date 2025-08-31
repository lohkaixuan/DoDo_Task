from fastapi import APIRouter, Depends
from pydantic import BaseModel, EmailStr
from fastapi.security import OAuth2PasswordRequestForm
from ..services.auth_service import register, login

router = APIRouter(prefix="/auth", tags=["auth"])

class RegisterIn(BaseModel):
    email: EmailStr
    password: str
    display_name: str | None = None

@router.post("/register")
async def register_route(payload: RegisterIn):
    u = await register(payload.email, payload.password, payload.display_name)
    return {"id": str(u.id), "email": u.email}

@router.post("/login")
async def login_route(form: OAuth2PasswordRequestForm = Depends()):
    token = await login(form.username, form.password)
    return {"access_token": token, "token_type": "bearer"}
