from sqlalchemy import (
    Column, Integer, String, Text, ForeignKey, TIMESTAMP, func, Boolean,
    Enum as SAEnum, CheckConstraint, UniqueConstraint, Index
)
from sqlalchemy.orm import relationship
from enum import Enum
from app.core.database import Base

# ==== EXISTING (giữ nguyên) ===================================================
class User(Base):
    __tablename__ = "users"
    id = Column(Integer, primary_key=True, index=True)
    username = Column(String(50), unique=True, nullable=False)
    email = Column(String(100), unique=True, nullable=False)
    hashed_password = Column(Text, nullable=True)
    avatar_url = Column(Text, nullable=True)
    bio = Column(Text, nullable=True)
    provider = Column(String(50), default="local")
    provider_id = Column(String(255), nullable=True)
    created_at = Column(TIMESTAMP(timezone=True), server_default=func.now())
    updated_at = Column(TIMESTAMP(timezone=True), server_default=func.now(), onupdate=func.now())

    scores = relationship("Score", back_populates="user", cascade="all, delete")
    # new: rating theo game
    ratings = relationship("UserGameRating", back_populates="user", cascade="all, delete")
    # new: tham gia các trận
    match_links = relationship("MatchPlayer", back_populates="user", cascade="all, delete")

class Game(Base):
    __tablename__ = "games"
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(100), unique=True, nullable=False)
    description = Column(Text, nullable=True)
    thumbnail_url = Column(Text, nullable=True)
    created_at = Column(TIMESTAMP(timezone=True), server_default=func.now())

    scores = relationship("Score", back_populates="game", cascade="all, delete")
    ratings = relationship("UserGameRating", back_populates="game", cascade="all, delete")
    matches = relationship("Match", back_populates="game", cascade="all, delete")

class Score(Base):
    __tablename__ = "scores"
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"))
    game_id = Column(Integer, ForeignKey("games.id", ondelete="CASCADE"))
    score = Column(Integer, default=0)
    play_time = Column(Integer, default=0)
    played_at = Column(TIMESTAMP(timezone=True), server_default=func.now())

    user = relationship("User", back_populates="scores")
    game = relationship("Game", back_populates="scores")

# ==== NEW FOR CARO ============================================================

class MatchStatus(str, Enum):
    waiting = "waiting"
    playing = "playing"
    finished = "finished"
    abandoned = "abandoned"

class Match(Base):
    """
    Một phòng/cặp đấu Caro.
    """
    __tablename__ = "matches"

    id = Column(Integer, primary_key=True, index=True)
    game_id = Column(Integer, ForeignKey("games.id", ondelete="CASCADE"), nullable=False)
    board_rows = Column(Integer, nullable=False, default=15)
    board_cols = Column(Integer, nullable=False, default=19)
    win_len = Column(Integer, nullable=False, default=5)
    status = Column(SAEnum(MatchStatus), nullable=False, default=MatchStatus.waiting)
    created_at = Column(TIMESTAMP(timezone=True), server_default=func.now())
    started_at = Column(TIMESTAMP(timezone=True))
    finished_at = Column(TIMESTAMP(timezone=True))

    # relationships
    game = relationship("Game", back_populates="matches")
    players = relationship("MatchPlayer", back_populates="match", cascade="all, delete-orphan")
    moves = relationship("Move", back_populates="match", cascade="all, delete-orphan")

    __table_args__ = (
        CheckConstraint("board_rows >= 5 AND board_cols >= 5", name="ck_board_min_size"),
        CheckConstraint("win_len BETWEEN 3 AND 10", name="ck_win_len_range"),
        Index("ix_matches_game_status", "game_id", "status"),
    )

class MatchPlayer(Base):
    """
    Liên kết người chơi - trận, + symbol X/O, winner flag.
    """
    __tablename__ = "match_players"

    match_id = Column(Integer, ForeignKey("matches.id", ondelete="CASCADE"), primary_key=True)
    user_id  = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), primary_key=True)
    symbol   = Column(String(1), nullable=False)  # 'X' hoặc 'O'
    is_winner = Column(Boolean, default=None)     # None khi chưa kết thúc
    joined_at = Column(TIMESTAMP(timezone=True), server_default=func.now())

    match = relationship("Match", back_populates="players")
    user  = relationship("User", back_populates="match_links")

    __table_args__ = (
        CheckConstraint("symbol IN ('X','O')", name="ck_symbol_only_xo"),
        UniqueConstraint("match_id", "symbol", name="uq_match_symbol_once"),  # 1 symbol chỉ 1 người
        Index("ix_match_players_user", "user_id"),
    )

class Move(Base):
    """
    Nước đi trong trận: lưu toạ độ, lượt thứ, symbol.
    """
    __tablename__ = "moves"

    id = Column(Integer, primary_key=True)
    match_id = Column(Integer, ForeignKey("matches.id", ondelete="CASCADE"), nullable=False, index=True)
    turn_no = Column(Integer, nullable=False)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    x = Column(Integer, nullable=False)  # row index (0..board_rows-1)
    y = Column(Integer, nullable=False)  # col index (0..board_cols-1)
    symbol = Column(String(1), nullable=False)  # 'X' | 'O'
    made_at = Column(TIMESTAMP(timezone=True), server_default=func.now())

    match = relationship("Match", back_populates="moves")
    user  = relationship("User")  # không cần back_populates

    __table_args__ = (
        CheckConstraint("symbol IN ('X','O')", name="ck_move_symbol_only_xo"),
        UniqueConstraint("match_id", "x", "y", name="uq_cell_once"),           # 1 ô chỉ đánh 1 lần
        UniqueConstraint("match_id", "turn_no", name="uq_turn_once"),          # mỗi lượt duy nhất
        Index("ix_moves_match_turn", "match_id", "turn_no"),
    )

class UserGameRating(Base):
    """
    ELO/Rating theo từng game (tuỳ chọn nhưng rất hữu ích cho leaderboard).
    """
    __tablename__ = "user_game_ratings"

    id = Column(Integer, primary_key=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    game_id = Column(Integer, ForeignKey("games.id", ondelete="CASCADE"), nullable=False)
    rating = Column(Integer, nullable=False, default=1000)
    wins = Column(Integer, nullable=False, default=0)
    losses = Column(Integer, nullable=False, default=0)
    draws = Column(Integer, nullable=False, default=0)
    updated_at = Column(TIMESTAMP(timezone=True), server_default=func.now(), onupdate=func.now())

    user = relationship("User", back_populates="ratings")
    game = relationship("Game", back_populates="ratings")

    __table_args__ = (
        UniqueConstraint("user_id", "game_id", name="uq_user_game_rating_once"),
        Index("ix_rating_game_rating", "game_id", "rating"),
    )

# ==== FRIEND SYSTEM ===========================================================

class FriendRequestStatus(str, Enum):
    pending = "pending"
    accepted = "accepted"
    rejected = "rejected"

class FriendRequest(Base):
    """
    Lời mời kết bạn: sender gửi cho receiver.
    """
    __tablename__ = "friend_requests"

    id = Column(Integer, primary_key=True)
    sender_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    receiver_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    status = Column(SAEnum(FriendRequestStatus), nullable=False, default=FriendRequestStatus.pending)
    created_at = Column(TIMESTAMP(timezone=True), server_default=func.now())
    updated_at = Column(TIMESTAMP(timezone=True), server_default=func.now(), onupdate=func.now())

    sender = relationship("User", foreign_keys=[sender_id])
    receiver = relationship("User", foreign_keys=[receiver_id])

    __table_args__ = (
        # Không cho gửi 2 lời mời cùng lúc giữa 2 người
        UniqueConstraint("sender_id", "receiver_id", name="uq_friend_request_once"),
        Index("ix_friend_requests_receiver_status", "receiver_id", "status"),
        Index("ix_friend_requests_sender", "sender_id"),
        CheckConstraint("sender_id != receiver_id", name="ck_no_self_friend_request"),
    )

class Friend(Base):
    """
    Quan hệ bạn bè (2 chiều): user1 <-> user2.
    Để tránh duplicate, ta luôn lưu user_id nhỏ hơn làm user1_id.
    """
    __tablename__ = "friends"

    id = Column(Integer, primary_key=True)
    user1_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    user2_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    created_at = Column(TIMESTAMP(timezone=True), server_default=func.now())

    user1 = relationship("User", foreign_keys=[user1_id])
    user2 = relationship("User", foreign_keys=[user2_id])

    __table_args__ = (
        UniqueConstraint("user1_id", "user2_id", name="uq_friendship_once"),
        Index("ix_friends_user1", "user1_id"),
        Index("ix_friends_user2", "user2_id"),
        CheckConstraint("user1_id < user2_id", name="ck_user1_less_than_user2"),
    )

# ==== CHALLENGE SYSTEM ========================================================

class ChallengeStatus(str, Enum):
    pending = "pending"
    accepted = "accepted"
    rejected = "rejected"
    expired = "expired"

class Challenge(Base):
    """
    Thách đấu: challenger mời opponent chơi một trận.
    """
    __tablename__ = "challenges"

    id = Column(Integer, primary_key=True)
    challenger_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    opponent_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    game_id = Column(Integer, ForeignKey("games.id", ondelete="CASCADE"), nullable=False)
    match_id = Column(Integer, ForeignKey("matches.id", ondelete="SET NULL"), nullable=True)  # Match được tạo khi accept
    status = Column(SAEnum(ChallengeStatus), nullable=False, default=ChallengeStatus.pending)
    message = Column(Text, nullable=True)  # Tin nhắn thách đấu
    created_at = Column(TIMESTAMP(timezone=True), server_default=func.now())
    updated_at = Column(TIMESTAMP(timezone=True), server_default=func.now(), onupdate=func.now())
    expires_at = Column(TIMESTAMP(timezone=True), nullable=True)  # Challenge tự động expire sau X phút

    challenger = relationship("User", foreign_keys=[challenger_id])
    opponent = relationship("User", foreign_keys=[opponent_id])
    game = relationship("Game")
    match = relationship("Match")

    __table_args__ = (
        Index("ix_challenges_opponent_status", "opponent_id", "status"),
        Index("ix_challenges_challenger", "challenger_id"),
        CheckConstraint("challenger_id != opponent_id", name="ck_no_self_challenge"),
    )

# ==== ROOM SYSTEM =============================================================

class RoomStatus(str, Enum):
    waiting = "waiting"
    playing = "playing"
    finished = "finished"

class Room(Base):
    """
    Phòng chơi với room code, host, password optional.
    """
    __tablename__ = "rooms"

    id = Column(Integer, primary_key=True)
    room_code = Column(String(6), unique=True, nullable=False, index=True)  # Mã 6 ký tự
    room_name = Column(String(100), nullable=False)
    host_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    game_id = Column(Integer, ForeignKey("games.id", ondelete="CASCADE"), nullable=False)
    
    # Room settings
    password = Column(String(255), nullable=True)  # Hash của password nếu có
    is_public = Column(Boolean, default=True)
    max_players = Column(Integer, default=2)
    board_rows = Column(Integer, default=15)
    board_cols = Column(Integer, default=19)
    win_len = Column(Integer, default=5)
    
    # Status
    status = Column(SAEnum(RoomStatus), nullable=False, default=RoomStatus.waiting)
    match_id = Column(Integer, ForeignKey("matches.id", ondelete="SET NULL"), nullable=True)
    
    # Timestamps
    created_at = Column(TIMESTAMP(timezone=True), server_default=func.now())
    started_at = Column(TIMESTAMP(timezone=True), nullable=True)
    finished_at = Column(TIMESTAMP(timezone=True), nullable=True)

    # Relationships
    host = relationship("User", foreign_keys=[host_id])
    game = relationship("Game")
    match = relationship("Match")
    players = relationship("RoomPlayer", back_populates="room", cascade="all, delete-orphan")

    __table_args__ = (
        CheckConstraint("max_players >= 2 AND max_players <= 4", name="ck_room_max_players"),
        Index("ix_rooms_status", "status"),
        Index("ix_rooms_host", "host_id"),
    )

class RoomPlayer(Base):
    """
    Người chơi trong phòng với trạng thái ready.
    """
    __tablename__ = "room_players"

    room_id = Column(Integer, ForeignKey("rooms.id", ondelete="CASCADE"), primary_key=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), primary_key=True)
    is_ready = Column(Boolean, default=False)
    joined_at = Column(TIMESTAMP(timezone=True), server_default=func.now())

    room = relationship("Room", back_populates="players")
    user = relationship("User")

    __table_args__ = (
        Index("ix_room_players_user", "user_id"),
    )
