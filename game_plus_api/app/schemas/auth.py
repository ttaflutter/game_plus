from pydantic import BaseModel, EmailStr, HttpUrl, field_validator
from typing import Optional, Literal
from app.schemas.user import UserPublic  # Import from user.py to get rating field

# ---------- Requests ----------
class RegisterRequest(BaseModel):
    username: str
    email: EmailStr
    password: Optional[str] = None
    provider: Literal["local", "google"] = "local"
    provider_id: Optional[str] = None
    avatar_url: Optional[HttpUrl] = None
    bio: Optional[str] = None

    @field_validator("password")
    @classmethod
    def password_required_for_local(cls, v, info):
        provider = info.data.get("provider", "local")
        if provider == "local" and not v:
            raise ValueError("Password is required for local registration")
        return v

class LoginRequest(BaseModel):
    email: EmailStr
    password: str

# ---------- Responses ----------
# Note: UserPublic is now imported from app.schemas.user to include rating field

class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    expires_in: int
    user: UserPublic

class LoginGoogleRequest(BaseModel):
    email: EmailStr
    name: Optional[str] = None
    avatar_url: Optional[HttpUrl] = None
    sub: str
