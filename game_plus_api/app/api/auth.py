from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from jose import jwt, JWTError

from app.core.database import get_db
from app.core.security import hash_password, verify_password, create_access_token
from app.core.config import access_token_expires, SECRET_KEY, ALGORITHM
from app.schemas.auth import RegisterRequest, LoginRequest, TokenResponse, UserPublic
from app.models.models import User

router = APIRouter(prefix="/api/auth", tags=["Auth"])

# ---------- Helpers ----------
async def get_user_by_email(db: AsyncSession, email: str) -> User | None:
    res = await db.execute(select(User).where(User.email == email))
    return res.scalar_one_or_none()

async def get_user_by_id(db: AsyncSession, user_id: int) -> User | None:
    res = await db.execute(select(User).where(User.id == user_id))
    return res.scalar_one_or_none()

# ---------- Endpoints ----------
@router.post("/register", response_model=TokenResponse, status_code=201)
async def register(payload: RegisterRequest, db: AsyncSession = Depends(get_db)):
    # Check duplicates
    if await get_user_by_email(db, payload.email):
        raise HTTPException(status_code=400, detail="Email already registered")

    # username unique
    res = await db.execute(select(User).where(User.username == payload.username))
    if res.scalar_one_or_none():
        raise HTTPException(status_code=400, detail="Username already taken")

    # Create user
    user = User(
        username=payload.username,
        email=payload.email,
        hashed_password=hash_password(payload.password) if payload.provider == "local" else None,
        avatar_url=str(payload.avatar_url) if payload.avatar_url else None,
        bio=payload.bio,
        provider=payload.provider,
        provider_id=payload.provider_id,
    )
    db.add(user)
    await db.commit()
    await db.refresh(user)

    # Issue token
    expires = access_token_expires()
    token = create_access_token(subject=user.id, expires_delta=expires)

    return TokenResponse(
        access_token=token,
        expires_in=int(expires.total_seconds()),
        user=UserPublic(id=user.id, username=user.username, email=user.email, avatar_url=user.avatar_url, provider=user.provider),
    )

@router.post("/login", response_model=TokenResponse)
async def login(payload: LoginRequest, db: AsyncSession = Depends(get_db)):
    user = await get_user_by_email(db, payload.email)
    if not user or not verify_password(payload.password, user.hashed_password):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid credentials")

    expires = access_token_expires()
    token = create_access_token(subject=user.id, expires_delta=expires)

    return TokenResponse(
        access_token=token,
        expires_in=int(expires.total_seconds()),
        user=UserPublic(id=user.id, username=user.username, email=user.email, avatar_url=user.avatar_url, provider=user.provider),
    )

# OAuth2-style Bearer token dependency
from fastapi.security import OAuth2PasswordBearer
from fastapi import Request

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/auth/login")  # FE dùng JSON; tokenUrl chỉ để docs

async def get_current_user(token: str = Depends(oauth2_scheme), db: AsyncSession = Depends(get_db)) -> User:
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        user_id: str | None = payload.get("sub")
        if user_id is None:
            raise credentials_exception
    except JWTError:
        raise credentials_exception

    user = await get_user_by_id(db, int(user_id))
    if user is None:
        raise credentials_exception
    return user

@router.get("/me", response_model=UserPublic)
async def me(current_user: User = Depends(get_current_user)):
    return UserPublic(
        id=current_user.id,
        username=current_user.username,
        email=current_user.email,
        avatar_url=current_user.avatar_url,
        provider=current_user.provider,
    )
