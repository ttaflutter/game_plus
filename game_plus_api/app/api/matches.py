from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, insert, update, desc, func
from app.core.database import get_db
from app.models.models import Match, MatchPlayer, Game, MatchStatus, User, UserGameRating, Move
from app.core.security import get_current_user
from datetime import datetime, timezone
from typing import List, Optional

router = APIRouter(prefix="/api/matches", tags=["matches"])


@router.post("/join")
async def quick_join_match(
    db: AsyncSession = Depends(get_db),
    current_user=Depends(get_current_user)
):
    # Lấy game Caro
    game = await db.scalar(select(Game).where(Game.name == "Caro"))
    if not game:
        raise HTTPException(status_code=404, detail="Game 'Caro' not found")

    # Tìm trận đang chờ
    match = await db.scalar(
        select(Match)
        .where(Match.game_id == game.id)
        .where(Match.status == MatchStatus.waiting)
    )

    match_id = None
    match_status = MatchStatus.waiting
    board_info = "15x19"

    # Nếu chưa có -> tạo mới
    if not match:
        new_match = Match(
            game_id=game.id,
            board_rows=15,
            board_cols=19,
            win_len=5,
            status=MatchStatus.waiting,
            created_at=datetime.now(timezone.utc),
        )
        db.add(new_match)
        await db.flush()
        match_id = new_match.id
    else:
        match_id = match.id

    # Kiểm tra người chơi đã trong match chưa
    exists = await db.scalar(
        select(MatchPlayer).where(
            MatchPlayer.match_id == match_id,
            MatchPlayer.user_id == current_user.id,
        )
    )
    
    if not exists:
        # X hoặc O tùy người đến trước
        current_players = await db.execute(
            select(MatchPlayer).where(MatchPlayer.match_id == match_id)
        )
        player_count = len(current_players.all())
        symbol = "X" if player_count == 0 else "O"

        db.add(MatchPlayer(
            match_id=match_id,
            user_id=current_user.id,
            symbol=symbol
        ))

        # Nếu đã có 2 người → bắt đầu trận
        if player_count + 1 == 2:
            match_status = MatchStatus.playing
            await db.execute(
                update(Match)
                .where(Match.id == match_id)
                .values(
                    status=MatchStatus.playing,
                    started_at=datetime.now(timezone.utc)
                )
            )

        await db.commit()

    return {
        "match_id": match_id,
        "status": match_status,
        "board": board_info
    }


@router.get("/history")
async def get_match_history(
    limit: int = Query(10, ge=1, le=100),
    offset: int = Query(0, ge=0),
    db: AsyncSession = Depends(get_db),
    current_user=Depends(get_current_user)
):
    """Lấy lịch sử các trận đấu của user."""
    # Lấy các trận của user
    query = (
        select(Match, MatchPlayer)
        .join(MatchPlayer, MatchPlayer.match_id == Match.id)
        .where(MatchPlayer.user_id == current_user.id)
        .order_by(Match.created_at.desc())
        .limit(limit)
        .offset(offset)
    )
    
    result = await db.execute(query)
    matches_data = result.all()
    
    history = []
    for match, player in matches_data:
        # Lấy thông tin đối thủ
        opponent = await db.scalar(
            select(MatchPlayer)
            .where(
                MatchPlayer.match_id == match.id,
                MatchPlayer.user_id != current_user.id
            )
        )
        
        opponent_info = None
        if opponent:
            opponent_user = await db.scalar(
                select(User).where(User.id == opponent.user_id)
            )
            if opponent_user:
                opponent_info = {
                    "user_id": opponent_user.id,
                    "username": opponent_user.username,
                    "avatar_url": opponent_user.avatar_url,
                    "symbol": opponent.symbol
                }
        
        # Xác định kết quả
        result_text = "draw"
        if player.is_winner is True:
            result_text = "win"
        elif player.is_winner is False:
            result_text = "loss"
        
        history.append({
            "match_id": match.id,
            "status": match.status.value if hasattr(match.status, "value") else str(match.status),
            "result": result_text,
            "your_symbol": player.symbol,
            "opponent": opponent_info,
            "created_at": match.created_at.isoformat() if match.created_at else None,
            "finished_at": match.finished_at.isoformat() if match.finished_at else None,
        })
    
    return {"history": history, "total": len(history)}


@router.get("/{match_id}")
async def get_match_detail(
    match_id: int,
    db: AsyncSession = Depends(get_db),
    current_user=Depends(get_current_user)
):
    """Lấy chi tiết một trận đấu bao gồm replay."""
    match = await db.scalar(select(Match).where(Match.id == match_id))
    if not match:
        raise HTTPException(status_code=404, detail="Match not found")
    
    # Lấy danh sách players
    players_result = await db.execute(
        select(MatchPlayer, User)
        .join(User, User.id == MatchPlayer.user_id)
        .where(MatchPlayer.match_id == match_id)
    )
    players_data = players_result.all()
    
    players = []
    for mp, user in players_data:
        players.append({
            "user_id": user.id,
            "username": user.username,
            "avatar_url": user.avatar_url,
            "symbol": mp.symbol,
            "is_winner": mp.is_winner
        })
    
    # Lấy các nước đi
    moves_result = await db.execute(
        select(Move)
        .where(Move.match_id == match_id)
        .order_by(Move.turn_no.asc())
    )
    moves = moves_result.scalars().all()
    
    moves_list = [
        {
            "turn_no": m.turn_no,
            "user_id": m.user_id,
            "x": m.x,
            "y": m.y,
            "symbol": m.symbol,
            "made_at": m.made_at.isoformat() if m.made_at else None
        }
        for m in moves
    ]
    
    return {
        "match_id": match.id,
        "status": match.status.value if hasattr(match.status, "value") else str(match.status),
        "board_size": f"{match.board_rows}x{match.board_cols}",
        "win_len": match.win_len,
        "players": players,
        "moves": moves_list,
        "created_at": match.created_at.isoformat() if match.created_at else None,
        "started_at": match.started_at.isoformat() if match.started_at else None,
        "finished_at": match.finished_at.isoformat() if match.finished_at else None,
    }


@router.get("/leaderboard/caro")
async def get_leaderboard(
    limit: int = Query(50, ge=1, le=100),
    offset: int = Query(0, ge=0),
    db: AsyncSession = Depends(get_db)
):
    """Bảng xếp hạng game Caro."""
    # Lấy game Caro
    game = await db.scalar(select(Game).where(Game.name == "Caro"))
    if not game:
        raise HTTPException(status_code=404, detail="Game 'Caro' not found")
    
    # Lấy top users theo rating
    query = (
        select(UserGameRating, User)
        .join(User, User.id == UserGameRating.user_id)
        .where(UserGameRating.game_id == game.id)
        .order_by(UserGameRating.rating.desc())
        .limit(limit)
        .offset(offset)
    )
    
    result = await db.execute(query)
    leaderboard_data = result.all()
    
    leaderboard = []
    for idx, (rating, user) in enumerate(leaderboard_data, start=offset + 1):
        total_games = rating.wins + rating.losses + rating.draws
        win_rate = (rating.wins / total_games * 100) if total_games > 0 else 0
        
        leaderboard.append({
            "rank": idx,
            "user_id": user.id,
            "username": user.username,
            "avatar_url": user.avatar_url,
            "rating": rating.rating,
            "wins": rating.wins,
            "losses": rating.losses,
            "draws": rating.draws,
            "total_games": total_games,
            "win_rate": round(win_rate, 1)
        })
    
    return {"leaderboard": leaderboard}


@router.get("/stats/me")
async def get_my_stats(
    db: AsyncSession = Depends(get_db),
    current_user=Depends(get_current_user)
):
    """Thống kê của bản thân."""
    # Lấy game Caro
    game = await db.scalar(select(Game).where(Game.name == "Caro"))
    if not game:
        raise HTTPException(status_code=404, detail="Game 'Caro' not found")
    
    # Lấy rating
    rating = await db.scalar(
        select(UserGameRating).where(
            UserGameRating.user_id == current_user.id,
            UserGameRating.game_id == game.id
        )
    )
    
    if not rating:
        return {
            "rating": 1000,
            "wins": 0,
            "losses": 0,
            "draws": 0,
            "total_games": 0,
            "win_rate": 0.0,
            "rank": None
        }
    
    total_games = rating.wins + rating.losses + rating.draws
    win_rate = (rating.wins / total_games * 100) if total_games > 0 else 0
    
    # Tính rank
    rank_result = await db.scalar(
        select(func.count())
        .select_from(UserGameRating)
        .where(
            UserGameRating.game_id == game.id,
            UserGameRating.rating > rating.rating
        )
    )
    rank = (rank_result or 0) + 1
    
    return {
        "rating": rating.rating,
        "wins": rating.wins,
        "losses": rating.losses,
        "draws": rating.draws,
        "total_games": total_games,
        "win_rate": round(win_rate, 1),
        "rank": rank
    }


@router.get("/rating/{user_id}")
async def get_user_rating(
    user_id: int,
    db: AsyncSession = Depends(get_db)
):
    """Lấy rating của một user cụ thể."""
    # Lấy game Caro
    game = await db.scalar(select(Game).where(Game.name == "Caro"))
    if not game:
        raise HTTPException(status_code=404, detail="Game 'Caro' not found")
    
    # Lấy user info
    user = await db.scalar(select(User).where(User.id == user_id))
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    # Lấy rating
    rating = await db.scalar(
        select(UserGameRating).where(
            UserGameRating.user_id == user_id,
            UserGameRating.game_id == game.id
        )
    )
    
    if not rating:
        return {
            "user_id": user_id,
            "username": user.username,
            "avatar_url": user.avatar_url,
            "rating": 1000,
            "wins": 0,
            "losses": 0,
            "draws": 0,
            "total_games": 0,
            "win_rate": 0.0,
            "rank": None
        }
    
    total_games = rating.wins + rating.losses + rating.draws
    win_rate = (rating.wins / total_games * 100) if total_games > 0 else 0
    
    # Tính rank
    rank_result = await db.scalar(
        select(func.count())
        .select_from(UserGameRating)
        .where(
            UserGameRating.game_id == game.id,
            UserGameRating.rating > rating.rating
        )
    )
    rank = (rank_result or 0) + 1
    
    return {
        "user_id": user_id,
        "username": user.username,
        "avatar_url": user.avatar_url,
        "rating": rating.rating,
        "wins": rating.wins,
        "losses": rating.losses,
        "draws": rating.draws,
        "total_games": total_games,
        "win_rate": round(win_rate, 1),
        "rank": rank
    }