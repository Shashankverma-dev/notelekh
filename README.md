# Notelekh 🖋️✨

> **Modern Collaborative Note-taking & Infinite Canvas Studio**  
> *Crafted for thinkers, creators, and students — combining fluid handwriting, infinite canvas, and AI-assisted note-taking.*

[![Live Demo](https://img.shields.io/badge/Demo-notelekh.web.app-4285F4?style=flat-square&logo=google-chrome&logoColor=white)](https://notelekh.web.app)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=flat-square&logo=flutter&logoColor=white)](https://flutter.dev)
[![FastAPI](https://img.shields.io/badge/FastAPI-Python-009688?style=flat-square&logo=fastapi&logoColor=white)](https://fastapi.tiangolo.com)
[![Firebase](https://img.shields.io/badge/Firebase-Hosting%20%7C%20Auth%20%7C%20Firestore-FFCA28?style=flat-square&logo=firebase&logoColor=black)](https://firebase.google.com)

---

## 🌟 Key Highlights

- **Infinite Canvas & Paginated Notebooks**: Switch seamlessly between boundless whiteboards, standard A4 paginated notebooks (ruled, dotted, grid, blank), and rich text/markdown documents.
- **GoodNotes-Inspired Vector Inking Engine**:
  - Fountain Pen, Ballpoint Pen, Brush Pen, Pencil, and Highlighter.
  - Realistic pressure dynamics, velocity smoothing, and stroke interpolation.
  - Draw-and-hold automatic shape recognition (rectangles, ellipses, triangles, straight lines).
- **Lasso & Object Manipulation**: Select, transform, colorize, resize, and rearrange vector strokes, text items, and shapes.
- **PDF Study Viewer**: Load, view, annotate, and take split-pane notes on PDF documents with margin inking.
- **Cloud Sync & Offline-First**: Powered by Firebase Auth and Firestore with automatic local storage caching.
- **Responsive Workspace**: Adaptive desktop, tablet, and mobile shell with collapsible sidebar, context panel, quick search, and notification center.

---

## 📁 Repository Structure

```text
notes app/
├── apps/
│   ├── client/                  # Flutter Web & Mobile Frontend
│   │   ├── lib/
│   │   │   ├── core/            # Models, themes, networking, services
│   │   │   ├── features/        # Auth, Canvas, Dashboard, Files, Search, Studio
│   │   │   ├── state/           # Central AppState (Provider / ChangeNotifier)
│   │   │   └── main.dart        # Flutter entry point
│   │   ├── test/                # Unit, widget, and integration tests
│   │   └── web/                 # Web template, icons, manifest
│   │
│   └── backend/                 # FastAPI Python Backend
│       ├── app/
│       │   ├── api/             # API v1 routes & endpoints
│       │   ├── core/            # Config, security, database session
│       │   ├── models/          # SQLAlchemy ORM models
│       │   ├── schemas/         # Pydantic validation schemas
│       │   └── services/        # AI & workspace services
│       ├── tests/               # Backend pytest suite
│       └── requirements.txt     # Python dependencies
│
├── .firebaserc                  # Firebase project configuration
├── firebase.json                # Firebase Hosting rewrites & headers
├── .gitignore                   # Unified monorepo ignore rules
└── README.md                    # Project documentation
```

---

## 🚀 Getting Started

### 1. Flutter Client

#### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (`>= 3.24.0`)
- Google Chrome (for web testing)

#### Run Locally
```bash
cd apps/client
flutter pub get
flutter run -d chrome
```

#### Run Unit Tests
```bash
cd apps/client
flutter test
```

#### Build for Production
```bash
cd apps/client
flutter build web --release
```

---

### 2. Python Backend

#### Prerequisites
- Python 3.10+
- `pip` or `uv`

#### Setup & Run
```bash
cd apps/backend
python -m venv venv

# Windows
.\venv\Scripts\activate

# macOS / Linux
source venv/bin/activate

pip install -r requirements.txt
uvicorn app.main:app --reload --port 8000
```

API docs will be available at `http://localhost:8000/docs`.

---

### 3. Deploying to Firebase

The root `firebase.json` is configured to deploy the client web release bundle:

```bash
# 1. Build client web release
cd apps/client
flutter build web --release

# 2. Deploy hosting from project root
cd ../..
firebase deploy --only hosting
```

Live URL: **[https://notelekh.web.app](https://notelekh.web.app)**

---

## 🛡️ License

This project is proprietary and developed by **Shashank Verma** (`Shashankverma-dev`). All rights reserved.
