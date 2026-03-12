import os
import json
from datetime import datetime, timedelta, timezone
from typing import List, Optional

import httpx
from fastapi import FastAPI, UploadFile, File, Form, Depends, HTTPException, status, Body, Request, Response
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse, StreamingResponse
from pydantic import BaseModel, AnyHttpUrl, Field, ValidationError, ConfigDict
from pydantic_settings import BaseSettings
from sqlalchemy import Column, Integer, String, DateTime, Interval, func, text, select
from sqlalchemy.ext.asyncio import (
    AsyncSession,
    create_async_engine,
    async_sessionmaker,
)
from sqlalchemy.orm import declarative_base


class Settings(BaseSettings):
    app_name: str = "Smart Pantry API"
    environment: str = Field("development", env="ENVIRONMENT")

    database_url: str = Field(..., env="DATABASE_URL")

    gemini_api_key: str = Field(..., env="GEMINI_API_KEY")
    gemini_model: str = "gemini-1.5-flash"
    gemini_base_url: AnyHttpUrl = "https://generativelanguage.googleapis.com/v1beta"

    spoonacular_api_key: str = Field(..., env="SPOONACULAR_API_KEY")
    spoonacular_base_url: AnyHttpUrl = "https://api.spoonacular.com"

    # Comma-separated origins for CORS (e.g. http://localhost:51966,http://localhost:3000). Empty in dev = allow common localhost ports.
    allowed_origins_str: str = Field("", env="ALLOWED_ORIGINS")

    # Legacy: list of URLs (use ALLOWED_ORIGINS string instead).
    allowed_origins: List[AnyHttpUrl] = []

    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"


settings = Settings()

Base = declarative_base()

engine = create_async_engine(
    settings.database_url,
    echo=False,
    future=True,
)

AsyncSessionLocal = async_sessionmaker(
    bind=engine,
    autoflush=False,
    expire_on_commit=False,
    class_=AsyncSession,
)


class PantryItemORM(Base):
    __tablename__ = "pantry_items"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(String, index=True, nullable=False)
    item_name = Column(String, nullable=False)
    category = Column(String, nullable=True)
    estimated_expiry_days = Column(Integer, nullable=True)
    expiry_date = Column(DateTime(timezone=True), nullable=True)
    created_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )
    shelf_life = Column(Interval, nullable=True)


async def get_db() -> AsyncSession:
    async with AsyncSessionLocal() as session:
        yield session


class PantryItemBase(BaseModel):
    item_name: str
    category: Optional[str] = None
    estimated_expiry_days: Optional[int] = Field(
        default=None, ge=0, description="Approximate days until expiry."
    )
    expiry_date: Optional[datetime] = Field(
        default=None, description="Exact expiry date and time (ISO 8601)."
    )


class PantryItemCreate(PantryItemBase):
    pass


class PantryItemUpdate(BaseModel):
    item_name: Optional[str] = None
    category: Optional[str] = None
    estimated_expiry_days: Optional[int] = Field(
        default=None, ge=0, description="Approximate days until expiry."
    )

class PantryItemRead(PantryItemBase):
    id: int
    expiry_date: Optional[datetime] = None
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


class CleanedReceiptItem(BaseModel):
    item_name: str
    category: Optional[str] = None
    estimated_expiry_days: Optional[int] = None


class CleanReceiptRequest(BaseModel):
    raw_text: str
    user_id: str = Field(..., description="Current user id")


class CleanReceiptResponse(BaseModel):
    items: List[CleanedReceiptItem]


class MessageResponse(BaseModel):
    detail: str


class RecipeSuggestion(BaseModel):
    id: int
    title: str
    image_url: str
    owned_ingredients: int
    total_ingredients: int
    match_percentage: float
    tags: List[str] = []


class RecipeStep(BaseModel):
    order: int
    text: str


class RecipeAiDetails(BaseModel):
    title: str
    summary: str
    estimated_time_minutes: int
    difficulty: str
    steps: List[RecipeStep]
    tips: List[str] = []


DEMO_RECIPES_BASE = [
    {
        "title": "Creamy Garlic Parmesan Chicken",
        "image_url": "https://images.pexels.com/photos/6287522/pexels-photo-6287522.jpeg",
        "owned_ingredients": 6,
        "total_ingredients": 9,
        "match_percentage": 0.67,
        "tags": ["Dinner", "Chicken", "Comfort"],
    },
    {
        "title": "One-Pan Lemon Herb Salmon",
        "image_url": "https://images.pexels.com/photos/3296273/pexels-photo-3296273.jpeg",
        "owned_ingredients": 5,
        "total_ingredients": 8,
        "match_percentage": 0.62,
        "tags": ["Dinner", "Fish", "Healthy"],
    },
    {
        "title": "Roasted Veggie Buddha Bowl",
        "image_url": "https://images.pexels.com/photos/1640777/pexels-photo-1640777.jpeg",
        "owned_ingredients": 7,
        "total_ingredients": 10,
        "match_percentage": 0.7,
        "tags": ["Lunch", "Vegan", "Bowl"],
    },
    {
        "title": "Spicy Chickpea & Spinach Curry",
        "image_url": "https://images.pexels.com/photos/1640773/pexels-photo-1640773.jpeg",
        "owned_ingredients": 6,
        "total_ingredients": 11,
        "match_percentage": 0.55,
        "tags": ["Dinner", "Vegetarian", "Gluten-Free"],
    },
    {
        "title": "Sheet-Pan Fajita Chicken",
        "image_url": "https://images.pexels.com/photos/461198/pexels-photo-461198.jpeg",
        "owned_ingredients": 5,
        "total_ingredients": 9,
        "match_percentage": 0.56,
        "tags": ["Dinner", "Chicken", "Family"],
    },
    {
        "title": "Garlic Butter Shrimp Pasta",
        "image_url": "https://images.pexels.com/photos/6287301/pexels-photo-6287301.jpeg",
        "owned_ingredients": 7,
        "total_ingredients": 10,
        "match_percentage": 0.7,
        "tags": ["Dinner", "Seafood", "Pasta"],
    },
    {
        "title": "Caprese Stuffed Chicken Breast",
        "image_url": "https://images.pexels.com/photos/4079529/pexels-photo-4079529.jpeg",
        "owned_ingredients": 5,
        "total_ingredients": 8,
        "match_percentage": 0.62,
        "tags": ["Dinner", "Chicken", "Low-Carb"],
    },
    {
        "title": "Honey Soy Glazed Salmon Rice Bowl",
        "image_url": "https://images.pexels.com/photos/3296277/pexels-photo-3296277.jpeg",
        "owned_ingredients": 6,
        "total_ingredients": 9,
        "match_percentage": 0.67,
        "tags": ["Dinner", "Asian", "Fish"],
    },
    {
        "title": "Crispy Tofu Stir-Fry with Veggies",
        "image_url": "https://images.pexels.com/photos/14386762/pexels-photo-14386762.jpeg",
        "owned_ingredients": 7,
        "total_ingredients": 11,
        "match_percentage": 0.64,
        "tags": ["Dinner", "Vegan", "Stir-Fry"],
    },
    {
        "title": "Mediterranean Chickpea Salad",
        "image_url": "https://images.pexels.com/photos/1487511/pexels-photo-1487511.jpeg",
        "owned_ingredients": 6,
        "total_ingredients": 9,
        "match_percentage": 0.67,
        "tags": ["Lunch", "Vegetarian", "Salad"],
    },
    {
        "title": "Oven-Baked Herb Potato Wedges",
        "image_url": "https://images.pexels.com/photos/1583884/pexels-photo-1583884.jpeg",
        "owned_ingredients": 4,
        "total_ingredients": 6,
        "match_percentage": 0.67,
        "tags": ["Side", "Vegetarian", "Snack"],
    },
    {
        "title": "Classic Beef & Bean Chili",
        "image_url": "https://images.pexels.com/photos/1537166/pexels-photo-1537166.jpeg",
        "owned_ingredients": 7,
        "total_ingredients": 12,
        "match_percentage": 0.58,
        "tags": ["Dinner", "Beef", "Comfort"],
    },
    {
        "title": "Slow Cooker Pulled Chicken Tacos",
        "image_url": "https://images.pexels.com/photos/3298183/pexels-photo-3298183.jpeg",
        "owned_ingredients": 6,
        "total_ingredients": 10,
        "match_percentage": 0.6,
        "tags": ["Dinner", "Chicken", "Tacos"],
    },
    {
        "title": "Veggie-Packed Fried Rice",
        "image_url": "https://images.pexels.com/photos/4553127/pexels-photo-4553127.jpeg",
        "owned_ingredients": 7,
        "total_ingredients": 10,
        "match_percentage": 0.7,
        "tags": ["Dinner", "Vegetarian", "Rice"],
    },
    {
        "title": "Baked Feta & Tomato Pasta",
        "image_url": "https://images.pexels.com/photos/1437267/pexels-photo-1437267.jpeg",
        "owned_ingredients": 5,
        "total_ingredients": 8,
        "match_percentage": 0.62,
        "tags": ["Dinner", "Pasta", "Viral"],
    },
    {
        "title": "Crispy Baked Chicken Thighs",
        "image_url": "https://images.pexels.com/photos/4106483/pexels-photo-4106483.jpeg",
        "owned_ingredients": 4,
        "total_ingredients": 7,
        "match_percentage": 0.57,
        "tags": ["Dinner", "Chicken", "Easy"],
    },
    {
        "title": "Creamy Tomato Basil Soup",
        "image_url": "https://images.pexels.com/photos/4103373/pexels-photo-4103373.jpeg",
        "owned_ingredients": 5,
        "total_ingredients": 9,
        "match_percentage": 0.56,
        "tags": ["Lunch", "Vegetarian", "Soup"],
    },
    {
        "title": "Garlic Roasted Brussels Sprouts",
        "image_url": "https://images.pexels.com/photos/5710170/pexels-photo-5710170.jpeg",
        "owned_ingredients": 4,
        "total_ingredients": 7,
        "match_percentage": 0.57,
        "tags": ["Side", "Vegetarian", "Roasted"],
    },
    {
        "title": "Breakfast Burrito with Eggs & Beans",
        "image_url": "https://images.pexels.com/photos/4958677/pexels-photo-4958677.jpeg",
        "owned_ingredients": 6,
        "total_ingredients": 9,
        "match_percentage": 0.67,
        "tags": ["Breakfast", "Eggs", "High-Protein"],
    },
    {
        "title": "Overnight Oats with Berries",
        "image_url": "https://images.pexels.com/photos/4113601/pexels-photo-4113601.jpeg",
        "owned_ingredients": 5,
        "total_ingredients": 7,
        "match_percentage": 0.71,
        "tags": ["Breakfast", "Vegetarian", "Meal-Prep"],
    },
    {
        "title": "Greek Yogurt Parfait with Granola",
        "image_url": "https://images.pexels.com/photos/1437268/pexels-photo-1437268.jpeg",
        "owned_ingredients": 5,
        "total_ingredients": 8,
        "match_percentage": 0.62,
        "tags": ["Breakfast", "Snack", "High-Protein"],
    },
    {
        "title": "Simple Margherita Flatbread Pizza",
        "image_url": "https://images.pexels.com/photos/4109087/pexels-photo-4109087.jpeg",
        "owned_ingredients": 5,
        "total_ingredients": 8,
        "match_percentage": 0.62,
        "tags": ["Dinner", "Vegetarian", "Pizza"],
    },
    {
        "title": "Spinach & Mushroom Omelette",
        "image_url": "https://images.pexels.com/photos/4393021/pexels-photo-4393021.jpeg",
        "owned_ingredients": 4,
        "total_ingredients": 7,
        "match_percentage": 0.57,
        "tags": ["Breakfast", "Eggs", "Low-Carb"],
    },
    {
        "title": "BBQ Chicken Sheet-Pan Nachos",
        "image_url": "https://images.pexels.com/photos/8448327/pexels-photo-8448327.jpeg",
        "owned_ingredients": 6,
        "total_ingredients": 10,
        "match_percentage": 0.6,
        "tags": ["Snack", "Chicken", "Game-Day"],
    },
    {
        "title": "Lentil & Sweet Potato Stew",
        "image_url": "https://images.pexels.com/photos/6546027/pexels-photo-6546027.jpeg",
        "owned_ingredients": 7,
        "total_ingredients": 11,
        "match_percentage": 0.64,
        "tags": ["Dinner", "Vegan", "One-Pot"],
    },
    {
        "title": "Garlic Butter Green Beans",
        "image_url": "https://images.pexels.com/photos/1435895/pexels-photo-1435895.jpeg",
        "owned_ingredients": 4,
        "total_ingredients": 6,
        "match_percentage": 0.67,
        "tags": ["Side", "Vegetarian", "Quick"],
    },
    {
        "title": "Crispy Baked Falafel Wraps",
        "image_url": "https://images.pexels.com/photos/6546020/pexels-photo-6546020.jpeg",
        "owned_ingredients": 6,
        "total_ingredients": 10,
        "match_percentage": 0.6,
        "tags": ["Dinner", "Vegan", "Middle Eastern"],
    },
    {
        "title": "Peanut Butter Banana Smoothie",
        "image_url": "https://images.pexels.com/photos/5938240/pexels-photo-5938240.jpeg",
        "owned_ingredients": 4,
        "total_ingredients": 6,
        "match_percentage": 0.67,
        "tags": ["Breakfast", "Snack", "Smoothie"],
    },
    {
        "title": "Berry Spinach Power Salad",
        "image_url": "https://images.pexels.com/photos/1435894/pexels-photo-1435894.jpeg",
        "owned_ingredients": 6,
        "total_ingredients": 9,
        "match_percentage": 0.67,
        "tags": ["Lunch", "Vegetarian", "Salad"],
    },
    {
        "title": "Sheet-Pan Roasted Sausage & Veggies",
        "image_url": "https://images.pexels.com/photos/3731474/pexels-photo-3731474.jpeg",
        "owned_ingredients": 6,
        "total_ingredients": 10,
        "match_percentage": 0.6,
        "tags": ["Dinner", "Sausage", "Sheet-Pan"],
    },
]


def build_demo_recipes(max_results: int) -> List[RecipeSuggestion]:
    recipes: List[RecipeSuggestion] = []
    if max_results <= 0:
        return recipes

    idx = 1
    while len(recipes) < max_results:
        for base in DEMO_RECIPES_BASE:
            recipes.append(
                RecipeSuggestion(
                    id=idx,
                    title=base["title"],
                    image_url=base["image_url"],
                    owned_ingredients=base["owned_ingredients"],
                    total_ingredients=base["total_ingredients"],
                    match_percentage=base["match_percentage"],
                    tags=base["tags"],
                )
            )
            idx += 1
            if len(recipes) >= max_results:
                break

    return recipes


async_client: Optional[httpx.AsyncClient] = None


async def get_http_client() -> httpx.AsyncClient:
    if async_client is None:
        raise RuntimeError("HTTP client not initialized")
    return async_client


async def call_gemini_for_items(
    raw_text: str,
    client: httpx.AsyncClient,
    settings: Settings,
) -> List[CleanedReceiptItem]:
    system_prompt = (
        "You are a grocery receipt parser. "
        "Given raw OCR text from a grocery receipt, extract food items. "
        "Return ONLY a JSON array. Each element must have: "
        "`item_name` (string), `category` (string or null), "
        "`estimated_expiry_days` (integer or null). "
        "Do not include any extra keys, explanations, or markdown."
    )

    user_prompt = f"Clean this grocery receipt text and extract pantry items:\n{raw_text}"

    url = (
        f"{settings.gemini_base_url}/models/"
        f"{settings.gemini_model}:generateContent"
    )
    params = {"key": settings.gemini_api_key}

    payload = {
        "contents": [
            {
                "role": "user",
                "parts": [
                    {"text": system_prompt},
                    {"text": user_prompt},
                ],
            }
        ],
        "generationConfig": {
            "temperature": 0.2,
            "maxOutputTokens": 1024,
        },
    }

    try:
        resp = await client.post(url, params=params, json=payload, timeout=30.0)
    except httpx.RequestError as exc:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"Error reaching Gemini API: {exc}",
        )

    if resp.status_code != 200:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"Gemini API error: {resp.status_code} {resp.text}",
        )

    data = resp.json()

    try:
        text = data["candidates"][0]["content"]["parts"][0]["text"]
    except (KeyError, IndexError) as exc:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"Unexpected Gemini response structure: {exc}",
        )

    try:
        parsed = json.loads(text)
    except json.JSONDecodeError as exc:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"Gemini output was not valid JSON: {exc}",
        )

    if not isinstance(parsed, list):
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Gemini output is not a JSON list.",
        )

    try:
        items = [CleanedReceiptItem(**item) for item in parsed]
    except ValidationError as exc:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"Gemini output validation failed: {exc.errors()}",
        )

    return items


async def clean_receipt_data(raw_text: str, client: httpx.AsyncClient) -> List[CleanedReceiptItem]:
    return await call_gemini_for_items(raw_text=raw_text, client=client, settings=settings)


async def call_gemini_vision_receipt(
    image_bytes: bytes,
    mime_type: str,
    client: httpx.AsyncClient,
    settings: Settings,
) -> List[CleanedReceiptItem]:
    """Extract pantry items from a receipt image using Gemini vision."""
    import base64
    b64 = base64.standard_b64encode(image_bytes).decode("ascii")
    prompt = (
        "Look at this receipt image. Extract all grocery/food items. "
        "Return ONLY a JSON array. Each element must have: "
        "`item_name` (string), `category` (string or null), "
        "`estimated_expiry_days` (integer or null). "
        "Do not include any extra keys, explanations, or markdown."
    )
    url = (
        f"{settings.gemini_base_url}/models/"
        f"{settings.gemini_model}:generateContent"
    )
    params = {"key": settings.gemini_api_key}
    payload = {
        "contents": [
            {
                "role": "user",
                "parts": [
                    {"inline_data": {"mime_type": mime_type, "data": b64}},
                    {"text": prompt},
                ],
            }
        ],
        "generationConfig": {"temperature": 0.2, "maxOutputTokens": 1024},
    }
    try:
        resp = await client.post(url, params=params, json=payload, timeout=60.0)
    except httpx.RequestError as exc:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"Error reaching Gemini API: {exc}",
        )
    if resp.status_code != 200:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"Gemini API error: {resp.status_code} {resp.text}",
        )
    data = resp.json()
    try:
        text = data["candidates"][0]["content"]["parts"][0]["text"]
    except (KeyError, IndexError) as exc:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"Unexpected Gemini response structure: {exc}",
        )
    try:
        parsed = json.loads(text)
    except json.JSONDecodeError as exc:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"Gemini output was not valid JSON: {exc}",
        )
    if not isinstance(parsed, list):
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Gemini output is not a JSON list.",
        )
    try:
        return [CleanedReceiptItem(**item) for item in parsed]
    except ValidationError as exc:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"Gemini output validation failed: {exc.errors()}",
        )


async def fetch_spoonacular_recipes(
    ingredients: List[str],
    client: httpx.AsyncClient,
    settings: Settings,
    max_results: int = 100,
) -> List[RecipeSuggestion]:
    """
    Calls Spoonacular's findByIngredients endpoint and normalizes results.
    When ENVIRONMENT=demo, returns rich local demo data instead of calling Spoonacular.
    """
    # Demo mode: always serve local sample recipes so the UI
    # looks fully populated even without external APIs.
    if settings.environment.lower() == "demo":
        return build_demo_recipes(max_results)

    if not ingredients:
        return []

    url = f"{settings.spoonacular_base_url}/recipes/findByIngredients"
    params = {
        "apiKey": settings.spoonacular_api_key,
        "ingredients": ",".join(ingredients[:15]),
        "number": max_results,
        "ranking": 1,
        "ignorePantry": "true",
    }

    try:
        resp = await client.get(url, params=params, timeout=20.0)
    except httpx.RequestError as exc:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"Error reaching Spoonacular API: {exc}",
        )

    if resp.status_code != 200:
        # Graceful fallback when Spoonacular daily quota is exceeded, so
        # the UI still shows something instead of an error.
        if resp.status_code == 402:
            top = ingredients[:3] or ["Pantry"]
            fallback: List[RecipeSuggestion] = []
            for idx, name in enumerate(top, start=1):
                fallback.append(
                    RecipeSuggestion(
                        id=idx,
                        title=f"Use your {name.title()}",
                        image_url="",
                        owned_ingredients=1,
                        total_ingredients=1,
                        match_percentage=1.0,
                        tags=["Fallback", "Pantry"],
                    )
                )
            return fallback

        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"Spoonacular API error: {resp.status_code} {resp.text}",
        )

    data = resp.json()
    if not isinstance(data, list):
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Spoonacular output is not a JSON list.",
        )

    suggestions: List[RecipeSuggestion] = []
    for item in data:
        try:
            rid = int(item.get("id"))
            title = str(item.get("title") or "Untitled")
            image_url = str(item.get("image") or "")
            used = int(item.get("usedIngredientCount") or 0)
            missed = int(item.get("missedIngredientCount") or 0)
            total = max(used + missed, 1)
            match_percentage = float(used / total)
            tags: List[str] = []
            if missed == 0:
                tags.append("Most Ingredients")
            if used >= 3:
                tags.append("Pantry Friendly")

            suggestions.append(
                RecipeSuggestion(
                    id=rid,
                    title=title,
                    image_url=image_url,
                    owned_ingredients=used,
                    total_ingredients=total,
                    match_percentage=match_percentage,
                    tags=tags,
                )
            )
        except Exception:
            continue

    return suggestions


async def generate_recipe_ai_details(
    recipe_title: str,
    pantry_items: List[str],
    client: httpx.AsyncClient,
    settings: Settings,
) -> RecipeAiDetails:
    """
    Uses Gemini to generate human-friendly cooking steps and meta info
    for a given recipe title and the current pantry.
    """
    system_prompt = (
        "You are a helpful cooking assistant for a smart pantry app. "
        "Given a recipe title and the list of ingredients in a user's pantry, "
        "you generate concise cooking instructions and meta information. "
        "Return ONLY a JSON object with this exact schema:\n\n"
        "{\n"
        '  "title": string,\n'
        '  "summary": string,\n'
        '  "estimated_time_minutes": integer,\n'
        '  "difficulty": string,\n'
        '  "steps": [ {"order": integer, "text": string}, ... ],\n'
        '  "tips": [string, ...]\n'
        "}\n\n"
        "Do not include any extra keys, comments, markdown, or explanations."
    )

    user_prompt = (
        f"Recipe title: {recipe_title}\n\n"
        f"Pantry items you can assume are available: {', '.join(pantry_items) or 'Unknown'}.\n\n"
        "Write practical home-cook friendly steps that use as many pantry items as possible."
    )

    url = (
        f"{settings.gemini_base_url}/models/"
        f"{settings.gemini_model}:generateContent"
    )
    params = {"key": settings.gemini_api_key}

    payload = {
        "contents": [
            {
                "role": "user",
                "parts": [
                    {"text": system_prompt},
                    {"text": user_prompt},
                ],
            }
        ],
        "generationConfig": {
            "temperature": 0.3,
            "maxOutputTokens": 1024,
        },
    }

    try:
        resp = await client.post(url, params=params, json=payload, timeout=30.0)
    except httpx.RequestError as exc:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"Error reaching Gemini API: {exc}",
        )

    if resp.status_code != 200:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"Gemini API error: {resp.status_code} {resp.text}",
        )

    data = resp.json()
    try:
        text = data["candidates"][0]["content"]["parts"][0]["text"]
    except (KeyError, IndexError) as exc:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"Unexpected Gemini response structure: {exc}",
        )

    try:
        parsed = json.loads(text)
    except json.JSONDecodeError as exc:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"Gemini output was not valid JSON: {exc}",
        )

    try:
        steps = [
            RecipeStep(order=int(s.get("order", i + 1)), text=str(s.get("text") or ""))
            for i, s in enumerate(parsed.get("steps") or [])
        ]
        details = RecipeAiDetails(
            title=str(parsed.get("title") or recipe_title),
            summary=str(parsed.get("summary") or f"How to cook {recipe_title}."),
            estimated_time_minutes=int(parsed.get("estimated_time_minutes") or 20),
            difficulty=str(parsed.get("difficulty") or "Easy"),
            steps=steps or [
                RecipeStep(order=1, text=f"Cook {recipe_title} using your available pantry items.")
            ],
            tips=[str(t) for t in (parsed.get("tips") or [])],
        )
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"Gemini details parsing failed: {exc}",
        )

    return details


app = FastAPI(title=settings.app_name, version="1.0.0")


@app.on_event("startup")
async def on_startup() -> None:
    global async_client
    async_client = httpx.AsyncClient(timeout=30.0)

    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)


@app.on_event("shutdown")
async def on_shutdown() -> None:
    global async_client
    if async_client:
        await async_client.aclose()
        async_client = None


def _cors_origins() -> list[str]:
    if settings.allowed_origins_str.strip():
        return [o.strip() for o in settings.allowed_origins_str.split(",") if o.strip()]
    if settings.allowed_origins:
        return [str(o) for o in settings.allowed_origins]
    # Default dev: allow Flutter web and common localhost ports (required when allow_credentials=True).
    return [
        "http://localhost:51966",
        "http://127.0.0.1:51966",
        "http://localhost:8080",
        "http://127.0.0.1:8080",
        "http://localhost:3000",
        "http://127.0.0.1:3000",
    ]


app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.options("/{rest_of_path:path}")
async def preflight_cors(rest_of_path: str, request: Request) -> Response:
    """
    Handle CORS preflight requests explicitly so the browser always
    receives the expected headers on OPTIONS.
    """
    return Response(
        status_code=status.HTTP_204_NO_CONTENT,
        headers={
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Methods": "GET,POST,PUT,DELETE,OPTIONS",
            "Access-Control-Allow-Headers": request.headers.get(
                "Access-Control-Request-Headers", "*"
            ),
        },
    )


@app.middleware("http")
async def add_cors_headers(request: Request, call_next):
    """
    Ensure all responses (including errors) include permissive CORS headers
    in development so Flutter web can reach the API.
    """
    response = await call_next(request)
    response.headers.setdefault("Access-Control-Allow-Origin", "*")
    response.headers.setdefault("Access-Control-Allow-Methods", "*")
    response.headers.setdefault("Access-Control-Allow-Headers", "*")
    return response


@app.get("/health", response_model=MessageResponse)
async def health() -> MessageResponse:
    return MessageResponse(detail="ok")


@app.get("/pantry", response_model=List[PantryItemRead])
async def list_pantry_items(
    user_id: str,
    db: AsyncSession = Depends(get_db),
) -> List[PantryItemRead]:
    result = await db.execute(
        text(
            """
            SELECT * FROM pantry_items
            WHERE user_id = :user_id
            ORDER BY created_at DESC
            """
        ),
        {"user_id": user_id},
    )
    rows = result.mappings().all()
    items = []
    for row in rows:
        orm = PantryItemORM(**row)
        items.append(PantryItemRead.from_orm(orm))
    return items


@app.post(
    "/pantry",
    response_model=PantryItemRead,
    status_code=status.HTTP_201_CREATED,
)
async def create_pantry_item(
    user_id: str,
    payload: PantryItemCreate,
    db: AsyncSession = Depends(get_db),
) -> PantryItemRead:
    expiry_date: Optional[datetime] = None
    shelf_life = None
    if payload.expiry_date is not None:
        expiry_date = payload.expiry_date
        if expiry_date.tzinfo is None:
            expiry_date = expiry_date.replace(tzinfo=timezone.utc)
        if payload.estimated_expiry_days is not None:
            shelf_life = timedelta(days=payload.estimated_expiry_days)
        else:
            delta = expiry_date - datetime.now(timezone.utc)
            shelf_life = delta if delta.total_seconds() > 0 else timedelta(0)
    elif payload.estimated_expiry_days is not None:
        shelf_life = timedelta(days=payload.estimated_expiry_days)
        expiry_date = datetime.now(timezone.utc) + shelf_life

    item = PantryItemORM(
        user_id=user_id,
        item_name=payload.item_name,
        category=payload.category,
        estimated_expiry_days=payload.estimated_expiry_days,
        expiry_date=expiry_date,
        shelf_life=shelf_life,
    )
    db.add(item)
    await db.commit()
    await db.refresh(item)
    return PantryItemRead.from_orm(item)


@app.patch(
    "/pantry/{item_id}",
    response_model=PantryItemRead,
)
async def update_pantry_item(
    item_id: int,
    user_id: str,
    payload: PantryItemUpdate,
    db: AsyncSession = Depends(get_db),
) -> PantryItemRead:
    result = await db.execute(
        select(PantryItemORM).where(
            PantryItemORM.id == item_id, PantryItemORM.user_id == user_id
        )
    )
    orm = result.scalars().first()
    if orm is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Item not found"
        )

    if payload.item_name is not None:
        orm.item_name = payload.item_name
    if payload.category is not None:
        orm.category = payload.category

    if payload.estimated_expiry_days is not None:
        orm.estimated_expiry_days = payload.estimated_expiry_days
        shelf_life = timedelta(days=payload.estimated_expiry_days)
        orm.shelf_life = shelf_life
        orm.expiry_date = datetime.now(timezone.utc) + shelf_life

    db.add(orm)
    await db.commit()
    await db.refresh(orm)
    return PantryItemRead.from_orm(orm)


@app.delete(
    "/pantry/{item_id}",
    status_code=status.HTTP_204_NO_CONTENT,
)
async def delete_pantry_item(
    item_id: int,
    user_id: str,
    db: AsyncSession = Depends(get_db),
) -> None:
    result = await db.execute(
        select(PantryItemORM).where(
            PantryItemORM.id == item_id, PantryItemORM.user_id == user_id
        )
    )
    orm = result.scalars().first()
    if orm is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Item not found"
        )

    await db.delete(orm)
    await db.commit()


@app.post(
    "/pantry/parse-receipt-text",
    response_model=CleanReceiptResponse,
)
async def parse_receipt_text(
    body: CleanReceiptRequest,
    client: httpx.AsyncClient = Depends(get_http_client),
) -> CleanReceiptResponse:
    items = await clean_receipt_data(raw_text=body.raw_text, client=client)
    return CleanReceiptResponse(items=items)


@app.post(
    "/pantry/ingest-receipt-text",
    response_model=List[PantryItemRead],
    status_code=status.HTTP_201_CREATED,
)
async def ingest_receipt_text(
    body: CleanReceiptRequest,
    client: httpx.AsyncClient = Depends(get_http_client),
    db: AsyncSession = Depends(get_db),
) -> List[PantryItemRead]:
    items = await clean_receipt_data(raw_text=body.raw_text, client=client)

    to_create: List[PantryItemORM] = []
    for it in items:
        expiry_date = None
        shelf_life = None
        if it.estimated_expiry_days is not None:
            shelf_life = timedelta(days=it.estimated_expiry_days)
            expiry_date = datetime.now(timezone.utc) + shelf_life

        to_create.append(
            PantryItemORM(
                user_id=body.user_id,
                item_name=it.item_name,
                category=it.category,
                estimated_expiry_days=it.estimated_expiry_days,
                expiry_date=expiry_date,
                shelf_life=shelf_life,
            )
        )

    db.add_all(to_create)
    await db.commit()
    for item in to_create:
        await db.refresh(item)

    return [PantryItemRead.from_orm(i) for i in to_create]


@app.get(
    "/recipes/suggestions",
    response_model=List[RecipeSuggestion],
)
async def recipe_suggestions(
    user_id: str,
    db: AsyncSession = Depends(get_db),
    client: httpx.AsyncClient = Depends(get_http_client),
) -> List[RecipeSuggestion]:
    """
    Returns recipe suggestions from Spoonacular based on the user's pantry.
    In demo mode, always returns rich local demo data even if pantry is empty.
    """
    result = await db.execute(
        text(
            """
            SELECT item_name
            FROM pantry_items
            WHERE user_id = :user_id
            ORDER BY created_at DESC
            """
        ),
        {"user_id": user_id},
    )
    rows = result.mappings().all()
    ingredient_names = [row["item_name"] for row in rows]

    # In demo mode we ignore whether the pantry is empty and still
    # return a full demo recipe list so the UI looks populated.
    if settings.environment.lower() == "demo":
        return await fetch_spoonacular_recipes(
            ingredients=ingredient_names or ["demo"],
            client=client,
            settings=settings,
        )

    return await fetch_spoonacular_recipes(
        ingredients=ingredient_names,
        client=client,
        settings=settings,
    )


@app.get("/image-proxy")
async def image_proxy(
    url: str,
    client: httpx.AsyncClient = Depends(get_http_client),
):
    """
    Simple image proxy to work around CORS for Flutter web NetworkImage.
    """
    try:
        resp = await client.get(url, timeout=20.0)
    except httpx.RequestError as exc:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"Error fetching image: {exc}",
        )

    if resp.status_code != 200:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"Upstream image error: {resp.status_code}",
        )

    content_type = resp.headers.get("content-type", "image/jpeg")
    return StreamingResponse(
        iter([resp.content]),
        media_type=content_type,
    )


@app.post("/recipes/ai-details", response_model=RecipeAiDetails)
async def get_recipe_ai_details(
    payload: dict,
    db: AsyncSession = Depends(get_db),
    client: httpx.AsyncClient = Depends(get_http_client),
):
    """
    Generate AI-powered cooking steps and meta info for a recipe.

    Expects JSON body:
    {
      "recipe_title": "string",
      "pantry_items": ["egg", "milk", ...]   # optional
    }
    """
    recipe_title = str(payload.get("recipe_title") or "").strip()
    pantry_items = payload.get("pantry_items") or []

    if not recipe_title:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="recipe_title is required",
        )

    # If pantry_items not provided, fall back to names from DB
    if not pantry_items:
        result = await db.execute(
            text(
                """
                SELECT item_name
                FROM pantry_items
                ORDER BY created_at DESC
                """
            )
        )
        rows = result.mappings().all()
        pantry_items = [row["item_name"] for row in rows]

    # Try Gemini first; if it fails for any reason, return a safe
    # local fallback so the UI always has something to show.
    try:
        return await generate_recipe_ai_details(
            recipe_title=recipe_title,
            pantry_items=pantry_items,
            client=client,
            settings=settings,
        )
    except Exception:
        steps = [
            RecipeStep(
                order=1,
                text=f"Gather all the ingredients you have for {recipe_title}.",
            ),
            RecipeStep(
                order=2,
                text="Preheat your pan, oven or pot as appropriate and prepare basic aromatics like garlic, onion or spices.",
            ),
            RecipeStep(
                order=3,
                text="Cook the main ingredient (such as pasta, rice, protein or vegetables) until just done, seasoning with salt and pepper.",
            ),
            RecipeStep(
                order=4,
                text="Combine everything together, taste and adjust with acid (lemon or vinegar), herbs and extra seasoning.",
            ),
            RecipeStep(
                order=5,
                text="Serve warm, garnish with any fresh herbs, cheese or crunchy toppings you have available.",
            ),
        ]

        return RecipeAiDetails(
            title=recipe_title,
            summary=f"A simple way to cook {recipe_title} using what you already have in your pantry.",
            estimated_time_minutes=25,
            difficulty="Easy",
            steps=steps,
            tips=[
                "Taste as you go and adjust seasoning gradually.",
                "Add a splash of the starchy cooking liquid (like pasta water) to make sauces silky.",
                "Layer flavors with aromatics first, then spices, then fresh herbs at the end.",
            ],
        )

@app.post(
    "/pantry/upload-receipt",
    response_model=List[PantryItemRead],
    status_code=status.HTTP_201_CREATED,
)
async def upload_receipt_image(
    user_id: str = Form(...),
    file: UploadFile = File(...),
    client: httpx.AsyncClient = Depends(get_http_client),
    db: AsyncSession = Depends(get_db),
) -> List[PantryItemRead]:
    content_type = file.content_type or "image/jpeg"
    if not content_type.startswith("image/"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="File must be an image (e.g. image/jpeg, image/png).",
        )
    try:
        image_bytes = await file.read()
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Failed to read image: {exc}",
        )
    if not image_bytes:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Empty image file.",
        )
    items = await call_gemini_vision_receipt(
        image_bytes=image_bytes,
        mime_type=content_type,
        client=client,
        settings=settings,
    )
    to_create: List[PantryItemORM] = []
    for it in items:
        expiry_date = None
        shelf_life = None
        if it.estimated_expiry_days is not None:
            shelf_life = timedelta(days=it.estimated_expiry_days)
            expiry_date = datetime.now(timezone.utc) + shelf_life
        to_create.append(
            PantryItemORM(
                user_id=user_id,
                item_name=it.item_name,
                category=it.category,
                estimated_expiry_days=it.estimated_expiry_days,
                expiry_date=expiry_date,
                shelf_life=shelf_life,
            )
        )
    db.add_all(to_create)
    await db.commit()
    for orm in to_create:
        await db.refresh(orm)
    return [PantryItemRead.model_validate(i) for i in to_create]


@app.exception_handler(HTTPException)
async def http_exception_handler(_, exc: HTTPException):
    return JSONResponse(
        status_code=exc.status_code,
        content={"detail": exc.detail},
    )


@app.exception_handler(Exception)
async def unhandled_exception_handler(_, exc: Exception):
    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content={"detail": "Internal server error."},
    )

