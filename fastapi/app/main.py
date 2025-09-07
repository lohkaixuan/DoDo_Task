from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from fastapi.exceptions import RequestValidationError
from dotenv import load_dotenv
load_dotenv(override=True)


from .db import init_db
from app.routers.pet_ai import router as pet_ai_router
from .routers import tasks, wellbeing, ai, auth, health_productivity
from .schemas.response import Envelope
app = FastAPI(
    title="DoDoTask Backend", 
    version="0.1.0",
    docs_url="/docs",
    redoc_url="/redoc",
    )

# Global exception handlers
@app.exception_handler(HTTPException)
async def http_exc_handler(_: Request, exc: HTTPException):
    return JSONResponse(
        status_code=exc.status_code,
        content=Envelope(status=exc.status_code, message=str(exc.detail), data=None).model_dump(),
    )

@app.exception_handler(RequestValidationError)
async def validation_exc_handler(_: Request, exc: RequestValidationError):
    return JSONResponse(
        status_code=422,
        content=Envelope(status=422, message="Validation error", data=exc.errors()).model_dump(),
    )

# ---CORS---
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

app.include_router(pet_ai_router)
app.include_router(tasks.router)      # NEW: create/complete tasks (+event logs)
app.include_router(wellbeing.router)  # your analytics & risk endpoints
app.include_router(ai.router)         # chat with AI
app.include_router(auth.router)         # chat with AI
app.include_router(health_productivity.router)  # health and productivity endpoints
@app.get("/")
async def root():
    return {"message": "Backend is alive 🎉"}
