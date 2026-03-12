# Smart Pantry

A cross-platform app to manage your pantry, get recipe suggestions based on what you have, and add items by scanning receipts, barcodes, or manual entry.

## Features

- **Dashboard** – Overview of pantry count, recipe suggestions, and items expiring soon (with date/time and “Expired” state)
- **Recipe suggestions** – Recipes matched to your pantry; filter by Fast, Vegetarian, Most ingredients
- **Recipe details** – AI-generated cooking steps, tips, time, and difficulty; match percentage and tags
- **Add to pantry**
  - **Scan receipt** – Take a photo or pick an image (web: file picker); backend OCR (Gemini vision) extracts items
  - **Scan barcode** – Camera barcode scan (iOS/Android); product name from Open Food Facts
  - **Manually add item** – Form with item name, category, and optional expiry date & time picker
  - **Paste receipt text** – Paste raw OCR text to extract and add items
- **Expiring soon** – List shows multiple items with expiry date/time; “Today”, “1 day left”, or “Expired” (red) when past
- **Themed UI** – Teal and cream theme, no white cards; native splash screen

## Tech Stack

| Layer    | Stack |
|----------|--------|
| **Frontend** | Flutter (Dart), Riverpod, Dio, Hive, intl, image_picker, mobile_scanner, flutter_native_splash |
| **Backend**  | FastAPI, Python 3.x, SQLAlchemy (async), SQLite / PostgreSQL, Gemini 1.5 Flash, Spoonacular API |

## Project structure

```
Smart-Pantry/
├── frontend/          # Flutter app (iOS, Android, Web)
│   ├── lib/
│   │   ├── core/      # Colors, theme
│   │   ├── models/
│   │   ├── providers/
│   │   ├── screens/
│   │   └── widgets/
│   └── pubspec.yaml
├── backend/           # FastAPI API
│   ├── main.py
│   ├── .env          # Config (not committed; use .env.example)
│   └── requirements.txt
└── README.md
```

## Prerequisites

- **Flutter** SDK (for frontend)
- **Python 3.10+** and **pip** (for backend)
- **API keys**: Gemini (Google AI), Spoonacular (recipes). Optional for demo: backend can run in `ENVIRONMENT=demo` with local data.

## Quick start

### 1. Backend

```bash
cd backend
python -m venv .venv
# Windows:
.venv\Scripts\activate
# macOS/Linux:
# source .venv/bin/activate

pip install -r requirements.txt
cp .env.example .env
# Edit .env and set DATABASE_URL, GEMINI_API_KEY, SPOONACULAR_API_KEY (or use demo mode).

uvicorn main:app --reload --port 8100
```

API base: **http://localhost:8100**

### 2. Frontend

```bash
cd frontend
flutter pub get
flutter run -d chrome   # Web
# Or: flutter run -d windows  /  flutter run  (for device selection)
```

The app uses `http://localhost:8100` as the default API URL. For a different host/port, run with:

```bash
flutter run -d chrome --dart-define=API_BASE_URL=http://your-api-url
```

### 3. Optional: native splash

Splash screen is already generated (cream background). To change it, edit the `flutter_native_splash` section in `frontend/pubspec.yaml`, then:

```bash
cd frontend
dart run flutter_native_splash:create
```

## Backend environment variables

| Variable | Required | Description |
|----------|----------|-------------|
| `DATABASE_URL` | Yes | e.g. `sqlite+aiosqlite:///./smart_pantry.db` or PostgreSQL URL |
| `GEMINI_API_KEY` | Yes | Google AI (Gemini) API key for receipt OCR and AI steps |
| `SPOONACULAR_API_KEY` | Yes* | Spoonacular API key for recipe search (*not needed if `ENVIRONMENT=demo`) |
| `ENVIRONMENT` | No | `development` (default) or `demo` to use local demo recipes and skip Spoonacular |

See `backend/.env.example` for a template.

## Production deployment (overview)

For a real deployment:

- **Backend**
  - Use a production database (e.g. managed PostgreSQL) and set `DATABASE_URL` accordingly.
  - Set `ENVIRONMENT=development` (or `production`) so demo recipes are disabled and real Spoonacular data is used.
  - Run with a robust ASGI server stack, e.g.:
    - `uvicorn main:app --host 0.0.0.0 --port 8100 --workers 4` behind Nginx or a cloud load balancer.
  - Keep `.env` **out of version control** and configure secrets via your hosting platform’s env vars.

- **Frontend**
  - Build release artifacts targeting your platform:
    - Web: `flutter build web --dart-define=API_BASE_URL=https://your-api-host`
    - Android: `flutter build apk --dart-define=API_BASE_URL=https://your-api-host`
    - iOS: `flutter build ipa --dart-define=API_BASE_URL=https://your-api-host`
  - Serve the built web assets (`frontend/build/web`) from a static host (e.g. Firebase Hosting, Vercel, S3+CloudFront).
  - Ensure CORS on the backend allows your production web origin (set `ALLOWED_ORIGINS` in `.env`).

## Running on mobile

- **iOS**: `flutter run` and select the simulator or device. Camera and barcode scanning require a real device or simulator with camera.
- **Android**: Same; ensure camera permission is allowed for receipt and barcode scan.

On **web**, “Scan receipt” uses the file picker; “Scan barcode” shows a message to use the app on a phone.

## License

Private / educational use. Ensure API keys and `.env` are not committed.
