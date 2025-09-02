# app/logic/risk_mongo.py
from datetime import datetime, timedelta, date
from statistics import median
from bson.son import SON

def _dt_range(day: date):
    start = datetime.combine(day, datetime.min.time())
    end = datetime.combine(day, datetime.max.time())
    return start, end

async def rollup_daily(db, user_id: str, day: date):
    start, end = _dt_range(day)

    # tasks completed + avg priority
    pipe_tasks = [
        {"$match": {
            "user_id": user_id,
            "completed_at": {"$gte": start, "$lte": end}
        }},
        {"$group": {
            "_id": None,
            "count": {"$sum": 1},
            "avg_prio": {"$avg": "$priority"}
        }}
    ]
    t = await db.tasks.aggregate(pipe_tasks).to_list(1)
    tasks_completed = (t[0]["count"] if t else 0)
    avg_priority = (t[0]["avg_prio"] if t else None)

    # overdue_count (from events)
    overdue_count = await db.events.count_documents({
        "user_id": user_id, "type": "overdue", "ts": {"$gte": start, "$lte": end}
    })

    # focus minutes
    f = await db.focus_sessions.aggregate([
        {"$match": {"user_id": user_id, "started_at": {"$gte": start, "$lte": end}}},
        {"$group": {"_id": None, "m": {"$sum": {"$ifNull": ["$actual_minutes", 0]}}}}
    ]).to_list(1)
    focus_minutes = int(f[0]["m"]) if f else 0

    # breaks, hydration
    breaks_taken = await db.events.count_documents({
        "user_id": user_id, "type": "break_start", "ts": {"$gte": start, "$lte": end}
    })
    hydration_count = await db.events.count_documents({
        "user_id": user_id, "type": "hydrate", "ts": {"$gte": start, "$lte": end}
    })

    # sleep minutes from events.context.minutes
    s = await db.events.aggregate([
        {"$match": {"user_id": user_id, "type": "sleep_log", "ts": {"$gte": start, "$lte": end}}},
        {"$group": {"_id": None, "mins": {"$sum": {"$ifNull": ["$context.minutes", 0]}}}}
    ]).to_list(1)
    sleep_minutes = int(s[0]["mins"]) if s else 0

    # negative/anxious/tired mood count
    mood_negative_count = await db.mood_logs.count_documents({
        "user_id": user_id, "ts": {"$gte": start, "$lte": end},
        "label": {"$in": ["negative", "anxious", "tired"]}
    })

    # late-night usage (events 00:00–05:59)
    ln = await db.events.aggregate([
        {"$match": {"user_id": user_id, "ts": {"$gte": start, "$lte": end}}},
        {"$project": {"hour": {"$hour": "$ts"}}},
        {"$match": {"hour": {"$gte": 0, "$lte": 5}}},
        {"$count": "n"}
    ]).to_list(1)
    late_night_usage = (ln[0]["n"] if ln else 0)

    doc = {
        "user_id": user_id,
        "date": day.isoformat(),
        "tasks_completed": tasks_completed,
        "overdue_count": int(overdue_count),
        "avg_priority_completed": avg_priority,
        "total_focus_minutes": focus_minutes,
        "breaks_taken": int(breaks_taken),
        "hydration_count": int(hydration_count),
        "sleep_minutes": sleep_minutes,
        "mood_negative_count": int(mood_negative_count),
        "late_night_usage": int(late_night_usage)
    }
    await db.usage_stats_daily.update_one(
        {"user_id": user_id, "date": day.isoformat()},
        {"$set": doc},
        upsert=True
    )
    return doc

async def _overdue_streak(db, user_id: str, until_day: date, max_days=7):
    # get last 7 days rollups
    days = [(until_day - timedelta(days=i)).isoformat() for i in range(max_days)]
    rows = await db.usage_stats_daily.find(
        {"user_id": user_id, "date": {"$in": days}}
    ).sort("date", -1).to_list(length=max_days)

    streak = 0
    for r in rows:
        if r.get("overdue_count",0) > 0:
            streak += 1
        else:
            break
    return streak

def _choose_pet_reaction(score: float) -> str:
    if score >= 70: return "concern"
    if score >= 40: return "cheer"
    return "idle"

async def compute_stress_score(db, user_id: str, window: str = "daily"):
    now = datetime.utcnow()
    day = now.date()
    today = await rollup_daily(db, user_id, day)

    signals = {}
    score = 0.0

    streak = await _overdue_streak(db, user_id, day)
    signals["overdue_streak"] = streak
    score += min(20, streak * 7)

    signals["neg_mood"] = today["mood_negative_count"]
    score += min(25, today["mood_negative_count"] * 5)

    signals["sleep_low"] = today["sleep_minutes"] < 360
    if signals["sleep_low"]: score += 15

    signals["late_night_usage"] = today["late_night_usage"]
    score += min(15, today["late_night_usage"] * 5)

    focus_minutes = max(today["total_focus_minutes"], 1)
    interruptions_per_hour = today["breaks_taken"] / (focus_minutes/60.0)
    signals["interruptions_per_hour"] = round(interruptions_per_hour, 2)
    score += min(15, interruptions_per_hour * 3)

    signals["hydration_low"] = today["hydration_count"] < 3
    if signals["hydration_low"]: score += 10

    score = float(min(100, round(score, 1)))
    reaction = _choose_pet_reaction(score)

    doc = {
        "user_id": user_id,
        "ts": now.isoformat(),
        "window": window,
        "score": score,
        "signals": signals,
        "pet_reaction": reaction,
        "suggestion": (
            "I’m sensing strain—2-min breathing + reschedule 1 task earlier."
            if score >= 70 else
            ("Tiny step time! 25-min focus + sip water." if score >= 40
             else "Looking good—keep steady 💪")
        )
    }
    await db.stress_risk_scores.insert_one(doc)
    # (optional) also update pet mood/energy
    await db.pets.update_one({"user_id": user_id}, {"$set": {"mood": "concerned" if score>=70 else ("happy" if score<40 else "idle")}}, upsert=True)
    return doc

async def recommend_new_due_date(db, user_id: str, task_id: str):
    task = await db.tasks.find_one({"task_id": task_id, "user_id": user_id})
    if not task or not task.get("due_date"):
        return None

    # look at user's completed tasks in same (category, priority)
    cursor = db.tasks.find({
        "user_id": user_id,
        "category": task.get("category"),
        "priority": task.get("priority"),
        "completed_at": {"$ne": None},
        "due_date": {"$ne": None}
    }, {"completed_at": 1, "due_date": 1}).limit(200)

    delays = []
    async for t in cursor:
        try:
            completed = t["completed_at"]
            if isinstance(completed, str): completed = datetime.fromisoformat(completed.replace("Z",""))
            due = t["due_date"]
            if isinstance(due, str): due = datetime.fromisoformat(due)
            d = (completed.date() - due.date()).days
            if d > 0:
                delays.append(d)
        except Exception:
            continue

    if not delays:
        return None

    med_delay = int(median(delays))
    pull_forward = min(3, max(1, med_delay))
    # task['due_date'] might be string date
    due = task["due_date"]
    if isinstance(due, str): due = datetime.fromisoformat(due)
    suggested = (due - timedelta(days=pull_forward)).date().isoformat()

    return {
        "task_id": task_id,
        "current_due": task["due_date"],
        "suggested_due": suggested,
        "reason": f"median lateness {med_delay}d → pulling {pull_forward}d earlier"
    }
