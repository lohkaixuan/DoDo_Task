# app/routers/tasks.py
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from typing import Optional, Literal
from datetime import datetime, date
import uuid
from app.db import get_db
from app.schemas.response import Envelope
from app.utils.response import ok, created

router = APIRouter(prefix="/tasks", tags=["tasks"])

class TaskIn(BaseModel):
    user_id: str
    title: str
    category: Literal["Academic","Personal","Private"]
    priority: int = 2
    estimated_time: Optional[int] = None
    due_date: Optional[date] = None

@router.post("", status_code=201, response_model=Envelope[dict])
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
    return created(doc, message="Task created")

@router.post("/{task_id}/start", response_model=Envelope[dict])
async def start_task(task_id: str, user_id: str, db = Depends(get_db)):
    task = await db.tasks.find_one({"task_id": task_id, "user_id": user_id})
    if not task:
        raise HTTPException(404, "Task not found")
    await db.events.insert_one({
        "event_id": str(uuid.uuid4()),
        "user_id": user_id,
        "type": "task_start",
        "ts": datetime.utcnow(),
        "context": {"task_id": task_id}
    })
    return ok({"started": True, "task_id": task_id}, message="Task started")

@router.patch("/{task_id}/complete", response_model=Envelope[dict])
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

    await db.tasks.update_one(
        {"task_id": task_id, "user_id": user_id},
        {"$set": {"status": "done", "completed_at": now.isoformat()}}
    )

    await db.events.insert_one({
        "event_id": str(uuid.uuid4()),
        "user_id": user_id,
        "type": "task_complete",
        "ts": now,
        "context": {"task_id": task_id}
    })

    if is_overdue:
        await db.events.insert_one({
            "event_id": str(uuid.uuid4()),
            "user_id": user_id,
            "type": "overdue",
            "ts": now,
            "context": {"task_id": task_id}
        })

    return ok({"completed": True, "task_id": task_id, "overdue": is_overdue}, message="Task completed")
