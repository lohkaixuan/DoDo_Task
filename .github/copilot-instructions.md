# DoDoTask AI Coding Guidelines

## Architecture Overview
- **Monorepo**: FastAPI backend (`fastapi/`) + Flutter frontend (`flutter/`)
- **Backend**: Async FastAPI with Beanie/Motor (MongoDB ODM), JWT auth, routers for tasks/AI/wellbeing
- **Frontend**: Flutter with GetX state management, Dio HTTP client, platform services (TTS, notifications)
- **Data Flow**: Flutter generates UUIDs (`flutter_id`), syncs tasks/auth via REST APIs; AI pet chat uses HuggingFace/Inworld/Groq
- **Key Models**: `Task` (with subtasks, enums: `TaskStatus.notStarted/inProgress/completed/late`), `User` (email auth)

## Critical Workflows
- **Backend Setup**: `cd fastapi; python -m venv .venv; .\.venv\Scripts\Activate.ps1; pip install -r requirement.txt; uvicorn app.main:app --reload --port 8000`
- **Frontend Setup**: `cd flutter; flutter pub get; flutter run`
- **API Docs**: Visit `http://127.0.0.1:8000/docs` for Swagger; endpoints like `POST /tasks`, `POST /auth/login`
- **Debugging**: Use `flutter logs` for mobile; backend logs via uvicorn; check MongoDB Atlas for data

## Project Conventions
- **Enums**: Define matching enums in Python (`models/models.py`) and Dart (`models/task.dart`) for `TaskStatus`, `PriorityLevel`, etc.
- **User Context**: Hardcode `user_email: "yap@gmail.com"` in controllers until auth integration (e.g., `taskController.dart:37`)
- **Error Handling**: Use `Envelope` schema for responses; catch `DioException` in Flutter for sync failures
- **AI Integration**: Pet chat via `/ai/pet/chat`; sentiment analysis with Vader; fallback to Groq if Inworld fails
- **Notifications**: Schedule via `NotificationService` in `TaskController.addTask()`; payload includes `taskId` for focus screen navigation

## Integration Patterns
- **Sync Logic**: In `TaskController`, local updates trigger cloud sync (e.g., `addTask()` posts to `/tasks` with `flutter_id`)
- **Pet Reactions**: `PetController` reacts to task status changes (e.g., sad on not started, happy on completed)
- **Cross-Platform**: Use `flutter_secure_storage` for tokens; `flutter_tts` for voiced reminders; `just_audio` for sounds

## Examples
- **Task Creation**: `TaskController.addTask()` → `dio.post('/tasks', data: {... 'flutter_id': t.id, 'user_email': 'yap@gmail.com'})`
- **AI Chat**: `POST /ai/pet/chat` with persona prompt including mood/risk scores from `compute_stress_score()`
- **Router Pattern**: `fastapi/app/routers/tasks.py` uses `Task.find(Task.user_email == user_email)` for queries</content>
<parameter name="filePath">c:\Users\Khey\Documents\GitHub\DoDo_Task\.github\copilot-instructions.md