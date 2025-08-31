from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from .db import init_db
from .routers import auth

app = FastAPI(title="DoDoTask Backend")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # tighten later
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.on_event("startup")
async def _startup():
    await init_db()

app.include_router(auth.router)

@app.get("/")
async def root():
    return {"message": "Backend is alive 🎉"}
