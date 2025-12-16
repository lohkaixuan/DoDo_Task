# app/routers/pet_ai.py
from __future__ import annotations
import os
from datetime import datetime
from typing import Optional, Literal, Dict, Any

from fastapi import APIRouter, Depends, UploadFile, File, HTTPException
from pydantic import BaseModel, Field

from app.db import get_db
from app.schemas.response import Envelope
# 👇👇👇 之前这里写错了，把 fastapi. 去掉！ 👇👇👇
from app.utils.response_utils import ok, created 
from app.logic.risk_mongo import compute_stress_score
from app.services.pet_service_ai import HuggingFaceClient, InworldClient

router = APIRouter(prefix="/ai/pet", tags=["ai-pet"])

# ... 下面的代码保持不变 ...
# 为了保险，你可以把下面的也复制进去，或者只改上面那行 import

class ChatIn(BaseModel):
    user_id: str
    text: str
    use_inworld: bool = Field(default=True)
    character_id: Optional[str] = Field(default_factory=lambda: os.getenv("INWORLD_CHARACTER_ID"))


class ChatOut(BaseModel):
    reply: str
    provider: Literal["inworld", "huggingface", "groq"]
    sentiment: Dict[str, Any] | None = None
    risk: Dict[str, Any] | None = None
    ts: datetime


@router.post("/chat", response_model=Envelope[ChatOut])
async def chat(body: ChatIn, db=Depends(get_db)):
    hf = HuggingFaceClient()

    # 1) 本地情绪 + 风险
    senti = await hf.analyze_sentiment(body.text)
    risk = await compute_stress_score(db, body.user_id) or {"score": 0, "signals": []}

    # 2) Persona
    persona = (
        "You are 'DoDo', a gentle, playful virtual pet companion. "
        "Speak in short, warm sentences with emojis occasionally. "
        "Use positive reinforcement, tiny-steps coaching, and never shame. "
        f"User mood: {senti['label']} (p={senti['score']:.2f}). "
        f"Stress score: {risk['score']} with signals {risk['signals']}. "
        "If stress >=70: suggest micro-break & reschedule. "
        "If 40-69: suggest 25-min focus + water. "
        "Otherwise: celebrate consistency."
    )
    prompt = f"{persona}\nUser: {body.text}\nPet:"

    # 3) 优先 Inworld，否则 Groq
    reply = ""
    provider: Literal["inworld", "huggingface", "groq"] = "groq"

    if body.use_inworld:
        iw = InworldClient()
        try:
            reply = await iw.chat(
                character_id=body.character_id or "",
                user_id=body.user_id,
                text=body.text,
                context={"mood": senti, "risk": {"score": risk["score"], "signals": risk["signals"]}},
            )
            provider = "inworld"
        except Exception:
            reply = await hf.generate_reply(prompt)
            provider = "groq"
    else:
        reply = await hf.generate_reply(prompt)
        provider = "groq"

    # 4) 日志
    await db.events.insert_one(
        {
            "event_id": os.urandom(8).hex(),
            "user_id": body.user_id,
            "type": "emotion_text",
            "ts": datetime.utcnow(),
            "context": {
                "text": body.text,
                "reply": reply,
                "provider": provider,
                "sentiment": senti,
                "risk": {"score": risk["score"], "signals": risk["signals"]},
            },
        }
    )

    return ok(ChatOut(reply=reply, provider=provider, sentiment=senti, risk=risk, ts=datetime.utcnow()))


class SentimentIn(BaseModel):
    text: str


@router.post("/analyze/sentiment", response_model=Envelope[Dict[str, Any]])
async def analyze_sentiment(body: SentimentIn):
    hf = HuggingFaceClient()
    out = await hf.analyze_sentiment(body.text)
    return ok(out)


@router.post("/analyze/image-caption", response_model=Envelope[Dict[str, Any]])
async def image_caption(file: UploadFile = File(...)):
    if not file.content_type or not file.content_type.startswith("image/"):
        raise HTTPException(415, "Please upload an image file.")
    image_bytes = await file.read()
    hf = HuggingFaceClient()
    caption = await hf.caption_image(image_bytes)
    return ok({"caption": caption, "filename": file.filename})