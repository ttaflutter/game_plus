from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.core.database import get_db
from app.core.security import create_access_token
from app.core.config import access_token_expires
from app.models.models import User
from app.schemas.auth import TokenResponse, UserPublic, LoginGoogleRequest
from app.api.auth import ensure_user_caro_rating, user_to_public  # Import helpers

router = APIRouter(prefix="/api/auth", tags=["Auth"])

@router.post("/google-login", response_model=TokenResponse)
async def google_login(payload: LoginGoogleRequest, db: AsyncSession = Depends(get_db)):
    email = payload.email
    name = payload.name or email.split("@")[0]
    avatar = str(payload.avatar_url) if payload.avatar_url else None
    sub = payload.sub

    # Tìm user theo provider_id (Google ID)
    res = await db.execute(select(User).where(User.provider == "google", User.provider_id == sub))
    user = res.scalar_one_or_none()

    # Nếu chưa có, thử tìm theo email
    if not user:
        res = await db.execute(select(User).where(User.email == email))
        existing_email_user = res.scalar_one_or_none()

        if existing_email_user:
            # Liên kết Google với user local cũ
            existing_email_user.provider = "google"
            existing_email_user.provider_id = sub
            existing_email_user.avatar_url = avatar or existing_email_user.avatar_url
            user = existing_email_user
        else:
            # Tạo mới user Google
            user = User(
                username=name,
                email=email,
                avatar_url=avatar,
                hashed_password=None,
                bio="",
                provider="google",
                provider_id=sub,
            )
            db.add(user)

        await db.flush()  # Flush để có user.id
        
        # Tự động tạo rating cho user mới/updated
        await ensure_user_caro_rating(db, user.id)
        
        await db.commit()
        await db.refresh(user)

    # Tạo JWT
    expires = access_token_expires()
    jwt_token = create_access_token(subject=user.id, expires_delta=expires)

    # Get user with rating
    user_public = await user_to_public(user, db)

    return TokenResponse(
        access_token=jwt_token,
        expires_in=int(expires.total_seconds()),
        user=user_public
    )
