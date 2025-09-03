# app/services/pet_ai.py
from __future__ import annotations
import os, httpx, base64
from typing import Any, Dict, Optional
from dotenv import load_dotenv
from vaderSentiment.vaderSentiment import SentimentIntensityAnalyzer

load_dotenv(override=True)

# --- 本地情绪分析器 ---
_vader = SentimentIntensityAnalyzer()

# --- Groq 配置 ---
GROQ_API_KEY = (os.getenv("GROQ_API_KEY") or "").strip()
GROQ_URL = "https://api.groq.com/openai/v1/chat/completions"


class HuggingFaceClient:
    """
    现在不再调用 Hugging Face Inference API：
    - analyze_sentiment 用本地 VADER
    - generate_reply 用 Groq（免费、低延迟）
    """
    def __init__(self):
        pass

    async def analyze_sentiment(self, text: str) -> Dict[str, Any]:
        s = _vader.polarity_scores(text)
        comp = s["compound"]
        if comp >= 0.05:
            return {"label": "POSITIVE", "score": float(comp)}
        elif comp <= -0.05:
            return {"label": "NEGATIVE", "score": float(-comp)}
        else:
            return {"label": "NEUTRAL", "score": float(abs(comp))}

    async def generate_reply(self, prompt: str) -> str:
        if not GROQ_API_KEY:
            # 没有 Groq Key 的兜底
            return "I’m here with you. Let’s take a tiny step together. 🌟"

        headers = {"Authorization": f"Bearer {GROQ_API_KEY}", "Content-Type": "application/json"}
        body = {
            "model": "llama-3.1-8b-instant",
            "messages": [{"role": "user", "content": prompt}],
            "temperature": 0.8,
            "max_tokens": 160
        }
        async with httpx.AsyncClient(timeout=40) as c:
            r = await c.post(GROQ_URL, headers=headers, json=body)
            r.raise_for_status()
            data = r.json()
            return data["choices"][0]["message"]["content"].strip()


# --- Inworld（可选：等你搭代理后再启用） ---
INWORLD_PROXY_URL = (os.getenv("INWORLD_PROXY_URL") or "").rstrip("/")
INWORLD_API_KEY   = (os.getenv("INWORLD_API_KEY") or "").strip()

class InworldClient:
    def __init__(self, base_url: Optional[str] = None, api_key: Optional[str] = None):
        self.base_url = (base_url or INWORLD_PROXY_URL).rstrip("/")
        self.api_key  = api_key or INWORLD_API_KEY

    async def chat(self, character_id: str, user_id: str, text: str, context: dict | None = None) -> str:
        if not self.base_url:
            raise RuntimeError("INWORLD_PROXY_URL havent use（use_inworld=false run Groq first）")
        headers = {"Content-Type": "application/json"}
        if self.api_key:
            headers["Authorization"] = f"Bearer {self.api_key}"
        payload = {"characterId": character_id, "userId": user_id, "text": text, "context": context or {}}
        async with httpx.AsyncClient(timeout=40) as c:
            r = await c.post(f"{self.base_url}/chat", headers=headers, json=payload)
            r.raise_for_status()
            data = r.json()
            return str(data.get("reply") or r.text)
