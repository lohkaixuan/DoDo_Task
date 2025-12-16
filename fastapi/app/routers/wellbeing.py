# app/routers/wellbeing.py
from fastapi import APIRouter, Depends
from pydantic import BaseModel, Field
from typing import Optional, Literal
from datetime import datetime, date
from app.db import get_db
from app.schemas.response import Envelope
from app.utils.response_utils import ok, created
from app.logic.risk_mongo import compute_stress_score, recommend_new_due_date, rollup_daily

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
@router.post("/events", response_model=Envelope[dict])
async def ingest_event(body: EventIn, db=Depends(get_db)):
    doc = body.model_dump()
    doc["ts"] = doc["ts"] or datetime.utcnow()
    await db.events.insert_one(doc)
    return created({"inserted": True, "event_id": body.event_id}, message="Event ingested")

@router.post("/mood", response_model=Envelope[dict])
async def log_mood(body: MoodIn, db=Depends(get_db)):
    doc = body.model_dump()
    doc["ts"] = doc["ts"] or datetime.utcnow()
    await db.mood_logs.insert_one(doc)
    return created({"inserted": True, "mood_id": body.mood_id}, message="Mood logged")

# ---------- Daily rollup ----------
@router.post("/rollup/{user_id}", response_model=Envelope[dict])
async def do_rollup(user_id: str, day: Optional[date] = None, db=Depends(get_db)):
    d = day or datetime.utcnow().date()
    out = await rollup_daily(db, user_id, d)
    return ok(out, message="Daily rollup")

# ---------- Risk ----------
@router.get("/risk/{user_id}", response_model=Envelope[dict])
async def risk(user_id: str, db=Depends(get_db)):
    s = await compute_stress_score(db, user_id)
    return ok(s, message="Risk computed")

# ---------- Due-date recommendation ----------
@router.get("/tasks/{task_id}/recommend-due", response_model=Envelope[dict | None])
async def recommend_due(task_id: str, user_id: str, db=Depends(get_db)):
    info = await recommend_new_due_date(db, user_id, task_id)
    return ok(info or {"message": "No chronic delay detected."}, message="Recommendation")
