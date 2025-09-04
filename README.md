# DoDoTask — Tasks + Virtual Companion

A task management application that integrates a virtual companion to help you get things done!  
Your companion is fully customizable (voice, personality, appearance) and gives **voiced reminders**. Emotions change with your progress—sad when nothing’s done, happier as you complete tasks. Includes a **focus timer** and social features like **friend interactions**, **group tasks**, and a **spur/encourage** mechanic.

[![Flutter](https://img.shields.io/badge/Flutter-3.x-blue)](https://flutter.dev)
[![FastAPI](https://img.shields.io/badge/FastAPI-0.115+-teal)](https://fastapi.tiangolo.com)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](#-license)

---

## ✨ Features

- **Virtual Companion**
  - Customizable look, voice & personality
  - Emotion reacts to task status (not started → in progress → completed)
  - Pet chat & lightweight celebrations

- **Task Management**
  - Tasks with priority, category, due date/time
  - Buckets: Not Started / In Progress / Completed / Late
  - Reminders: minute / hour / daily (guardian alert planned)
  - Subtasks (planned)

- **Focus & Reminders**
  - Built-in **focus timer**
  - **Voiced reminders** (TTS)

- **Analytics**
  - Dashboard with historical charts
  - Filter by duration & category
  - AI summary of strengths/weaknesses (which categories tend to delay, etc.)

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
│ ├─ routers/ # auth, ai, tasks, wellbeing, etc.
│ ├─ schemas/ # request/response DTOs
│ ├─ services/ # auth_service, pet_ai, ...
│ └─ utils/ # config, db, deps
└─ flutter/
└─ lib/
├─ api/ # Dio client, API definitions, models
├─ binding/ # GetX bindings
├─ controller/ # TaskController, PetController, Auth, ...
├─ models/ # task.dart, etc.
├─ route/ # GetX pages
├─ screens/ # dashboard, add_update_task, pet_chat_screen, ...
├─ services/ # TTS, notifications, celebration
├─ storage/ # authStorage
└─ widgets/ # pet_header, task_list_tile, ...

yaml
复制代码

---

## 🚀 Getting Started

### Backend (FastAPI)

**Requirements**
- Python 3.11+
- MongoDB (Atlas or local)

**Setup**
```bash
cd fastapi
python -m venv .venv && . .venv/Scripts/activate  # Windows
# source .venv/bin/activate                        # macOS/Linux

pip install -r requirement.txt
Create .env in fastapi/:

env
复制代码
MONGODB_URI="mongodb+srv://<user>:<pass>@<cluster>/<db>?retryWrites=true&w=majority"
JWT_SECRET="<long-random-secret>"
JWT_ALGORITHM="HS256"
Run the API:

bash
复制代码
uvicorn app.main:app --reload --port 8000
Open http://127.0.0.1:8000/docs for Swagger.

Frontend (Flutter)
Requirements

Flutter 3.x

Android/iOS toolchains

Setup

bash
复制代码
cd flutter
flutter pub get
Set your backend URL in lib/api/dioclient.dart:

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

🔌 Example Endpoints
POST /auth/register — create account

POST /auth/login — get JWT

GET /tasks / POST /tasks / PATCH /tasks/{id} / DELETE /tasks/{id}

POST /pet_ai/summary — companion insights

GET /health_productivity/metrics — productivity stats

GET /wellbeing/today — wellbeing snapshot

(See interactive docs at /docs.)

🗺️ Roadmap
 Subtasks UI/UX

 Push notifications & cross-device sync

 Advanced analytics & recommendations

 Rich companion animations/skins

 Group-task workflows & chat

 Public demo deployment

🤝 Contributing
PRs welcome! For major changes, open an issue first.

📄 License
MIT

markdown
复制代码

want me to also:
- add shields for CI/build/test coverage,
- drop in screenshot/GIF sections,
- or rename the **Flutter app display name** & **Android/iOS bundle IDs** to match `DoDo_Task`?  
say the word and I’ll prep exact commands/files 🧰