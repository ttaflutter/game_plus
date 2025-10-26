# app/api/leaderboard.py
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, or_, and_, case, desc
from app.core.database import get_db
from app.core.security import get_current_user
from app.models.models import (
    User, Game, UserGameRating, MatchPlayer, Match, MatchStatus,
    Friend, FriendRequest, FriendRequestStatus
)
from app.schemas.leaderboard import LeaderboardEntry, UserProfileDetail
from typing import List, Optional
from datetime import datetime, timezone

router = APIRouter(prefix="/api/leaderboard", tags=["leaderboard"])

# ==== Helper Functions ====

async def get_user_stats(db: AsyncSession, user_id: int, game_id: int) -> dict:
    """Lấy thống kê wins/losses/draws của user."""
    # Đếm số trận thắng
    wins = await db.scalar(
        select(func.count())
        .select_from(MatchPlayer)
        .join(Match, Match.id == MatchPlayer.match_id)
        .where(
            MatchPlayer.user_id == user_id,
            Match.game_id == game_id,
            Match.status == MatchStatus.finished,
            MatchPlayer.is_winner == True
        )
    ) or 0
    
    # Đếm số trận thua
    losses = await db.scalar(
        select(func.count())
        .select_from(MatchPlayer)
        .join(Match, Match.id == MatchPlayer.match_id)
        .where(
            MatchPlayer.user_id == user_id,
            Match.game_id == game_id,
            Match.status == MatchStatus.finished,
            MatchPlayer.is_winner == False
        )
    ) or 0
    
    # Đếm số trận hòa (is_winner = None nhưng match finished)
    draws = await db.scalar(
        select(func.count())
        .select_from(MatchPlayer)
        .join(Match, Match.id == MatchPlayer.match_id)
        .where(
            MatchPlayer.user_id == user_id,
            Match.game_id == game_id,
            Match.status == MatchStatus.finished,
            MatchPlayer.is_winner == None
        )
    ) or 0
    
    total_games = wins + losses + draws
    win_rate = (wins / total_games * 100) if total_games > 0 else 0.0
    
    return {
        "wins": wins,
        "losses": losses,
        "draws": draws,
        "total_games": total_games,
        "win_rate": round(win_rate, 2)
    }

async def check_friendship(db: AsyncSession, user1_id: int, user2_id: int) -> bool:
    """Kiểm tra 2 người đã là bạn chưa."""
    u1, u2 = (min(user1_id, user2_id), max(user1_id, user2_id))
    friend = await db.scalar(
        select(Friend).where(Friend.user1_id == u1, Friend.user2_id == u2)
    )
    return friend is not None

async def check_pending_request(db: AsyncSession, user1_id: int, user2_id: int) -> bool:
    """Kiểm tra có lời mời đang pending không."""
    req = await db.scalar(
        select(FriendRequest).where(
            or_(
                and_(FriendRequest.sender_id == user1_id, FriendRequest.receiver_id == user2_id),
                and_(FriendRequest.sender_id == user2_id, FriendRequest.receiver_id == user1_id)
            ),
            FriendRequest.status == FriendRequestStatus.pending
        )
    )
    return req is not None

async def get_user_rank(db: AsyncSession, user_id: int, game_id: int) -> int:
    """Tính rank của user dựa trên rating."""
    # Đếm số người có rating cao hơn
    higher_count = await db.scalar(
        select(func.count())
        .select_from(UserGameRating)
        .where(
            UserGameRating.game_id == game_id,
            UserGameRating.rating > (
                select(UserGameRating.rating)
                .where(UserGameRating.user_id == user_id, UserGameRating.game_id == game_id)
            )
        )
    ) or 0
    
    return higher_count + 1

# ==== API Endpoints ====

@router.get("/", response_model=List[LeaderboardEntry])
async def get_leaderboard(
    game_name: str = Query("Caro", description="Tên game (mặc định: Caro)"),
    limit: int = Query(50, ge=1, le=100, description="Số lượng người chơi tối đa"),
    offset: int = Query(0, ge=0, description="Vị trí bắt đầu"),
    search: Optional[str] = Query(None, description="Tìm kiếm theo username"),
    current_user: Optional[User] = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Lấy bảng xếp hạng theo rating.
    
    - Sắp xếp theo rating giảm dần
    - Hiển thị rank, username, avatar, rating, wins/losses/draws
    - Hỗ trợ phân trang và tìm kiếm
    - Hiển thị trạng thái kết bạn nếu user đã đăng nhập
    """
    # Tìm game
    game = await db.scalar(select(Game).where(Game.name == game_name))
    if not game:
        raise HTTPException(404, f"Game '{game_name}' not found")
    
    # Build query
    query = (
        select(UserGameRating, User)
        .join(User, User.id == UserGameRating.user_id)
        .where(UserGameRating.game_id == game.id)
    )
    
    # Tìm kiếm theo username
    if search:
        query = query.where(User.username.ilike(f"%{search}%"))
    
    # Sắp xếp theo rating
    query = query.order_by(desc(UserGameRating.rating))
    
    # Phân trang
    query = query.offset(offset).limit(limit)
    
    # Execute
    results = await db.execute(query)
    results = results.all()
    
    # Build response
    leaderboard = []
    for idx, (rating_obj, user) in enumerate(results):
        # Tính rank thực tế (không phải index trong page)
        rank = offset + idx + 1
        
        # Lấy stats
        stats = await get_user_stats(db, user.id, game.id)
        
        # Check friendship status
        is_friend = False
        has_pending = False
        if current_user and current_user.id != user.id:
            is_friend = await check_friendship(db, current_user.id, user.id)
            has_pending = await check_pending_request(db, current_user.id, user.id)
        
        leaderboard.append(LeaderboardEntry(
            rank=rank,
            user_id=user.id,
            username=user.username,
            avatar_url=user.avatar_url,
            rating=rating_obj.rating,
            wins=stats["wins"],
            losses=stats["losses"],
            draws=stats["draws"],
            total_games=stats["total_games"],
            win_rate=stats["win_rate"],
            is_current_user= user.id == current_user.id,
            is_online=False,  # TODO: implement online status
            is_friend=is_friend,
            has_pending_request=has_pending
        ))
    
    return leaderboard

@router.get("/user/{user_id}", response_model=UserProfileDetail)
async def get_user_profile(
    user_id: int,
    game_name: str = Query("Caro", description="Tên game"),
    current_user: Optional[User] = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Lấy thông tin chi tiết của một người chơi.
    
    - Hiển thị đầy đủ thông tin: rank, rating, stats, bio
    - Lịch sử các trận đấu gần đây
    - Trạng thái kết bạn
    """
    # Tìm user
    user = await db.scalar(select(User).where(User.id == user_id))
    if not user:
        raise HTTPException(404, "User not found")
    
    # Tìm game
    game = await db.scalar(select(Game).where(Game.name == game_name))
    if not game:
        raise HTTPException(404, f"Game '{game_name}' not found")
    
    # Lấy rating
    rating_obj = await db.scalar(
        select(UserGameRating)
        .where(UserGameRating.user_id == user_id, UserGameRating.game_id == game.id)
    )
    rating = rating_obj.rating if rating_obj else 1200
    
    # Lấy rank
    rank = await get_user_rank(db, user_id, game.id)
    
    # Lấy stats
    stats = await get_user_stats(db, user_id, game.id)
    
    # Check friendship
    is_friend = False
    has_pending = False
    if current_user and current_user.id != user_id:
        is_friend = await check_friendship(db, current_user.id, user_id)
        has_pending = await check_pending_request(db, current_user.id, user_id)
    
    # Lấy recent matches (10 trận gần nhất)
    recent_matches_query = (
        select(Match, MatchPlayer)
        .join(MatchPlayer, MatchPlayer.match_id == Match.id)
        .where(
            MatchPlayer.user_id == user_id,
            Match.game_id == game.id,
            Match.status == MatchStatus.finished
        )
        .order_by(desc(Match.finished_at))
        .limit(10)
    )
    recent_results = await db.execute(recent_matches_query)
    recent_results = recent_results.all()
    
    recent_matches = []
    for match, player in recent_results:
        # Tìm opponent
        opponent_player = await db.scalar(
            select(MatchPlayer)
            .where(
                MatchPlayer.match_id == match.id,
                MatchPlayer.user_id != user_id
            )
        )
        
        if opponent_player:
            opponent = await db.scalar(select(User).where(User.id == opponent_player.user_id))
            opponent_username = opponent.username if opponent else "Unknown"
        else:
            opponent_username = "Bot/Unknown"
        
        # Xác định kết quả
        if player.is_winner == True:
            result = "win"
        elif player.is_winner == False:
            result = "loss"
        else:
            result = "draw"
        
        recent_matches.append({
            "match_id": match.id,
            "opponent_username": opponent_username,
            "result": result,
            "finished_at": match.finished_at.isoformat() if match.finished_at else None,
            "symbol": player.symbol
        })
    
    return UserProfileDetail(
        user_id=user.id,
        username=user.username,
        avatar_url=user.avatar_url,
        bio=user.bio,
        rating=rating,
        rank=rank,
        wins=stats["wins"],
        losses=stats["losses"],
        draws=stats["draws"],
        total_games=stats["total_games"],
        win_rate=stats["win_rate"],
        created_at=user.created_at,
        is_friend=is_friend,
        has_pending_request=has_pending,
        is_online=False,  # TODO: implement online status
        recent_matches=recent_matches
    )

@router.get("/my-stats", response_model=UserProfileDetail)
async def get_my_stats(
    game_name: str = Query("Caro", description="Tên game"),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Lấy thống kê của chính mình.
    """
    # Gọi lại endpoint get_user_profile với user_id của chính mình
    return await get_user_profile(current_user.id, game_name, current_user, db)

@router.get("/top/{top_n}", response_model=List[LeaderboardEntry])
async def get_top_players(
    top_n: int,
    game_name: str = Query("Caro", description="Tên game"),
    current_user: Optional[User] = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Lấy top N người chơi hàng đầu.
    
    Ví dụ: /api/leaderboard/top/10 để lấy top 10
    """
    if top_n < 1 or top_n > 100:
        raise HTTPException(400, "top_n must be between 1 and 100")
    
    return await get_leaderboard(
        game_name=game_name,
        limit=top_n,
        offset=0,
        search=None,
        current_user=current_user,
        db=db
    )
