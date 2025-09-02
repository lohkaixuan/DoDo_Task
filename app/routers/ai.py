# app/routers/ai.py
import os
from fastapi import APIRouter
from pydantic import BaseModel
from typing import List, Literal, Optional
from httpx import AsyncClient

router = APIRouter(prefix="/ai", tags=["ai"])

class ChatMessage(BaseModel):
    role: Literal["user", "assistant", "system"]
    content: str

class ChatRequest(BaseModel):
    user_id: str
    messages: List[ChatMessage]

OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")

@router.post("/chat")
async def chat(req: ChatRequest):
    if not OPENAI_API_KEY:
        # dev stub: echo + tiny suggestion
        last = req.messages[-1].content if req.messages else ""
        return {
            "reply": f"(stub) You said: {last}\nTry a 25-min focus and a sip of water. 🫶",
            "model": "stub"
        }

    # Example: OpenAI responses API (JSON). Replace with your provider if needed.
    url = "https://api.openai.com/v1/chat/completions"
    payload = {
        "model": "gpt-4o-mini",
        "messages": [m.model_dump() for m in req.messages],
        "temperature": 0.7,
    }
    headers = {"Authorization": f"Bearer {OPENAI_API_KEY}"}
    async with AsyncClient(timeout=30) as client:
        r = await client.post(url, json=payload, headers=headers)
        r.raise_for_status()
        data = r.json()
        text = data["choices"][0]["message"]["content"]
        return {"reply": text, "model": payload["model"]}
