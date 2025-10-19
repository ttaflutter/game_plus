from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, update

from app.core.database import get_db
from app.api.auth import get_current_user
from app.models.models import User
from app.schemas.user import UserPublic, UserUpdate

router = APIRouter(prefix="/api/users", tags=["Users"])

@router.get("/me", response_model=UserPublic)
async def get_profile(current_user: User = Depends(get_current_user)):
    return UserPublic.from_orm(current_user)

@router.put("/me", response_model=UserPublic)
async def update_profile(
    payload: UserUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
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
    user = res.fetchone()
    return UserPublic.from_orm(user)
