# app/routers/tts.py
import io
import edge_tts
from fastapi import APIRouter, HTTPException , Query
from fastapi.responses import StreamingResponse
from pydantic import BaseModel, Field

router = APIRouter(prefix="/tts", tags=["tts"])

# Cute defaults
DEFAULT_VOICE_EN = "en-US-AnaNeural"
DEFAULT_VOICE_ZH = "zh-CN-XiaoxiaoNeural"

class TtsReq(BaseModel):
    text: str = Field(..., min_length=1, max_length=400)  # protect server
    voice: str | None = None  # optional override

def pick_voice(text: str, voice: str | None):
    if voice:
        return voice
    # super simple language guess
    return DEFAULT_VOICE_ZH if any("\u4e00" <= ch <= "\u9fff" for ch in text) else DEFAULT_VOICE_EN

@router.get("/speak")
async def speak_get(text: str = Query(..., min_length=1, max_length=400), voice: str | None = None):
    req = TtsReq(text=text, voice=voice)
    return await speak(req)

@router.post("/speak")
async def speak(req: TtsReq):
    text = req.text.strip()
    if not text:
        raise HTTPException(status_code=400, detail="Text is empty")

    voice = pick_voice(text, req.voice)

    # Generate audio to memory (no disk)
    communicate = edge_tts.Communicate(text, voice)
    audio_stream = io.BytesIO()

    try:
        async for chunk in communicate.stream():
            if chunk["type"] == "audio":
                audio_stream.write(chunk["data"])
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"TTS failed: {e}")

    audio_stream.seek(0)
    return StreamingResponse(
        audio_stream,
        media_type="audio/mpeg",
        headers={
            "Cache-Control": "no-store",
            "X-Voice": voice,
        },
    )