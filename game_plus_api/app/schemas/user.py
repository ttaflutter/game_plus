from pydantic import BaseModel, EmailStr, HttpUrl
from typing import Optional

class UserPublic(BaseModel):
    id: int
    username: str
    email: EmailStr
    avatar_url: Optional[HttpUrl] = None
    provider: str
    bio: Optional[str] = None
    class Config:
        orm_mode = True

class UserUpdate(BaseModel):
    username: Optional[str]
    bio: Optional[str]
    avatar_url: Optional[HttpUrl]
