# dodotask-back
Backend
# DoDoTask — Tasks + Virtual Companion

A task management application that integrates a virtual companion to help you get things done!  
It features a fully customizable companion (voice, personality, appearance) that organizes your activities and reminds you with **voiced reminders**. Your companion’s emotion changes based on how many tasks you’ve completed—sad when nothing’s done, and happier as progress grows. Includes a **focus timer**, and social features like **friend interactions**, **group tasks**, and a **spur/encourage** mechanic.

> Frontend: Flutter (GetX + Dio) • Backend: FastAPI (MongoDB via Beanie/Motor)

---

## ✨ Key Features

- **Virtual Companion**
  - Customizable look, voice & personality
  - Emotion reacts to your productivity (not started → in progress → completed)
  - Pet chat and lightweight celebrations

- **Task Management**
  - Create/update tasks with priority, category, due date/time
  - Status buckets: Not Started / In Progress / Completed / Late
  - Subtasks (planned), reminders (minute/hour/daily)

- **Focus & Reminders**
  - Built-in **focus timer**
  - **Voiced reminders** (TTS)

- **Analytics**
  - Dashboard with historical charts
  - Filters by duration & category
  - AI summary (which categories tend to delay, strengths/weaknesses)

- **Social**
  - Interact with friends & their companions
  - Group tasks and spur/encourage others

---

## 📁 Monorepo Layout

dodotask-back/
├─ fastapi/
│ └─ app/
│ ├─ logic/ # server-side business logic
│ ├─ models/ # Pydantic/Beanie models
│ ├─ routers/ # FastAPI routers (auth, ai, tasks, wellbeing, etc.)
│ ├─ schemas/ # request/response schemas
│ ├─ services/ # service layer (auth_service, pet_ai, ...)
│ └─ utils/ # config/db/deps helpers
└─ flutter/
└─ lib/
├─ api/ # Dio client, API defs, models
├─ binding/ # GetX bindings
├─ controller/ # TaskController, PetController, Auth, etc.
├─ models/ # task.dart, etc.
├─ route/ # GetX pages
├─ screens/ # dashboard, add_update_task, pet_chat_screen, ...
├─ services/ # TTS/notification/celebration
├─ storage/ # authStorage
└─ widgets/ # pet_header, task_list_tile, etc.

yaml
复制代码

---

## 🚀 Getting Started

### 1) Backend (FastAPI)

**Requirements**
- Python 3.11+
- MongoDB (Atlas or local)
- (Recommended) virtualenv

**Setup**
```bash
cd fastapi
python -m venv .venv && . .venv/Scripts/activate  # Windows
# source .venv/bin/activate                        # macOS/Linux

pip install -r requirement.txt
Create a .env in fastapi/:

env
复制代码
MONGODB_URI="mongodb+srv://<user>:<pass>@<cluster>/<db>?retryWrites=true&w=majority"
JWT_SECRET="<long-random-secret>"
JWT_ALGORITHM="HS256"
Run:

bash
复制代码
uvicorn app.main:app --reload --port 8000
API will be at http://127.0.0.1:8000 (adjust in Flutter if needed).

2) Frontend (Flutter)
Requirements

Flutter 3.x

Android/iOS toolchains

Setup

bash
复制代码
cd flutter
flutter pub get
Point the app to your backend in lib/api/dioclient.dart:

dart
复制代码
BaseOptions(
  baseUrl: "http://127.0.0.1:8000", // or your ngrok/hosted URL
)
Run:

bash
复制代码
flutter run
🧠 Tech Stack
Flutter (GetX, Dio)

FastAPI (Pydantic v2, Beanie/Motor for MongoDB)

Auth: JWT

Notifications/TTS: platform services (e.g., flutter_tts, local notifications)

🔌 Example Endpoints (backend)
POST /auth/register, POST /auth/login

GET /tasks, POST /tasks, PATCH /tasks/{id}, DELETE /tasks/{id}

POST /pet_ai/summary (companion/analytics)

GET /health_productivity/metrics, GET /wellbeing/today

(Exact routes may evolve; see /docs when running the server.)

🗺️ Roadmap
 Subtasks UI/UX

 Cross-device sync & push notifications

 Advanced analytics & recommendations

 Rich companion animations/skins

 Group task workflows & chat

 Public demo deployment

🤝 Contributing
Issues and PRs are welcome! Please open an issue to discuss major changes first.
IFs to the README,
- or script the Flutter app/bundle rename?  
Say the word and I’ll pop those in 💪
