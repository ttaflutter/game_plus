# app/schemas/leaderboard.py
from pydantic import BaseModel, ConfigDict
from typing import Optional
from datetime import datetime

class LeaderboardEntry(BaseModel):
    """Schema cho một entry trong bảng xếp hạng."""
    model_config = ConfigDict(from_attributes=True)
    
    rank: int
    user_id: int
    username: str
    avatar_url: Optional[str] = None
    rating: int
    wins: int
    losses: int
    draws: int
    total_games: int
    win_rate: float
    is_online: bool = False
    is_friend: bool = False
    is_current_user: bool = False
    has_pending_request: bool = False

class UserProfileDetail(BaseModel):
    """Schema cho thông tin chi tiết người dùng khi click vào profile."""
    model_config = ConfigDict(from_attributes=True)
    
    user_id: int
    username: str
    avatar_url: Optional[str] = None
    bio: Optional[str] = None
    rating: int
    rank: int
    wins: int
    losses: int
    draws: int
    total_games: int
    win_rate: float
    created_at: datetime
    is_friend: bool = False
    has_pending_request: bool = False
    is_online: bool = False
    
    # Recent match history
    recent_matches: list = []

class LeaderboardFilter(BaseModel):
    """Filter options cho leaderboard."""
    game_name: str = "Caro"
    limit: int = 50
    offset: int = 0
    search_username: Optional[str] = None
