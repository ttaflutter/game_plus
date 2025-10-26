# app/schemas/match_history.py
from pydantic import BaseModel, ConfigDict
from typing import Optional, List
from datetime import datetime

class MoveDetail(BaseModel):
    """Chi tiết một nước đi."""
    model_config = ConfigDict(from_attributes=True)
    
    turn_no: int
    user_id: int
    username: str
    x: int  # row
    y: int  # col
    symbol: str  # 'X' or 'O'
    made_at: datetime

class PlayerInfo(BaseModel):
    """Thông tin người chơi trong trận."""
    user_id: int
    username: str
    avatar_url: Optional[str] = None
    symbol: str  # 'X' or 'O'
    is_winner: Optional[bool] = None
    rating_before: Optional[int] = None
    rating_after: Optional[int] = None

class MatchHistoryItem(BaseModel):
    """Item trong danh sách lịch sử đấu."""
    model_config = ConfigDict(from_attributes=True)
    
    match_id: int
    game_name: str
    status: str  # 'waiting', 'playing', 'finished', 'abandoned'
    result: Optional[str] = None  # 'win', 'loss', 'draw' (từ góc nhìn của user)
    opponent_username: str
    opponent_avatar_url: Optional[str] = None
    opponent_symbol: str
    my_symbol: str
    board_rows: int
    board_cols: int
    total_moves: int
    created_at: datetime
    started_at: Optional[datetime] = None
    finished_at: Optional[datetime] = None
    duration_seconds: Optional[int] = None  # Thời gian chơi (giây)

class MatchDetailResponse(BaseModel):
    """Chi tiết đầy đủ của một trận đấu."""
    model_config = ConfigDict(from_attributes=True)
    
    match_id: int
    game_name: str
    status: str
    board_rows: int
    board_cols: int
    win_len: int
    created_at: datetime
    started_at: Optional[datetime] = None
    finished_at: Optional[datetime] = None
    duration_seconds: Optional[int] = None
    
    # Thông tin người chơi
    players: List[PlayerInfo]
    
    # Danh sách nước đi
    moves: List[MoveDetail]
    
    # Ma trận bàn cờ (để hiển thị trạng thái cuối cùng)
    board: List[List[Optional[str]]]  # 2D array, mỗi ô là 'X', 'O', hoặc None
    
    # Winning line (nếu có)
    winning_line: Optional[List[dict]] = None  # [{"x": 0, "y": 0}, {"x": 0, "y": 1}, ...]

class MatchHistoryFilter(BaseModel):
    """Filter cho match history."""
    game_name: str = "Caro"
    status: Optional[str] = None  # 'finished', 'abandoned', etc.
    result: Optional[str] = None  # 'win', 'loss', 'draw'
    limit: int = 10
    offset: int = 0
