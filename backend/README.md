# Smart Pantry Backend

FastAPI backend for the Smart Pantry app: pantry CRUD, receipt OCR (text and image), recipe suggestions, and AI recipe details.

## Tech stack

- **FastAPI** + Uvicorn
- **SQLAlchemy** (async) with SQLite (aiosqlite) or PostgreSQL (asyncpg)
- **Gemini 1.5 Flash** – receipt text/image parsing and AI recipe steps
- **Spoonacular API** – recipe search (skipped when `ENVIRONMENT=demo`)
- **python-multipart** – receipt image uploads

## Setup

1. **Virtual environment and dependencies**

```bash
cd backend
python -m venv .venv
# Windows:
.venv\Scripts\activate
# macOS/Linux:
source .venv/bin/activate

pip install -r requirements.txt
```

2. **Environment**

```bash
cp .env.example .env
```

Edit `.env` and set:

| Variable | Description |
|----------|-------------|
| `DATABASE_URL` | e.g. `sqlite+aiosqlite:///./smart_pantry.db` or PostgreSQL URL |
| `GEMINI_API_KEY` | Google AI API key (required for receipt OCR and AI steps) |
| `SPOONACULAR_API_KEY` | Spoonacular API key (optional if `ENVIRONMENT=demo`) |
| `ENVIRONMENT` | `demo` = use built-in demo recipes, no Spoonacular calls |

3. **Run**

```bash
uvicorn main:app --reload --port 8100
```

- API: **http://localhost:8100**
- Docs: **http://localhost:8100/docs**

## Main endpoints

| Method | Path | Description |
|--------|------|-------------|
| GET | `/pantry` | List pantry items (query: `user_id`) |
| POST | `/pantry` | Create pantry item (body: item_name, category, estimated_expiry_days, optional expiry_date) |
| POST | `/pantry/ingest-receipt-text` | Parse raw receipt text and add items (Gemini) |
| POST | `/pantry/upload-receipt` | Upload receipt image; OCR with Gemini vision and add items (multipart: `user_id`, `file`) |
| GET | `/recipes/suggestions` | Recipe suggestions from pantry (query: `user_id`) |
| POST | `/recipes/ai-details` | AI-generated recipe steps and tips (body: recipe_title, pantry_items) |

## Database

With SQLite, the database file is created automatically (e.g. `smart_pantry.db` in the backend directory). For PostgreSQL, create the schema as needed; the app uses standard async SQLAlchemy.
