from pydantic import BaseModel
from typing import Optional

class ScoreCreate(BaseModel):
    game_id: int
    score: int
    play_time: Optional[int] = 0

class ScorePublic(BaseModel):
    id: int
    user_id: int
    game_id: int
    score: int
    play_time: int
    class Config:
        orm_mode = True

class LeaderboardEntry(BaseModel):
    username: str
    high_score: int
    plays: int
