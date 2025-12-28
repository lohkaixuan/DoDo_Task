# app/routers/pet_ai.py
from __future__ import annotations

import os
from datetime import datetime
from typing import Optional, Literal, Dict, Any

from fastapi import APIRouter, Depends, UploadFile, File, HTTPException
from pydantic import BaseModel, Field

from app.db import get_db
from app.schemas.response import Envelope
from app.utils.response_utils import ok
from app.logic.risk_mongo import compute_stress_score

from app.services.pet_service_ai import GroqClient

router = APIRouter(prefix="/ai/pet", tags=["ai-pet"])


# -----------------------------
# Models
# -----------------------------
class ChatIn(BaseModel):
    user_id: str = Field(..., min_length=1)
    text: str = Field(..., min_length=1, max_length=1200)


class ChatOut(BaseModel):
    reply: str
    provider: Literal["groq"]
    sentiment: Dict[str, Any] | None = None
    risk: Dict[str, Any] | None = None
    ts: datetime


class SentimentIn(BaseModel):
    text: str = Field(..., min_length=1, max_length=1200)


# -----------------------------
# Helpers
# -----------------------------
def _normalize_sentiment(s: Any) -> Dict[str, Any]:
    if isinstance(s, dict):
        label = (s.get("label") or s.get("sentiment") or "neutral").strip().lower()
        score = float(s.get("score") or 0.0)
        return {"label": label, "score": score}

    if isinstance(s, str):
        label = s.strip().lower() or "neutral"
        score_map = {"positive": 0.8, "neutral": 0.0, "negative": -0.8}
        return {"label": label, "score": score_map.get(label, 0.0)}

    return {"label": "neutral", "score": 0.0}


def _persona(sentiment: Dict[str, Any], risk: Dict[str, Any]) -> str:
    label = sentiment.get("label", "neutral")
    score = float(sentiment.get("score", 0.0))
    stress = int(risk.get("score", 0) or 0)
    signals = risk.get("signals", []) or []

    if stress >= 70:
        guidance = (
            "User seems stressed. Suggest a tiny break: breathe 3 times, drink water, "
            "and propose a smaller next step. Keep it gentle."
        )
    elif 40 <= stress <= 69:
        guidance = (
            "User is a bit stressed. Suggest a 25-min focus sprint + water, "
            "and one small task to start."
        )
    else:
        guidance = "User stress is low. Celebrate consistency and suggest one small next step."

    return (
        "You are DoDo, a playful cute virtual pet companion. "
        "Speak in short, warm sentences. "
        "Use light emojis sometimes (max 1-2 per reply). "
        "Be encouraging, never shame the user. "
        "Give tiny actionable steps. "
        "If user asks unsafe content, refuse briefly and offer a safe alternative.\n"
        f"User mood: {label} (score={score:.2f}). "
        f"Stress score: {stress}. Signals: {signals}. "
        f"{guidance}\n"
        "Style rules: keep reply under 60 words if possible. "
        "Ask at most one question."
    )


def _build_prompt(user_text: str, sentiment: Dict[str, Any], risk: Dict[str, Any]) -> str:
    sys = _persona(sentiment, risk)
    return f"{sys}\nUser: {user_text}\nDoDo:"


# -----------------------------
# Routes
# -----------------------------
@router.post("/chat", response_model=Envelope[ChatOut])
async def chat(body: ChatIn, db=Depends(get_db)):
    groq = GroqClient()

    # 1) sentiment + risk
    try:
        s_raw = groq.analyze_sentiment(body.text)  # sync
    except Exception:
        s_raw = "neutral"
    senti = _normalize_sentiment(s_raw)

    risk = await compute_stress_score(db, body.user_id) or {"score": 0, "signals": []}

    # 2) prompt
    prompt = _build_prompt(body.text, senti, risk)

    # 3) groq reply
    provider: Literal["groq"] = "groq"
    reply = await groq.generate_reply(prompt)

    if not reply or not reply.strip():
        reply = "Eep 🐾 I blanked out for a sec… try again?"

    # 4) log (do not crash chat if logging fails)
    try:
        await db.events.insert_one(
            {
                "event_id": os.urandom(8).hex(),
                "user_id": body.user_id,
                "type": "pet_chat",
                "ts": datetime.utcnow(),
                "context": {
                    "text": body.text,
                    "reply": reply,
                    "provider": provider,
                    "sentiment": senti,
                    "risk": {"score": risk.get("score", 0), "signals": risk.get("signals", [])},
                },
            }
        )
    except Exception:
        pass

    return ok(ChatOut(reply=reply, provider=provider, sentiment=senti, risk=risk, ts=datetime.utcnow()))


@router.post("/analyze/sentiment", response_model=Envelope[Dict[str, Any]])
async def analyze_sentiment(body: SentimentIn):
    groq = GroqClient()
    try:
        s_raw = groq.analyze_sentiment(body.text)
    except Exception:
        s_raw = "neutral"
    return ok(_normalize_sentiment(s_raw))


@router.post("/analyze/image-caption", response_model=Envelope[Dict[str, Any]])
async def image_caption(file: UploadFile = File(...)):
    raise HTTPException(status_code=501, detail="Image caption is not implemented in this backend.")
