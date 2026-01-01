# app/routers/wellbeing.py
from fastapi import APIRouter, Depends, Query
from pydantic import BaseModel, Field
from typing import Optional, Literal, Dict, Any, List
from datetime import datetime, date, timedelta

from app.db import get_db
from app.schemas.response import Envelope
from app.utils.response_utils import ok, created
from app.logic.risk_mongo import compute_stress_score, recommend_new_due_date, rollup_daily
from app.services.auth_service import require_user_id

router = APIRouter(prefix="/wellbeing", tags=["wellbeing"])

# -----------------------------
# Helpers
# -----------------------------
def _to_json(doc: dict) -> dict:
    doc = dict(doc)
    if "_id" in doc:
        doc["_id"] = str(doc["_id"])
    if "ts" in doc and hasattr(doc["ts"], "isoformat"):
        doc["ts"] = doc["ts"].isoformat()
    if "updated_at" in doc and hasattr(doc["updated_at"], "isoformat"):
        doc["updated_at"] = doc["updated_at"].isoformat()
    return doc


# -----------------------------
# USER mood (Setting page)
# -----------------------------
class MoodIn(BaseModel):
    mood_id: str
    ts: Optional[datetime] = None
    source: Literal["user_text", "user_slider", "voice_infer", "text_infer"]
    label: Literal["positive", "neutral", "negative", "anxious", "tired"]
    confidence: float = 1.0
    notes: Optional[str] = None


@router.post("/mood", response_model=Envelope[dict])
async def log_mood(
    body: MoodIn,
    db=Depends(get_db),
    user_id: str = Depends(require_user_id),
):
    doc = body.model_dump()
    doc["user_id"] = user_id
    doc["ts"] = doc["ts"] or datetime.utcnow()
    await db.mood_logs.insert_one(doc)
    return created({"inserted": True, "mood_id": body.mood_id}, message="Mood logged")


@router.get("/mood/history", response_model=Envelope[List[dict]])
async def get_mood_history_token(
    limit: int = Query(30, ge=1, le=200),
    db=Depends(get_db),
    user_id: str = Depends(require_user_id),
):
    cursor = (
        db.mood_logs.find(
            {"user_id": user_id},
            {"_id": 1, "user_id": 1, "ts": 1, "label": 1, "confidence": 1, "notes": 1, "source": 1},
        )
        .sort("ts", -1)
        .limit(limit)
    )
    items = [_to_json(doc) async for doc in cursor]
    return ok(items, message="Mood history retrieved")


# -----------------------------
# PET mood (Dashboard -> Insights below)
# -----------------------------
PetMood = Literal["idle", "happy", "sad", "tired", "hungry", "angry"]

class PetMoodSetIn(BaseModel):
    mood: PetMood
    reason: str = Field(default="manual")  # e.g. use_food:apple, purchase:lamp
    ts: Optional[datetime] = None


async def _ensure_pet(db, user_id: str) -> Dict[str, Any]:
    pet = await db.pets.find_one({"user_id": user_id})
    if pet:
        return pet
    doc = {"user_id": user_id, "mood": "idle", "updated_at": datetime.utcnow()}
    await db.pets.insert_one(doc)
    return doc


async def _log_pet_mood(db, user_id: str, mood: str, reason: str, ts: Optional[datetime] = None):
    now = ts or datetime.utcnow()

    await db.pets.update_one(
        {"user_id": user_id},
        {"$set": {"mood": mood, "updated_at": now}},
        upsert=True,
    )

    await db.pet_mood_logs.insert_one(
        {"user_id": user_id, "mood": mood, "reason": reason, "ts": now}
    )


@router.get("/pet", response_model=Envelope[Dict[str, Any]])
async def get_pet_state(
    db=Depends(get_db),
    user_id: str = Depends(require_user_id),
):
    pet = await _ensure_pet(db, user_id)
    return ok({
        "user_id": user_id,
        "mood": pet.get("mood", "idle"),
        "updated_at": pet.get("updated_at"),
    })


@router.post("/pet/mood", response_model=Envelope[Dict[str, Any]])
async def set_pet_mood(
    body: PetMoodSetIn,
    db=Depends(get_db),
    user_id: str = Depends(require_user_id),
):
    await _log_pet_mood(db, user_id, body.mood, body.reason, body.ts)
    return created({"updated": True, "mood": body.mood, "reason": body.reason}, message="Pet mood updated")


@router.get("/pet/mood/history", response_model=Envelope[List[Dict[str, Any]]])
async def get_pet_mood_history(
    limit: int = Query(30, ge=1, le=200),
    db=Depends(get_db),
    user_id: str = Depends(require_user_id),
):
    rows = await db.pet_mood_logs.find({"user_id": user_id}).sort("ts", -1).to_list(limit)
    return ok([_to_json(r) for r in rows], message="Pet mood history")


# -----------------------------
# Existing wellbeing stuff
# -----------------------------
class EventIn(BaseModel):
    event_id: str
    # ✅ 建议：不要让前端传 user_id（避免伪造），我们用 token 的 user_id
    type: Literal[
        "task_start","task_complete","overdue","break_start","break_end",
        "hydrate","sleep_log","focus_start","focus_tick","shop_purchase",
        "app_open","app_idle","emotion_text","emotion_voice"
    ]
    ts: Optional[datetime] = None
    context: dict = Field(default_factory=dict)

# ✅ 哪些 event 会影响 usage_stats_daily
ROLLUP_TYPES = {
    "task_complete","overdue","break_start","hydrate","sleep_log",
    "focus_start","focus_tick","app_open","app_idle"
}

@router.post("/events", response_model=Envelope[dict])
async def ingest_event(
    body: EventIn,
    db=Depends(get_db),
    user_id: str = Depends(require_user_id),  # ✅ 用 token user_id
):
    doc = body.model_dump()
    doc["user_id"] = user_id                 # ✅ 强制写入 token user_id
    doc["ts"] = doc["ts"] or datetime.utcnow()

    await db.events.insert_one(doc)

    # ✅ 插入后立刻 rollup 当天（只对关键类型）
    if body.type in ROLLUP_TYPES:
        await rollup_daily(db, user_id, doc["ts"].date())

    return created(
        {"inserted": True, "event_id": body.event_id},
        message="Event ingested"
    )


@router.post("/rollup/{user_id}", response_model=Envelope[dict])
async def do_rollup(user_id: str, day: Optional[date] = None, db=Depends(get_db)):
    d = day or datetime.utcnow().date()
    out = await rollup_daily(db, user_id, d)
    return ok(out, message="Daily rollup")


@router.get("/risk/{user_id}", response_model=Envelope[dict])
async def risk(user_id: str, db=Depends(get_db)):
    s = await compute_stress_score(db, user_id)
    return ok(s, message="Risk computed")


@router.get("/tasks/{task_id}/recommend-due", response_model=Envelope[dict | None])
async def recommend_due(task_id: str, user_id: str, db=Depends(get_db)):
    info = await recommend_new_due_date(db, user_id, task_id)
    return ok(info or {"message": "No chronic delay detected."}, message="Recommendation")

# NEW: daily usage stats (token)
@router.get("/stats/daily", response_model=Envelope[List[Dict[str, Any]]])
async def get_usage_stats_daily(
    days: int = Query(14, ge=1, le=120),
    db=Depends(get_db),
    user_id: str = Depends(require_user_id),
):
    # return last N days
    # collection: usage_stats_daily
    # fields expected: user_id, date (YYYY-MM-DD), total_focus_minutes, tasks_completed, etc.

    cursor = (
        db.usage_stats_daily
        .find({"user_id": user_id})
        .sort("date", -1)
        .limit(days)
    )

    rows = [_to_json(r) async for r in cursor]
    rows.reverse()  # make it ascending for chart left->right
    return ok(rows, message="Daily usage stats")
