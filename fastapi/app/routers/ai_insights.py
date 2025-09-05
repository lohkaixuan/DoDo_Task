# app/routers/ai_insights.py
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field
from typing import List, Optional, Dict, Any
from datetime import datetime, time
import os

from app.schemas.response import Envelope
from app.utils.response import ok

router = APIRouter(prefix="/ai", tags=["ai"])

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
    completedAt: Optional[datetime] = None  # 客户端若能发更好

class SummaryIn(BaseModel):
    user_id: str = Field(..., description="current user id")
    tasks: List[TaskIn]

class SummaryOut(BaseModel):
    summary: str
    metrics: Dict[str, Any]

# ---------- Helpers ----------
def _to_date(dt: Optional[datetime]) -> Optional[datetime]:
    """
    如果是日期（无时间），补成当天 23:59:59；若为空返回 None
    由于 Pydantic 已解析为 datetime，这里容错保留一层，方便你后续替换为 date 字段时兼容。
    """
    if dt is None:
        return None
    # 已经是 datetime，就直接返回；如果你改成 date 再来，这里可做 .combine()
    return dt

def _minutes_diff(a: datetime, b: datetime) -> int:
    return int((a - b).total_seconds() // 60)

def _avg(xs: List[int]) -> int:
    return int(sum(xs) / len(xs)) if xs else 0

def _heuristic_summarize(metrics: Dict[str, Any]) -> str:
    """无 LLM 时，生成可读的总结与建议"""
    total = metrics.get("total_tasks", 0)
    if total == 0:
        return (
            "You don't have any task data yet. Create and complete some tasks, "
            "and I’ll analyze your habits and give personalized recommendations!"
        )

    overall = metrics.get("overall", {})
    on_time = overall.get("on_time_rate", 0.0)
    late = overall.get("late_rate", 0.0)
    early = overall.get("early_rate", 0.0)
    avg_tardy = overall.get("avg_late_minutes", 0)
    avg_early = overall.get("avg_early_minutes", 0)

    top_slow = metrics.get("top_late_categories", [])
    top_fast = metrics.get("top_early_categories", [])

    s = []
    s.append(
        f"You currently have {total} tasks, with an on-time completion rate of ~{on_time:.0%}, "
        f"early completion rate of ~{early:.0%}, and late rate of ~{late:.0%}."
    )
    if top_fast:
        s.append(
            f"You often complete tasks in 「{', '.join(top_fast[:3])}」 early — great pacing there!"
        )
    if top_slow:
        s.append(
            f"Tasks in 「{', '.join(top_slow[:3])}」 tend to be delayed. "
            "Try breaking them into smaller subtasks or planning a day earlier."
        )
    if avg_early > 0:
        s.append(f"On average, you complete tasks {avg_early} minutes early — solid execution!")
    if avg_tardy > 0:
        s.append(
            f"On average, tasks are delayed by {avg_tardy} minutes. "
            "Consider micro-planning the day before or enabling more granular reminders."
        )
    return " ".join(s)

async def _maybe_llm_enhance(metrics: Dict[str, Any]) -> Optional[str]:
    """
    如果配置了 GROQ_API_KEY，就请求 LLM 生成更友好的总结；否则返回 None。
    """
    api_key = os.getenv("GROQ_API_KEY")
    if not api_key:
        return None

    import httpx
    prompt = f"""
You are an expert productivity coach. Based on the user's task completion metrics below, 
provide a concise summary (<=100 words) and 3 actionable recommendations to help the user 
improve their task management. Use a friendly and encouraging tone.

Metrics JSON:
{metrics}
""".strip()

    url = "https://api.groq.ai/v1/chat/completions"
    headers = {"Authorization": f"Bearer {api_key}"}
    body = {
        "model": "llama-3.1-8b-instant",  # 你可以换成自己要的
        "messages": [
            {"role": "system", "content": "You are a helpful coach."},
            {"role": "user", "content": prompt},
        ],
        "temperature": 0.6,  # ← 修正拼写
    }

    try:
        async with httpx.AsyncClient(timeout=30) as client:
            r = await client.post(url, headers=headers, json=body)
            r.raise_for_status()
            data = r.json()
            text = data["choices"][0]["message"]["content"]
            return text.strip()
    except Exception:
        return None

# ---------- Routes ----------
@router.post("/summary", response_model=Envelope[SummaryOut])
async def summarize_tasks(payload: SummaryIn):
    tasks = payload.tasks

    # --- 1) Basic Metrics ---
    total = len(tasks)
    per_cat: Dict[str, Dict[str, Any]] = {}  # {cat: {...}}
    overall = {"on_time": 0, "early": 0, "late": 0,
               "avg_early_samples": [], "avg_late_samples": []}

    for t in tasks:
        cat = (t.category or "Uncategorized").strip()
        if cat not in per_cat:
            # ⚠️ 保持 key 命名一致：early_samples / late_samples
            per_cat[cat] = {
                "total": 0, "on_time": 0, "early": 0, "late": 0,
                "early_samples": [], "late_samples": []
            }
        c = per_cat[cat]
        c["total"] += 1

        # ---- 关键：下面的推断必须在 for 循环内部 ----
        status = (t.status or "").lower()
        if status == "completed":
            # 若有 due 日期，则比较完成时间 vs due
            due = t.dueDateTime or _to_date(t.dueDate)
            comp = t.completedAt or datetime.utcnow()
            if due:
                diff = _minutes_diff(comp, due)  # +晚 -早
                if diff < -1:
                    c["early"] += 1
                    overall["early"] += 1
                    c["early_samples"].append(abs(diff))
                    overall["avg_early_samples"].append(abs(diff))
                elif diff <= 30:
                    c["on_time"] += 1
                    overall["on_time"] += 1
                else:
                    c["late"] += 1
                    overall["late"] += 1
                    c["late_samples"].append(diff)
                    overall["avg_late_samples"].append(diff)
            else:
                # 没有 due 的视为按时
                c["on_time"] += 1
                overall["on_time"] += 1

        elif status == "late":
            c["late"] += 1
            overall["late"] += 1
        else:
            # notStarted / inProgress / archived -> 不计入完成率
            pass

    # --- 汇总率 ---
    overall_out = {
        "on_time_rate": (overall["on_time"] / total) if total else 0.0,
        "early_rate": (overall["early"] / total) if total else 0.0,
        "late_rate": (overall["late"] / total) if total else 0.0,
        "avg_early_minutes": _avg(overall["avg_early_samples"]),
        "avg_late_minutes": _avg(overall["avg_late_samples"]),
    }

    cat_out: Dict[str, Any] = {}
    for k, v in per_cat.items():
        n = v["total"] or 1
        cat_out[k] = {
            "total": v["total"],
            "on_time_rate": v["on_time"] / n,
            "early_rate": v["early"] / n,
            "late_rate": v["late"] / n,
            "avg_early_minutes": _avg(v["early_samples"]),
            "avg_late_minutes": _avg(v["late_samples"]),
        }

    # --- 排序 ---
    top_late = sorted(cat_out.items(), key=lambda x: x[1]["late_rate"], reverse=True)
    top_early = sorted(cat_out.items(), key=lambda x: x[1]["early_rate"], reverse=True)

    metrics = {
        "user_id": payload.user_id,
        "total_tasks": total,
        "overall": overall_out,
        "by_category": cat_out,
        "top_late_categories": [k for k, _v in top_late if _v["late_rate"] > 0][:5],
        "top_early_categories": [k for k, _v in top_early if _v["early_rate"] > 0][:5],
    }

    # --- 2) 生成 summary 文本 ---
    llm_text = await _maybe_llm_enhance(metrics)
    summary = llm_text or _heuristic_summarize(metrics)

    return ok(SummaryOut(summary=summary, metrics=metrics))
