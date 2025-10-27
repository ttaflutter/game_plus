from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, update

from app.core.database import get_db
from app.api.auth import get_current_user
from app.models.models import User, UserGameRating, Game
from app.schemas.user import UserPublic, UserUpdate

router = APIRouter(prefix="/api/users", tags=["Users"])


async def get_user_caro_rating(db: AsyncSession, user_id: int) -> int | None:
    """Helper function to get user's Caro game rating."""
    print(f"🔍 Getting Caro rating for user {user_id}")
    game = await db.scalar(select(Game).where(Game.name == "Caro"))
    if not game:
        print(f"⚠️ Game 'Caro' not found in database!")
        return None
    
    print(f"✅ Found game Caro with id {game.id}")
    rating_obj = await db.scalar(
        select(UserGameRating.rating)
        .where(UserGameRating.user_id == user_id)
        .where(UserGameRating.game_id == game.id)
    )
    
    result = rating_obj if rating_obj is not None else 1200
    print(f"📊 User {user_id} rating: {result} (from_db={rating_obj is not None})")
    return result


async def user_to_public(user: User, db: AsyncSession) -> UserPublic:
    """Convert User model to UserPublic schema with rating."""
    rating = await get_user_caro_rating(db, user.id)
    
    # Handle empty string avatar_url (Pydantic V2 doesn't allow empty string for HttpUrl)
    avatar_url = user.avatar_url if user.avatar_url and user.avatar_url.strip() else None
    
    return UserPublic(
        id=user.id,
        username=user.username,
        email=user.email,
        avatar_url=avatar_url,
        provider=user.provider,
        bio=user.bio,
        rating=rating,
    )


@router.get("/me", response_model=UserPublic)
async def get_profile(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Get current user profile with Caro rating."""
    print(f"📍 GET /api/users/me called for user {current_user.id} ({current_user.username})")
    result = await user_to_public(current_user, db)
    print(f"📤 Returning user data with rating: {result.rating}")
    return result

@router.put("/me", response_model=UserPublic)
async def update_profile(
    payload: UserUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Update user profile and return with rating."""
    q = (
        update(User)
        .where(User.id == current_user.id)
        .values(
            username=payload.username or current_user.username,
            bio=payload.bio or current_user.bio,
            avatar_url=payload.avatar_url or current_user.avatar_url,
        )
        .returning(User)
    )
    res = await db.execute(q)
    await db.commit()
    updated_user = res.scalar_one()
    
    return await user_to_public(updated_user, db)
