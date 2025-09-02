# app/main.py
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from .db import init_db
from .routers import tasks, wellbeing, ai  # add your package __init__ if needed

app = FastAPI(title="DoDoTask Backend")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.on_event("startup")
async def _startup():
    await init_db()

app.include_router(tasks.router)      # NEW: create/complete tasks (+event logs)
app.include_router(wellbeing.router)  # your analytics & risk endpoints
app.include_router(ai.router)         # chat with AI

@app.get("/")
async def root():
    return {"message": "Backend is alive 🎉"}
