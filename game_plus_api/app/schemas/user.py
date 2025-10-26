from pydantic import BaseModel, EmailStr, HttpUrl, ConfigDict, Field
from typing import Optional
from datetime import datetime

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
    username: Optional[str] = Field(None, min_length=3, max_length=50)
    bio: Optional[str] = Field(None, max_length=500)
    avatar_url: Optional[str] = None  # Changed to string to accept any URL format

class UserProfileDetail(BaseModel):
    """Chi tiết profile đầy đủ cho Profile Screen."""
    model_config = ConfigDict(from_attributes=True)
    
    id: int
    username: str
    email: EmailStr
    avatar_url: Optional[str] = None
    bio: Optional[str] = None
    provider: str
    created_at: datetime
    
    # Game stats
    rating: int
    total_matches: int
    wins: int
    losses: int
    draws: int
    win_rate: float
    
    # Friend stats
    total_friends: int

class ChangePasswordRequest(BaseModel):
    """Request để đổi mật khẩu."""
    old_password: str = Field(..., min_length=6)
    new_password: str = Field(..., min_length=6)

class UpdateAvatarRequest(BaseModel):
    """Request để update avatar."""
    avatar_url: str = Field(..., description="URL của avatar mới")

class NotificationSettings(BaseModel):
    """Cài đặt thông báo."""
    friend_requests: bool = True
    challenges: bool = True
    match_updates: bool = True
    chat_messages: bool = True

class UserSettings(BaseModel):
    """Cài đặt người dùng."""
    notifications: NotificationSettings = NotificationSettings()
    language: str = "vi"
    theme: str = "light"  # light, dark, auto

