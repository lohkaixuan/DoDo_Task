# =============================
# app/services/pet_ai.py
# =============================
from __future__ import annotations
import os
from typing import Optional, Dict, Any
from httpx import AsyncClient, Timeout


class HuggingFaceClient:
    """Lightweight wrapper around Hugging Face Inference API.
    - Text gen (small model default)
    - Sentiment analysis
    - Image captioning
    """
    def __init__(self, api_key: Optional[str] = None, base_url: str = "https://api-inference.huggingface.co"):
        self.api_key = api_key or os.getenv("HF_API_KEY")
        self.base_url = base_url.rstrip("/")

    async def _post_json(self, model: str, payload: Dict[str, Any]):
        headers = {"Authorization": f"Bearer {self.api_key}"} if self.api_key else {}
        async with AsyncClient(timeout=Timeout(30.0)) as client:
            r = await client.post(f"{self.base_url}/models/{model}", headers=headers, json=payload)
            r.raise_for_status()
            return r.json()

    async def _post_binary(self, model: str, data: bytes, content_type: str = "application/octet-stream"):
        headers = {"Content-Type": content_type}
        if self.api_key:
            headers["Authorization"] = f"Bearer {self.api_key}"
        async with AsyncClient(timeout=Timeout(60.0)) as client:
            r = await client.post(f"{self.base_url}/models/{model}", headers=headers, content=data)
            r.raise_for_status()
            return r.json()

    async def analyze_sentiment(self, text: str, model: str = "distilbert-base-uncased-finetuned-sst-2-english") -> Dict[str, Any]:
        out = await self._post_json(model, {"inputs": text})
        # Normalize a few response shapes HF might return
        cand = None
        if isinstance(out, list):
            cand = out[0] if out else None
            if isinstance(cand, list):
                cand = cand[0] if cand else None
        if isinstance(out, dict):
            cand = out
        if not cand:
            return {"label": "neutral", "score": 0.5}
        label = cand.get("label", "neutral")
        score = float(cand.get("score", 0.5))
        return {"label": label, "score": score}

    async def caption_image(self, image_bytes: bytes, model: str = "Salesforce/blip-image-captioning-base") -> str:
        out = await self._post_binary(model, image_bytes)
        if isinstance(out, list) and out and isinstance(out[0], dict) and "generated_text" in out[0]:
            return out[0]["generated_text"]
        if isinstance(out, dict) and "generated_text" in out:
            return out["generated_text"]
        return str(out)

    async def generate_reply(
        self,
        prompt: str,
        model: str = "google/flan-t5-base",
        max_new_tokens: int = 256,
        temperature: float = 0.7,
    ) -> str:
        payload = {
            "inputs": prompt,
            "parameters": {"max_new_tokens": max_new_tokens, "temperature": temperature},
            "options": {"wait_for_model": True},
        }
        out = await self._post_json(model, payload)
        if isinstance(out, list) and out and isinstance(out[0], dict) and "generated_text" in out[0]:
            return out[0]["generated_text"]
        if isinstance(out, dict) and "generated_text" in out:
            return out["generated_text"]
        return str(out)


class InworldClient:
    """
    Minimal HTTP proxy client for Inworld.

    Run a tiny Node/TS proxy using Inworld's official SDK that exposes a POST /chat endpoint:
    - Request:  { characterId, userId, text, context }
    - Response: { reply }

    Then set INWORLD_PROXY_URL to that proxy. If not set, we'll fall back to HuggingFace text gen.
    """

    def __init__(self, base_url: Optional[str] = None, api_key: Optional[str] = None):
        self.base_url = (base_url or os.getenv("INWORLD_PROXY_URL", "")).rstrip("/")
        self.api_key = api_key or os.getenv("INWORLD_API_KEY")

    async def chat(self, character_id: str, user_id: str, text: str, context: dict | None = None) -> str:
        if not self.base_url:
            raise RuntimeError("INWORLD_PROXY_URL not set")
        headers = {"Content-Type": "application/json"}
        if self.api_key:
            headers["Authorization"] = f"Bearer {self.api_key}"
        payload = {"characterId": character_id, "userId": user_id, "text": text, "context": context or {}}
        async with AsyncClient(timeout=Timeout(30.0)) as client:
            r = await client.post(f"{self.base_url}/chat", headers=headers, json=payload)
            r.raise_for_status()
            data = r.json()
            return data.get("reply", "")



# =============================
# HOW TO WIRE
# =============================
# 1) Save both sections as two files:
#    - app/services/pet_ai.py
#    - app/routers/pet_ai.py
# 2) In app/main.py (or wherever you build FastAPI), add:
#       from app.routers.pet_ai import router as pet_ai_router
#       app.include_router(pet_ai_router)
# 3) Env vars (.env):
#       HF_API_KEY=...                # optional for free/public endpoints
#       INWORLD_PROXY_URL=http://localhost:8080  # your Node proxy for Inworld
#       INWORLD_CHARACTER_ID=your-character-id   # from Inworld Studio
#       INWORLD_API_KEY=optional-shared-secret   # if your proxy requires it
# 4) Quick tests (PowerShell/curl):
#       curl -X POST http://127.0.0.1:8000/ai/pet/analyze/sentiment -H "Content-Type: application/json" -d '{"text":"today I'm tired but motivated"}'
#       curl -X POST http://127.0.0.1:8000/ai/pet/chat -H "Content-Type: application/json" -d '{"user_id":"u1","text":"I skipped study.","use_inworld":false}'
