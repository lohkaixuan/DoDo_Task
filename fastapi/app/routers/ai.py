# app/routers/ai.py
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field
from typing import List, Optional, Dict, Any
from datetime import datetime
import os

from app.schemas.response import Envelope
from fastapi.app.utils.response_utils import ok

router = APIRouter(prefix="/ai", tags=["ai"])

# ---------- (原有的 /ai/chat 如果你有就保留；这里略) ----------
# @router.post("/chat")
# async def chat(...):
#     ...

# ---------- Schemas ----------
class TaskIn(BaseModel):
    id: str
    title: str
    category: Optional[str] = None
    status: str                    # notStarted/inProgress/completed/late/archived
    type: str                      # singleDay/ranged
    dueDateTime: Optional[datetime] = None
    startDate: Optional[datetime] = None
    dueDate: Optional[datetime] = None
    estimatedMinutes: Optional[int] = None
    spentMinutes: Optional[int] = None
    priority: Optional[str] = "medium"  # low/medium/high/urgent
    important: Optional[bool] = True
    completedAt: Optional[datetime] = None  # 可选，如果没有我们做粗略推断

class SummaryIn(BaseModel):
    user_id: str = Field(..., description="current user id")
    tasks: List[TaskIn]

class SummaryOut(BaseModel):
    summary: str
    metrics: Dict[str, Any]

# ---------- Helpers ----------
def _to_date(dt: Optional[datetime]) -> Optional[datetime]:
    return dt

def _minutes_diff(a: datetime, b: datetime) -> int:
    return int((a - b).total_seconds() // 60)

def _heuristic_summarize(metrics: Dict[str, Any]) -> str:
    total = metrics.get("total_tasks", 0)
    if total == 0:
        return ("You currently don’t have any task data. "
                "Create some tasks and complete them—then I’ll analyze and give personalized recommendations.")

    overall = metrics.get("overall", {})
    on_time = overall.get("on_time_rate", 0.0)
    early   = overall.get("early_rate", 0.0)
    late    = overall.get("late_rate", 0.0)
    avg_tardy = overall.get("avg_late_minutes", 0)
    avg_early = overall.get("avg_early_minutes", 0)

    top_slow = metrics.get("top_late_categories", [])
    top_fast = metrics.get("top_early_categories", [])

    s = []
    s.append(f"You currently have {total} tasks. On-time rate ~{on_time:.0%}, early ~{early:.0%}, late ~{late:.0%}.")
    if top_fast:
      s.append(f"You often complete 「{', '.join(top_fast[:3])}」 ahead of time—great pacing here!")
    if top_slow:
      s.append(f"Tasks like 「{', '.join(top_slow[:3])}」 tend to be delayed. Try planning earlier or splitting into subtasks.")
    if avg_early > 0:
      s.append(f"On average you finish {avg_early} minutes early—nice execution. Keep it up!")
    if avg_tardy > 0:
      s.append(f"On average tasks are delayed by {avg_tardy} minutes. Consider day-before micro-planning or finer reminders.")
    return " ".join(s)

async def _maybe_llm_enhance(metrics: Dict[str, Any]) -> Optional[str]:
    """
    如果有 GROQ_API_KEY，就用 LLM 生成更自然的总结；否则返回 None
    """
    api_key = os.getenv("GROQ_API_KEY")
    if not api_key:
        return None

    import httpx
    prompt = f"""
You are an expert productivity coach. Based on the user's task metrics below,
write a friendly 100-word summary with 3 actionable recommendations.
Metrics: {metrics}
    """.strip()

    url = "https://api.groq.ai/v1/chat/completions"
    headers = {"Authorization": f"Bearer {api_key}"}
    body = {
        "model": "llama3-8b-8192",   # 或 "mixtral-8x7b"
        "messages": [
            {"role": "system", "content": "You help users improve productivity with clear, kind guidance."},
            {"role": "user",   "content": prompt},
        ],
        "temperature": 0.6,          # 注意拼写：temperature
    }

    try:
        async with httpx.AsyncClient(timeout=30) as client:
            r = await client.post(url, headers=headers, json=body)
            r.raise_for_status()
            data = r.json()
            return data["choices"][0]["message"]["content"].strip()
    except Exception:
        return None

# ---------- /ai/summary ----------
@router.post("/summary", response_model=Envelope[SummaryOut])
async def summarize_tasks(payload: SummaryIn):
    tasks = payload.tasks

    # --- 1) 统计 ---
    total = len(tasks)
    per_cat: Dict[str, Dict[str, Any]] = {}
    overall = {
        "on_time": 0,
        "early": 0,
        "late": 0,
        "early_samples": [],  # minutes (positive)
        "late_samples": [],   # minutes (positive)
    }

    for t in tasks:
        cat = (t.category or "Uncategorized").strip()
        if cat not in per_cat:
            per_cat[cat] = {
                "total": 0,
                "on_time": 0,
                "early": 0,
                "late": 0,
                "early_samples": [],
                "late_samples": [],
            }
        c = per_cat[cat]
        c["total"] += 1

        status = (t.status or "").lower()
        if status == "completed":
            due = t.dueDateTime or _to_date(t.dueDate)
            comp = t.completedAt or datetime.utcnow()
            if due:
                diff = _minutes_diff(comp, due)  # +晚  -早
                if diff < -1:
                    c["early"] += 1
                    overall["early"] += 1
                    c["early_samples"].append(abs(diff))
                    overall["early_samples"].append(abs(diff))
                elif diff <= 30:
                    c["on_time"] += 1
                    overall["on_time"] += 1
                else:
                    c["late"] += 1
                    overall["late"] += 1
                    c["late_samples"].append(diff)
                    overall["late_samples"].append(diff)
            else:
                c["on_time"] += 1
                overall["on_time"] += 1
        elif status == "late":
            c["late"] += 1
            overall["late"] += 1
        else:
            # notStarted / inProgress / archived -> 不计入完成统计
            pass

    def _avg(xs): return int(sum(xs) / len(xs)) if xs else 0

    overall_out = {
        "on_time_rate": (overall["on_time"] / total) if total else 0.0,
        "early_rate":   (overall["early"] / total) if total else 0.0,
        "late_rate":    (overall["late"] / total) if total else 0.0,
        "avg_early_minutes": _avg(overall["early_samples"]),
        "avg_late_minutes":  _avg(overall["late_samples"]),
    }

    cat_out: Dict[str, Dict[str, Any]] = {}
    for k, v in per_cat.items():
        n = v["total"] or 1
        cat_out[k] = {
            "total": v["total"],
            "on_time_rate": v["on_time"] / n,
            "early_rate":   v["early"] / n,
            "late_rate":    v["late"] / n,
            "avg_early_minutes": _avg(v["early_samples"]),
            "avg_late_minutes":  _avg(v["late_samples"]),
        }

    top_late  = sorted(cat_out.items(), key=lambda x: x[1]["late_rate"],  reverse=True)
    top_early = sorted(cat_out.items(), key=lambda x: x[1]["early_rate"], reverse=True)

    metrics = {
        "user_id": payload.user_id,
        "total_tasks": total,
        "overall": overall_out,
        "by_category": cat_out,
        "top_late_categories":  [k for k, v in top_late  if v["late_rate"]  > 0][:5],
        "top_early_categories": [k for k, v in top_early if v["early_rate"] > 0][:5],
    }

    # --- 2) 生成 summary 文本 ---
    llm_text = await _maybe_llm_enhance(metrics)
    summary = llm_text or _heuristic_summarize(metrics)
    return ok(SummaryOut(summary=summary, metrics=metrics))
