# app/routers/ai.py
import os
from fastapi import APIRouter
from pydantic import BaseModel
from typing import List, Literal
from httpx import AsyncClient
from app.schemas.response import Envelope
from app.utils.response import ok

router = APIRouter(prefix="/ai", tags=["ai"])

class ChatMessage(BaseModel):
    role: Literal["user", "assistant", "system"]
    content: str

class ChatRequest(BaseModel):
    user_id: str
    messages: List[ChatMessage]

class ChatOut(BaseModel):
    reply: str
    model: str

OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")

@router.post("/chat", response_model=Envelope[ChatOut])
async def chat(req: ChatRequest):
    if not OPENAI_API_KEY:
        last = req.messages[-1].content if req.messages else ""
        return ok(ChatOut(
            reply=f"(stub) You said: {last}\nTry a 25-min focus and a sip of water. 🫶",
            model="stub"
        ))

    url = "https://api.openai.com/v1/chat/completions"
    payload = {"model": "gpt-4o-mini", "messages": [m.model_dump() for m in req.messages], "temperature": 0.7}
    headers = {"Authorization": f"Bearer {OPENAI_API_KEY}"}
    async with AsyncClient(timeout=30) as client:
        r = await client.post(url, json=payload, headers=headers)
        r.raise_for_status()
        data = r.json()
        text = data["choices"][0]["message"]["content"]
        return ok(ChatOut(reply=text, model=payload["model"]))
