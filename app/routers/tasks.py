# app/routers/tasks.py
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from typing import Optional, Literal
from datetime import datetime, date
import uuid
from ..db import get_db

router = APIRouter(prefix="/tasks", tags=["tasks"])

class TaskIn(BaseModel):
    user_id: str
    title: str
    category: Literal["Academic","Personal","Private"]
    priority: int = 2            # 1=High,2=Med,3=Low
    estimated_time: Optional[int] = None  # minutes
    due_date: Optional[date] = None

@router.post("", status_code=201)
async def create_task(body: TaskIn, db = Depends(get_db)):
    task_id = str(uuid.uuid4())
    doc = {
        "task_id": task_id,
        "user_id": body.user_id,
        "title": body.title,
        "category": body.category,
        "priority": body.priority,
        "estimated_time": body.estimated_time,
        "due_date": body.due_date.isoformat() if body.due_date else None,
        "status": "pending",
        "completed_at": None,
        "created_at": datetime.utcnow().isoformat()
    }
    await db.tasks.insert_one(doc)
    return {"task_id": task_id, **doc}

@router.post("/{task_id}/start")
async def start_task(task_id: str, user_id: str, db = Depends(get_db)):
    task = await db.tasks.find_one({"task_id": task_id, "user_id": user_id})
    if not task:
        raise HTTPException(404, "Task not found")
    # event for analytics
    await db.events.insert_one({
        "event_id": str(uuid.uuid4()),
        "user_id": user_id,
        "type": "task_start",
        "ts": datetime.utcnow(),
        "context": {"task_id": task_id}
    })
    return {"ok": True}

@router.patch("/{task_id}/complete")
async def complete_task(task_id: str, user_id: str, db = Depends(get_db)):
    task = await db.tasks.find_one({"task_id": task_id, "user_id": user_id})
    if not task:
        raise HTTPException(404, "Task not found")

    now = datetime.utcnow()
    is_overdue = False
    if task.get("due_date"):
        try:
            due = datetime.fromisoformat(task["due_date"])
            is_overdue = now.date() > due.date()
        except Exception:
            pass

    # update task status
    await db.tasks.update_one(
        {"task_id": task_id, "user_id": user_id},
        {"$set": {"status": "done", "completed_at": now.isoformat()}}
    )

    # log complete
    await db.events.insert_one({
        "event_id": str(uuid.uuid4()),
        "user_id": user_id,
        "type": "task_complete",
        "ts": now,
        "context": {"task_id": task_id}
    })

    # log overdue if late (for pattern analysis)
    if is_overdue:
        await db.events.insert_one({
            "event_id": str(uuid.uuid4()),
            "user_id": user_id,
            "type": "overdue",
            "ts": now,
            "context": {"task_id": task_id}
        })

    return {"ok": True, "overdue": is_overdue}
