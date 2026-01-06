# ==================================================
# Program Name   : pet_service_ai.py
# Purpose        : Provide AI-based virtual pet intelligence services, including sentiment analysis, AI chat response generation,
#                  and safe fallback handling for external AI API failures.
# Developer      : Miss. Yap Shuet Khey
# Student ID     : TP074066
# Course         : Bachelor of Software Engineering (Hons)
# Created Date   : 25 August 2025
# Last Modified  : 15 December 2025
# ==================================================

import os
import json
import httpx
from typing import Optional

from vaderSentiment.vaderSentiment import SentimentIntensityAnalyzer


class GroqClient:
    """
    Groq (OpenAI-compatible) chat completions client.
    - Returns safe fallback text on any HTTP failure (including 401),
      so your ASGI app will not crash on Render.
    """

    def __init__(self):
        self.api_key = os.getenv("GROQ_API_KEY", "").strip()
        self.model = os.getenv("GROQ_MODEL", "llama-3.1-70b-versatile").strip()
        self.base_url = os.getenv("GROQ_BASE_URL", "https://api.groq.com/openai/v1").strip()

        # sentiment (optional, but nice for pet mood)
        self._sentiment = SentimentIntensityAnalyzer()

    def analyze_sentiment(self, text: str) -> str:
        score = self._sentiment.polarity_scores(text)["compound"]
        if score >= 0.5:
            return "positive"
        elif score <= -0.5:
            return "negative"
        return "neutral"

    def _fallback(self, reason: str) -> str:
        # keep it cute-ish but safe for production logs
        return f"Oops... I can't reach my brain right now ({reason}). Try again in a moment!"

    async def generate_reply(
        self,
        user_prompt: str,
        *,
        system_prompt: Optional[str] = None,
        temperature: float = 0.8,
        max_tokens: int = 220,
    ) -> str:
        # If key missing, never call network
        if not self.api_key:
            return self._fallback("missing GROQ_API_KEY")

        sys = system_prompt or (
            "You are a cute, playful virtual pet assistant. "
            "Keep replies short, warm, and encouraging. "
            "If user asks for unsafe content, refuse briefly."
        )

        payload = {
            "model": self.model,
            "messages": [
                {"role": "system", "content": sys},
                {"role": "user", "content": user_prompt},
            ],
            "temperature": float(temperature),
            "max_tokens": int(max_tokens),
        }

        headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json",
        }

        url = f"{self.base_url}/chat/completions"

        try:
            async with httpx.AsyncClient(timeout=30.0) as client:
                r = await client.post(url, headers=headers, json=payload)

                # Handle auth errors gracefully (the one that killed Render)
                if r.status_code in (401, 403):
                    return self._fallback("invalid GROQ_API_KEY")

                r.raise_for_status()
                data = r.json()

            return (
                data.get("choices", [{}])[0]
                    .get("message", {})
                    .get("content", "")
                    .strip()
                or self._fallback("empty reply")
            )

        except httpx.HTTPStatusError as e:
            # non-auth HTTP errors (429/5xx/etc)
            code = getattr(e.response, "status_code", "unknown")
            return self._fallback(f"http {code}")

        except Exception as e:
            # any unexpected crash
            return self._fallback(f"error {type(e).__name__}")


# Backward-compatible alias (so you don't need to rewrite pet_ai.py imports)
HuggingFaceClient = GroqClient
