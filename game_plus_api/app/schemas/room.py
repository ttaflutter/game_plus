# app/schemas/room.py
from pydantic import BaseModel, Field, ConfigDict
from typing import Optional, List
from datetime import datetime

class CreateRoomRequest(BaseModel):
    """Tạo phòng chơi mới."""
    room_name: str = Field(..., min_length=1, max_length=100, description="Tên phòng")
    password: Optional[str] = Field(None, max_length=50, description="Mật khẩu phòng (optional)")
    max_players: int = Field(2, ge=2, le=4, description="Số người chơi tối đa")
    board_rows: int = Field(15, ge=10, le=20, description="Số hàng")
    board_cols: int = Field(19, ge=10, le=25, description="Số cột")
    win_len: int = Field(5, ge=3, le=7, description="Số quân liên tiếp để thắng")
    is_public: bool = Field(True, description="Phòng công khai hay riêng tư")

class JoinRoomRequest(BaseModel):
    """Tham gia phòng."""
    room_code: str = Field(..., min_length=6, max_length=6, description="Mã phòng 6 ký tự")
    password: Optional[str] = Field(None, description="Mật khẩu nếu phòng có mật khẩu")

class PlayerInRoom(BaseModel):
    """Thông tin người chơi trong phòng."""
    user_id: int
    username: str
    avatar_url: Optional[str]
    rating: int
    is_ready: bool
    is_host: bool
    joined_at: datetime
    
    model_config = ConfigDict(from_attributes=True)

class RoomDetail(BaseModel):
    """Chi tiết phòng chơi."""
    id: int
    room_code: str
    room_name: str
    host_id: int
    status: str  # waiting | playing | finished
    is_public: bool
    has_password: bool
    max_players: int
    current_players: int
    board_rows: int
    board_cols: int
    win_len: int
    created_at: datetime
    players: List[PlayerInRoom] = []
    match_id: Optional[int] = None  # ID của match khi game bắt đầu
    
    model_config = ConfigDict(from_attributes=True)

class RoomListItem(BaseModel):
    """Item trong danh sách phòng."""
    id: int
    room_code: str
    room_name: str
    host_username: str
    status: str
    is_public: bool
    has_password: bool
    current_players: int
    max_players: int
    created_at: datetime
    
    model_config = ConfigDict(from_attributes=True)

class ReadyToggleRequest(BaseModel):
    """Toggle trạng thái ready."""
    is_ready: bool

class KickPlayerRequest(BaseModel):
    """Kick người chơi khỏi phòng."""
    user_id: int = Field(..., description="ID người chơi cần kick")
