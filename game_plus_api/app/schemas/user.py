from pydantic import BaseModel, EmailStr, HttpUrl, ConfigDict
from typing import Optional

class UserPublic(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    
    id: int
    username: str
    email: EmailStr
    avatar_url: Optional[HttpUrl] = None
    provider: str
    bio: Optional[str] = None
    rating: Optional[int] = None  # Caro game rating

class UserUpdate(BaseModel):
    username: Optional[str]
    bio: Optional[str]
    avatar_url: Optional[HttpUrl]
