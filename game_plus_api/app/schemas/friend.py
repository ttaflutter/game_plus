from pydantic import BaseModel, ConfigDict
from datetime import datetime
from typing import Optional

# ==== Friend Request Schemas ====

class FriendRequestCreate(BaseModel):
    """Request để gửi lời mời kết bạn."""
    receiver_username: str

class FriendRequestResponse(BaseModel):
    """Response của friend request với thông tin người gửi/nhận."""
    id: int
    sender_id: int
    receiver_id: int
    status: str
    created_at: datetime
    
    # Thông tin người gửi
    sender_username: str
    sender_avatar_url: Optional[str] = None
    
    # Thông tin người nhận
    receiver_username: str
    receiver_avatar_url: Optional[str] = None
    
    model_config = ConfigDict(from_attributes=True)

class FriendRequestAction(BaseModel):
    """Action để accept/reject friend request."""
    action: str  # "accept" hoặc "reject"

# ==== Friend Schemas ====

class FriendResponse(BaseModel):
    """Response của friend với thông tin bạn bè."""
    id: int
    user_id: int
    username: str
    avatar_url: Optional[str] = None
    rating: Optional[int] = 1200  # Rating Caro mặc định
    is_online: bool = False  # TODO: implement online status
    created_at: datetime  # Thời điểm kết bạn
    
    model_config = ConfigDict(from_attributes=True)

class SearchUserResponse(BaseModel):
    """Response khi search user để thêm bạn."""
    id: int
    username: str
    avatar_url: Optional[str] = None
    rating: Optional[int] = 1200
    is_friend: bool = False
    has_pending_request: bool = False
    
    model_config = ConfigDict(from_attributes=True)

# ==== Challenge Schemas ====

class ChallengeCreate(BaseModel):
    """Request để gửi thách đấu."""
    opponent_id: int
    message: Optional[str] = None

class ChallengeResponse(BaseModel):
    """Response của challenge với thông tin đầy đủ."""
    id: int
    challenger_id: int
    opponent_id: int
    game_id: int
    match_id: Optional[int] = None
    status: str
    message: Optional[str] = None
    created_at: datetime
    expires_at: Optional[datetime] = None
    
    # Thông tin challenger
    challenger_username: str
    challenger_avatar_url: Optional[str] = None
    challenger_rating: Optional[int] = 1200
    
    # Thông tin opponent
    opponent_username: str
    opponent_avatar_url: Optional[str] = None
    opponent_rating: Optional[int] = 1200
    
    model_config = ConfigDict(from_attributes=True)

class ChallengeAction(BaseModel):
    """Action để accept/reject challenge."""
    action: str  # "accept" hoặc "reject"
