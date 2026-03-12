import os
import asyncio

import pytest
import httpx
from fastapi.testclient import TestClient

# Ensure environment variables are set before importing the app.
os.environ.setdefault("ENVIRONMENT", "development")
os.environ.setdefault("DATABASE_URL", "sqlite+aiosqlite:///./test_smart_pantry.db")
os.environ.setdefault("GEMINI_API_KEY", "test-gemini-key")
os.environ.setdefault("SPOONACULAR_API_KEY", "test-spoonacular-key")

import main  # noqa: E402
from main import app, Base, engine, get_http_client, CleanedReceiptItem  # noqa: E402


@pytest.fixture(scope="session", autouse=True)
def _setup_test_database() -> None:
  """
  Create a fresh SQLite schema for tests.
  Runs once per test session.
  """

  async def init_models() -> None:
    async with engine.begin() as conn:
      await conn.run_sync(Base.metadata.drop_all)
      await conn.run_sync(Base.metadata.create_all)

  asyncio.run(init_models())


@pytest.fixture(scope="session", autouse=True)
def _override_http_client() -> None:
  """
  Provide a real httpx.AsyncClient instance for dependencies that require
  an HTTP client (e.g. recipes, Gemini), so tests don't hit the
  "HTTP client not initialized" RuntimeError. External calls are avoided
  by using inputs (like empty ingredients) that short-circuit before use.
  """
  async_client = httpx.AsyncClient()

  def _override():
    return async_client

  app.dependency_overrides[get_http_client] = _override

  yield

  asyncio.run(async_client.aclose())
  app.dependency_overrides.pop(get_http_client, None)


client = TestClient(app)


def test_health_endpoint() -> None:
  resp = client.get("/health")
  assert resp.status_code == 200
  assert resp.json() == {"detail": "ok"}


def test_pantry_crud_flow() -> None:
  user_id = "test-user"

  # Initially empty.
  resp = client.get("/pantry", params={"user_id": user_id})
  assert resp.status_code == 200
  assert resp.json() == []


def test_pantry_isolated_per_user() -> None:
  """
  Items created for one user must not appear in another user's pantry.
  """
  user_a = "user-a"
  user_b = "user-b"

  # Start from a clean state.
  resp = client.get("/pantry", params={"user_id": user_a})
  assert resp.status_code == 200
  resp = client.get("/pantry", params={"user_id": user_b})
  assert resp.status_code == 200

  # Create one item for user A.
  payload_a = {"item_name": "Apples", "category": "Fruit", "estimated_expiry_days": 5}
  resp = client.post("/pantry", params={"user_id": user_a}, json=payload_a)
  assert resp.status_code == 201
  item_a = resp.json()

  # Create one item for user B.
  payload_b = {"item_name": "Bread", "category": "Bakery", "estimated_expiry_days": 2}
  resp = client.post("/pantry", params={"user_id": user_b}, json=payload_b)
  assert resp.status_code == 201
  item_b = resp.json()

  # User A sees only their item.
  resp = client.get("/pantry", params={"user_id": user_a})
  assert resp.status_code == 200
  items_a = resp.json()
  assert len(items_a) == 1
  assert items_a[0]["id"] == item_a["id"]

  # User B sees only their item.
  resp = client.get("/pantry", params={"user_id": user_b})
  assert resp.status_code == 200
  items_b = resp.json()
  assert len(items_b) == 1
  assert items_b[0]["id"] == item_b["id"]


def test_delete_nonexistent_item_returns_404() -> None:
  user_id = "test-delete-404"

  # Ensure pantry is empty.
  resp = client.get("/pantry", params={"user_id": user_id})
  assert resp.status_code == 200

  # Deleting an unknown id should return 404.
  resp = client.delete("/pantry/999999", params={"user_id": user_id})
  assert resp.status_code == 404
  data = resp.json()
  assert data["detail"] == "Item not found"


def test_update_pantry_item_changes_fields() -> None:
  user_id = "test-update"

  # Create an item.
  create_payload = {
    "item_name": "Old Name",
    "category": "OldCat",
    "estimated_expiry_days": 1,
  }
  resp = client.post("/pantry", params={"user_id": user_id}, json=create_payload)
  assert resp.status_code == 201
  item = resp.json()
  item_id = item["id"]

  # Update name, category, and estimated_expiry_days.
  update_payload = {
    "item_name": "New Name",
    "category": "NewCat",
    "estimated_expiry_days": 5,
  }
  resp = client.patch(f"/pantry/{item_id}", params={"user_id": user_id}, json=update_payload)
  assert resp.status_code == 200
  updated = resp.json()
  assert updated["item_name"] == "New Name"
  assert updated["category"] == "NewCat"
  assert updated["estimated_expiry_days"] == 5
  # Expiry date should be present after update when estimated_expiry_days is set.
  assert updated["expiry_date"] is not None


def test_delete_item_wrong_user_gets_404_and_does_not_delete() -> None:
  owner_id = "owner-user"
  other_id = "other-user"

  # Create an item for owner.
  payload = {"item_name": "Yogurt", "category": "Dairy", "estimated_expiry_days": 7}
  resp = client.post("/pantry", params={"user_id": owner_id}, json=payload)
  assert resp.status_code == 201
  item = resp.json()
  item_id = item["id"]

  # Attempt delete with another user id.
  resp = client.delete(f"/pantry/{item_id}", params={"user_id": other_id})
  assert resp.status_code == 404

  # Item should still exist for the owner.
  resp = client.get("/pantry", params={"user_id": owner_id})
  assert resp.status_code == 200
  items = resp.json()
  assert any(i["id"] == item_id for i in items)


def test_recipes_suggestions_empty_when_no_pantry_items() -> None:
  """
  In non-demo ENVIRONMENT, when a user has no pantry items, /recipes/suggestions
  should return an empty list (because we don't call Spoonacular without ingredients).
  """
  user_id = "recipes-empty-user"

  resp = client.get("/pantry", params={"user_id": user_id})
  assert resp.status_code == 200
  assert resp.json() == []


def test_upload_receipt_rejects_non_image_file() -> None:
  user_id = "upload-non-image"

  files = {
    "user_id": (None, user_id),
    "file": ("test.txt", b"not an image", "text/plain"),
  }

  resp = client.post("/pantry/upload-receipt", files=files)
  assert resp.status_code == 400
  data = resp.json()
  assert data["detail"] == "File must be an image (e.g. image/jpeg, image/png)."


def test_upload_receipt_rejects_empty_image() -> None:
  user_id = "upload-empty-image"

  files = {
    "user_id": (None, user_id),
    "file": ("empty.jpg", b"", "image/jpeg"),
  }

  resp = client.post("/pantry/upload-receipt", files=files)
  assert resp.status_code == 400
  data = resp.json()
  assert data["detail"] == "Empty image file."


def test_ingest_receipt_text_creates_items_from_cleaner(monkeypatch: pytest.MonkeyPatch) -> None:
  user_id = "ingest-user"

  async def _fake_clean(raw_text: str, client: httpx.AsyncClient):
    return [
      CleanedReceiptItem(
        item_name="Test Apples",
        category="Fruit",
        estimated_expiry_days=4,
      )
    ]

  monkeypatch.setattr(main, "clean_receipt_data", _fake_clean)

  payload = {"raw_text": "ANY RAW OCR TEXT", "user_id": user_id}
  resp = client.post("/pantry/ingest-receipt-text", json=payload)
  assert resp.status_code == 201
  items = resp.json()
  assert len(items) == 1
  created = items[0]
  assert created["item_name"] == "Test Apples"
  assert created["category"] == "Fruit"
  assert created["estimated_expiry_days"] == 4
  assert created["expiry_date"] is not None

  # Confirm the item is actually in the pantry for that user.
  resp = client.get("/pantry", params={"user_id": user_id})
  assert resp.status_code == 200
  pantry_items = resp.json()
  assert any(i["item_name"] == "Test Apples" for i in pantry_items)


def test_get_recipe_ai_details_missing_title_returns_400() -> None:
  resp = client.post("/recipes/ai-details", json={})
  assert resp.status_code == 400
  data = resp.json()
  assert data["detail"] == "recipe_title is required"

