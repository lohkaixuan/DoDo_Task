# app/routers/health_productivity.py
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from ..db import get_session
from ..models import Event, MoodLog, StressRiskScore, Task
from ..logic.risk_mongo import compute_stress_score, recommend_new_due_date, choose_pet_reaction
from pydantic import BaseModel
from datetime import datetime

router = APIRouter(prefix="/wellbeing", tags=["wellbeing"])

class EventIn(BaseModel):
    event_id: str
    user_id: str
    type: str
    ts: datetime | None = None
    context: dict | None = None

@router.post("/events")
def ingest_event(body: EventIn, db: Session = Depends(get_session)):
    ev = Event(
        event_id=body.event_id, user_id=body.user_id,
        type=body.type, ts=body.ts or datetime.utcnow(),
        context=body.context or {}
    )
    db.add(ev); db.commit()
    return {"ok": True}

class MoodIn(BaseModel):
    mood_id: str
    user_id: str
    label: str
    source: str
    ts: datetime | None = None
    confidence: float = 1.0
    notes: str | None = None

@router.post("/mood")
def log_mood(body: MoodIn, db: Session = Depends(get_session)):
    m = MoodLog(**body.model_dump())
    db.add(m); db.commit()
    return {"ok": True}

@router.get("/risk/{user_id}")
def risk(user_id: str, db: Session = Depends(get_session)):
    s: StressRiskScore = compute_stress_score(db, user_id)
    return {
        "score": s.score,
        "signals": s.signals,
        "pet_reaction": choose_pet_reaction(s.score),
        "suggestion": _text_for_score(s.score, s.signals),
    }

def _text_for_score(score: float, signals: dict) -> str:
    if score >= 70:
        return "I’m sensing strain—2-min breathing + reschedule 1 task earlier."
    if score >= 40:
        return "Tiny step time! 25-min focus + sip water."
    return "Looking good—keep steady 💪"

@router.get("/tasks/{task_id}/recommend-due")
def recommend_due(task_id: str, user_id: str, db: Session = Depends(get_session)):
    task = db.get(Task, task_id)
    if not task or task.user_id != user_id:
        raise HTTPException(404, "Task not found")
    info = recommend_new_due_date(db, user_id, task)
    return info or {"message": "No chronic delay detected."}
