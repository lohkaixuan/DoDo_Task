# app/routers/health_productivity.py
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from datetime import datetime
from app.db import get_db
from app.schemas.response import Envelope
from app.utils.response import ok, created
from app.logic.risk_mongo import compute_stress_score, recommend_new_due_date, choose_pet_reaction

router = APIRouter(prefix="/wellbeing", tags=["wellbeing"])

# ---------- Event ----------
class EventIn(BaseModel):
    event_id: str
    user_id: str
    type: str
    ts: datetime | None = None
    context: dict | None = None

@router.post("/events", response_model=Envelope[dict])
async def ingest_event(body: EventIn, db=Depends(get_db)):
    doc = body.model_dump()
    doc["ts"] = doc["ts"] or datetime.utcnow()
    await db.events.insert_one(doc)
    return created({"inserted": True, "event_id": body.event_id}, message="Event ingested")

# ---------- Mood ----------
class MoodIn(BaseModel):
    mood_id: str
    user_id: str
    label: str
    source: str
    ts: datetime | None = None
    confidence: float = 1.0
    notes: str | None = None

@router.post("/mood", response_model=Envelope[dict])
async def log_mood(body: MoodIn, db=Depends(get_db)):
    doc = body.model_dump()
    doc["ts"] = doc["ts"] or datetime.utcnow()
    await db.mood.insert_one(doc)
    return created({"inserted": True, "mood_id": body.mood_id}, message="Mood logged")

# ---------- Stress Risk ----------
@router.get("/risk/{user_id}", response_model=Envelope[dict])
async def risk(user_id: str, db=Depends(get_db)):
    s = await compute_stress_score(db, user_id)
    return ok({
        "score": s["score"],
        "signals": s["signals"],
        "pet_reaction": choose_pet_reaction(s["score"]),
        "suggestion": _text_for_score(s["score"], s["signals"]),
    }, message="Risk computed")

def _text_for_score(score: float, signals: dict) -> str:
    if score >= 70:
        return "I’m sensing strain—2-min breathing + reschedule 1 task earlier."
    if score >= 40:
        return "Tiny step time! 25-min focus + sip water."
    return "Looking good—keep steady 💪"

# ---------- Task Due Recommendation ----------
@router.get("/tasks/{task_id}/recommend-due", response_model=Envelope[dict | None])
async def recommend_due(task_id: str, user_id: str, db=Depends(get_db)):
    task = await db.tasks.find_one({"_id": task_id, "user_id": user_id})
    if not task:
        raise HTTPException(404, "Task not found")
    info = await recommend_new_due_date(db, user_id, task)
    return ok(info or {"message": "No chronic delay detected."}, message="Recommendation")
