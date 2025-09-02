# app/routers/wellbeing.py
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from typing import Optional, Literal
from datetime import datetime, date, timedelta
from ..db import get_db
from ..logic.risk_mongo import compute_stress_score, recommend_new_due_date, rollup_daily

router = APIRouter(prefix="/wellbeing", tags=["wellbeing"])

# ---------- Inputs ----------
class EventIn(BaseModel):
    event_id: str
    user_id: str
    type: Literal[
        "task_start","task_complete","overdue","break_start","break_end",
        "hydrate","sleep_log","focus_start","focus_tick","shop_purchase",
        "app_open","app_idle","emotion_text","emotion_voice"
    ]
    ts: Optional[datetime] = None
    context: dict = Field(default_factory=dict)

class MoodIn(BaseModel):
    mood_id: str
    user_id: str
    ts: Optional[datetime] = None
    source: Literal["user_text","user_slider","voice_infer","text_infer"]
    label: Literal["positive","neutral","negative","anxious","tired"]
    confidence: float = 1.0
    notes: Optional[str] = None

# ---------- Ingestion ----------
@router.post("/events")
async def ingest_event(body: EventIn, db=Depends(get_db)):
    doc = body.model_dump()
    doc["ts"] = doc["ts"] or datetime.utcnow()
    await db.events.insert_one(doc)
    return {"ok": True}

@router.post("/mood")
async def log_mood(body: MoodIn, db=Depends(get_db)):
    doc = body.model_dump()
    doc["ts"] = doc["ts"] or datetime.utcnow()
    await db.mood_logs.insert_one(doc)
    return {"ok": True}

# ---------- Daily rollup (can be cron) ----------
@router.post("/rollup/{user_id}")
async def do_rollup(user_id: str, day: Optional[date] = None, db=Depends(get_db)):
    d = day or datetime.utcnow().date()
    out = await rollup_daily(db, user_id, d)
    return out

# ---------- Risk + pet suggestion ----------
@router.get("/risk/{user_id}")
async def risk(user_id: str, db=Depends(get_db)):
    s = await compute_stress_score(db, user_id)
    return s

# ---------- Due-date recommendation ----------
@router.get("/tasks/{task_id}/recommend-due")
async def recommend_due(task_id: str, user_id: str, db=Depends(get_db)):
    info = await recommend_new_due_date(db, user_id, task_id)
    if not info:
        return {"message": "No chronic delay detected."}
    return info
