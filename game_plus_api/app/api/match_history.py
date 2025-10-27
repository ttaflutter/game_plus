# app/api/match_history.py
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_, or_, desc, func
from app.core.database import get_db
from app.core.security import get_current_user
from app.models.models import (
    User, Game, Match, MatchPlayer, Move, MatchStatus, UserGameRating
)
from app.schemas.match_history import (
    MatchHistoryItem, MatchDetailResponse, MoveDetail, 
    PlayerInfo, MatchHistoryFilter
)
from typing import List, Optional
from datetime import datetime, timezone

router = APIRouter(prefix="/api/match-history", tags=["match-history"])

# ==== Helper Functions ====

def build_board_from_moves(moves: List[Move], rows: int, cols: int) -> List[List[Optional[str]]]:
    """Xây dựng ma trận bàn cờ từ danh sách moves."""
    # Khởi tạo board rỗng
    board = [[None for _ in range(cols)] for _ in range(rows)]
    
    # Đặt từng nước đi lên board
    for move in moves:
        if 0 <= move.x < rows and 0 <= move.y < cols:
            board[move.x][move.y] = move.symbol
    
    return board

def find_winning_line(board: List[List[Optional[str]]], win_len: int) -> Optional[List[dict]]:
    """
    Tìm đường thắng trên bàn cờ.
    Returns: List of coordinates [{"x": 0, "y": 0}, ...] hoặc None
    """
    rows = len(board)
    cols = len(board[0]) if rows > 0 else 0
    
    # Check horizontal
    for r in range(rows):
        for c in range(cols - win_len + 1):
            symbol = board[r][c]
            if symbol and all(board[r][c + i] == symbol for i in range(win_len)):
                return [{"x": r, "y": c + i} for i in range(win_len)]
    
    # Check vertical
    for r in range(rows - win_len + 1):
        for c in range(cols):
            symbol = board[r][c]
            if symbol and all(board[r + i][c] == symbol for i in range(win_len)):
                return [{"x": r + i, "y": c} for i in range(win_len)]
    
    # Check diagonal (top-left to bottom-right)
    for r in range(rows - win_len + 1):
        for c in range(cols - win_len + 1):
            symbol = board[r][c]
            if symbol and all(board[r + i][c + i] == symbol for i in range(win_len)):
                return [{"x": r + i, "y": c + i} for i in range(win_len)]
    
    # Check diagonal (top-right to bottom-left)
    for r in range(rows - win_len + 1):
        for c in range(win_len - 1, cols):
            symbol = board[r][c]
            if symbol and all(board[r + i][c - i] == symbol for i in range(win_len)):
                return [{"x": r + i, "y": c - i} for i in range(win_len)]
    
    return None

def calculate_duration(started_at: Optional[datetime], finished_at: Optional[datetime]) -> Optional[int]:
    """Tính thời gian chơi (giây)."""
    if started_at and finished_at:
        return int((finished_at - started_at).total_seconds())
    return None

# ==== API Endpoints ====

@router.get("/my-matches", response_model=List[MatchHistoryItem])
async def get_my_match_history(
    game_name: str = Query("Caro", description="Tên game"),
    status: Optional[str] = Query(None, description="Filter theo status (finished, abandoned, etc.)"),
    result: Optional[str] = Query(None, description="Filter theo kết quả (win, loss, draw)"),
    limit: int = Query(10, ge=1, le=50, description="Số lượng trận tối đa"),
    offset: int = Query(0, ge=0, description="Vị trí bắt đầu"),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Lấy lịch sử đấu của người dùng hiện tại.
    
    - Hiển thị 10 trận gần nhất (có thể tùy chỉnh)
    - Filter theo status và result
    - Sắp xếp theo thời gian mới nhất
    """
    # Tìm game
    game = await db.scalar(select(Game).where(Game.name == game_name))
    if not game:
        raise HTTPException(404, f"Game '{game_name}' not found")
    
    # Build query
    query = (
        select(Match, MatchPlayer)
        .join(MatchPlayer, MatchPlayer.match_id == Match.id)
        .where(
            MatchPlayer.user_id == current_user.id,
            Match.game_id == game.id
        )
    )
    
    # Filter theo status
    if status:
        try:
            match_status = MatchStatus(status)
            query = query.where(Match.status == match_status)
        except ValueError:
            raise HTTPException(400, f"Invalid status: {status}")
    
    # Filter theo result (win/loss/draw)
    if result:
        result_lower = result.lower()
        if result_lower == "win":
            query = query.where(MatchPlayer.is_winner == True)
        elif result_lower in ["loss", "lose"]:  # Accept both "loss" and "lose"
            query = query.where(MatchPlayer.is_winner == False)
        elif result_lower == "draw":
            query = query.where(MatchPlayer.is_winner == None, Match.status == MatchStatus.finished)
        else:
            raise HTTPException(400, f"Invalid result: {result}. Must be 'win', 'loss' (or 'lose'), or 'draw'")
    
    # Sắp xếp và phân trang
    query = query.order_by(desc(Match.created_at)).offset(offset).limit(limit)
    
    # Execute
    results = await db.execute(query)
    results = results.all()
    
    # Build response
    history = []
    for match, my_player in results:
        # Tìm opponent
        opponent_player = await db.scalar(
            select(MatchPlayer)
            .where(
                MatchPlayer.match_id == match.id,
                MatchPlayer.user_id != current_user.id
            )
        )
        
        if opponent_player:
            opponent = await db.scalar(select(User).where(User.id == opponent_player.user_id))
            opponent_username = opponent.username if opponent else "Unknown"
            opponent_avatar = opponent.avatar_url if opponent else None
            opponent_symbol = opponent_player.symbol
        else:
            opponent_username = "Bot/Unknown"
            opponent_avatar = None
            opponent_symbol = "O" if my_player.symbol == "X" else "X"
        
        # Xác định result
        result_str = None
        if match.status == MatchStatus.finished:
            if my_player.is_winner == True:
                result_str = "win"
            elif my_player.is_winner == False:
                result_str = "loss"
            else:
                result_str = "draw"
        
        # Đếm số nước đi
        total_moves = await db.scalar(
            select(func.count()).select_from(Move).where(Move.match_id == match.id)
        ) or 0
        
        # Tính duration
        duration = calculate_duration(match.started_at, match.finished_at)
        
        history.append(MatchHistoryItem(
            match_id=match.id,
            game_name=game.name,
            status=match.status.value,
            result=result_str,
            opponent_username=opponent_username,
            opponent_avatar_url=opponent_avatar,
            opponent_symbol=opponent_symbol,
            my_symbol=my_player.symbol,
            board_rows=match.board_rows,
            board_cols=match.board_cols,
            total_moves=total_moves,
            created_at=match.created_at,
            started_at=match.started_at,
            finished_at=match.finished_at,
            duration_seconds=duration
        ))
    
    return history

@router.get("/user/{user_id}", response_model=List[MatchHistoryItem])
async def get_user_match_history(
    user_id: int,
    game_name: str = Query("Caro", description="Tên game"),
    status: Optional[str] = Query(None, description="Filter theo status"),
    result: Optional[str] = Query(None, description="Filter theo kết quả"),
    limit: int = Query(10, ge=1, le=50, description="Số lượng trận tối đa"),
    offset: int = Query(0, ge=0, description="Vị trí bắt đầu"),
    current_user: Optional[User] = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Lấy lịch sử đấu của một người chơi khác.
    
    - Xem lịch sử đấu của bất kỳ người chơi nào
    - Hiển thị từ góc nhìn của người chơi đó
    """
    # Kiểm tra user tồn tại
    user = await db.scalar(select(User).where(User.id == user_id))
    if not user:
        raise HTTPException(404, "User not found")
    
    # Tìm game
    game = await db.scalar(select(Game).where(Game.name == game_name))
    if not game:
        raise HTTPException(404, f"Game '{game_name}' not found")
    
    # Build query (giống như my-matches nhưng với user_id khác)
    query = (
        select(Match, MatchPlayer)
        .join(MatchPlayer, MatchPlayer.match_id == Match.id)
        .where(
            MatchPlayer.user_id == user_id,
            Match.game_id == game.id
        )
    )
    
    # Filter
    if status:
        try:
            match_status = MatchStatus(status)
            query = query.where(Match.status == match_status)
        except ValueError:
            raise HTTPException(400, f"Invalid status: {status}")
    
    if result:
        result_lower = result.lower()
        if result_lower == "win":
            query = query.where(MatchPlayer.is_winner == True)
        elif result_lower in ["loss", "lose"]:  # Accept both "loss" and "lose"
            query = query.where(MatchPlayer.is_winner == False)
        elif result_lower == "draw":
            query = query.where(MatchPlayer.is_winner == None, Match.status == MatchStatus.finished)
        else:
            raise HTTPException(400, f"Invalid result: {result}. Must be 'win', 'loss' (or 'lose'), or 'draw'")
    
    # Sắp xếp và phân trang
    query = query.order_by(desc(Match.created_at)).offset(offset).limit(limit)
    
    # Execute
    results = await db.execute(query)
    results = results.all()
    
    # Build response
    history = []
    for match, player in results:
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
            opponent_avatar = opponent.avatar_url if opponent else None
            opponent_symbol = opponent_player.symbol
        else:
            opponent_username = "Bot/Unknown"
            opponent_avatar = None
            opponent_symbol = "O" if player.symbol == "X" else "X"
        
        # Xác định result
        result_str = None
        if match.status == MatchStatus.finished:
            if player.is_winner == True:
                result_str = "win"
            elif player.is_winner == False:
                result_str = "loss"
            else:
                result_str = "draw"
        
        # Đếm số nước đi
        total_moves = await db.scalar(
            select(func.count()).select_from(Move).where(Move.match_id == match.id)
        ) or 0
        
        # Tính duration
        duration = calculate_duration(match.started_at, match.finished_at)
        
        history.append(MatchHistoryItem(
            match_id=match.id,
            game_name=game.name,
            status=match.status.value,
            result=result_str,
            opponent_username=opponent_username,
            opponent_avatar_url=opponent_avatar,
            opponent_symbol=opponent_symbol,
            my_symbol=player.symbol,
            board_rows=match.board_rows,
            board_cols=match.board_cols,
            total_moves=total_moves,
            created_at=match.created_at,
            started_at=match.started_at,
            finished_at=match.finished_at,
            duration_seconds=duration
        ))
    
    return history

@router.get("/match/{match_id}", response_model=MatchDetailResponse)
async def get_match_detail(
    match_id: int,
    current_user: Optional[User] = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Lấy chi tiết đầy đủ của một trận đấu.
    
    - Danh sách tất cả nước đi (moves)
    - Ma trận bàn cờ
    - Thông tin 2 người chơi
    - Đường thắng (winning line) nếu có
    """
    # Tìm match
    match = await db.scalar(select(Match).where(Match.id == match_id))
    if not match:
        raise HTTPException(404, "Match not found")
    
    # Lấy game info
    game = await db.scalar(select(Game).where(Game.id == match.game_id))
    game_name = game.name if game else "Unknown"
    
    # Lấy thông tin players
    players_query = await db.execute(
        select(MatchPlayer, User)
        .join(User, User.id == MatchPlayer.user_id)
        .where(MatchPlayer.match_id == match_id)
    )
    players_data = players_query.all()
    
    players_info = []
    for player, user in players_data:
        # Lấy rating (nếu có)
        rating_before = None
        rating_after = None
        # TODO: Implement rating tracking if needed
        
        players_info.append(PlayerInfo(
            user_id=user.id,
            username=user.username,
            avatar_url=user.avatar_url,
            symbol=player.symbol,
            is_winner=player.is_winner,
            rating_before=rating_before,
            rating_after=rating_after
        ))
    
    # Lấy tất cả moves
    moves_query = await db.execute(
        select(Move, User)
        .join(User, User.id == Move.user_id)
        .where(Move.match_id == match_id)
        .order_by(Move.turn_no)
    )
    moves_data = moves_query.all()
    
    moves_list = []
    moves_objects = []
    for move, user in moves_data:
        moves_list.append(MoveDetail(
            turn_no=move.turn_no,
            user_id=user.id,
            username=user.username,
            x=move.x,
            y=move.y,
            symbol=move.symbol,
            made_at=move.made_at
        ))
        moves_objects.append(move)
    
    # Xây dựng board từ moves
    board = build_board_from_moves(moves_objects, match.board_rows, match.board_cols)
    
    # Tìm winning line
    winning_line = None
    if match.status == MatchStatus.finished:
        winning_line = find_winning_line(board, match.win_len)
    
    # Tính duration
    duration = calculate_duration(match.started_at, match.finished_at)
    
    return MatchDetailResponse(
        match_id=match.id,
        game_name=game_name,
        status=match.status.value,
        board_rows=match.board_rows,
        board_cols=match.board_cols,
        win_len=match.win_len,
        created_at=match.created_at,
        started_at=match.started_at,
        finished_at=match.finished_at,
        duration_seconds=duration,
        players=players_info,
        moves=moves_list,
        board=board,
        winning_line=winning_line
    )

@router.get("/stats/summary")
async def get_match_stats_summary(
    game_name: str = Query("Caro", description="Tên game"),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Lấy tổng hợp thống kê nhanh.
    
    - Tổng số trận
    - Số trận thắng/thua/hòa
    - Win rate
    - Trận gần nhất
    """
    # Tìm game
    game = await db.scalar(select(Game).where(Game.name == game_name))
    if not game:
        raise HTTPException(404, f"Game '{game_name}' not found")
    
    # Đếm tổng số trận
    total_matches = await db.scalar(
        select(func.count())
        .select_from(MatchPlayer)
        .join(Match, Match.id == MatchPlayer.match_id)
        .where(
            MatchPlayer.user_id == current_user.id,
            Match.game_id == game.id,
            Match.status == MatchStatus.finished
        )
    ) or 0
    
    # Đếm wins
    wins = await db.scalar(
        select(func.count())
        .select_from(MatchPlayer)
        .join(Match, Match.id == MatchPlayer.match_id)
        .where(
            MatchPlayer.user_id == current_user.id,
            Match.game_id == game.id,
            Match.status == MatchStatus.finished,
            MatchPlayer.is_winner == True
        )
    ) or 0
    
    # Đếm losses
    losses = await db.scalar(
        select(func.count())
        .select_from(MatchPlayer)
        .join(Match, Match.id == MatchPlayer.match_id)
        .where(
            MatchPlayer.user_id == current_user.id,
            Match.game_id == game.id,
            Match.status == MatchStatus.finished,
            MatchPlayer.is_winner == False
        )
    ) or 0
    
    # Đếm draws
    draws = await db.scalar(
        select(func.count())
        .select_from(MatchPlayer)
        .join(Match, Match.id == MatchPlayer.match_id)
        .where(
            MatchPlayer.user_id == current_user.id,
            Match.game_id == game.id,
            Match.status == MatchStatus.finished,
            MatchPlayer.is_winner == None
        )
    ) or 0
    
    # Tính win rate
    win_rate = (wins / total_matches * 100) if total_matches > 0 else 0.0
    
    # Lấy trận gần nhất
    latest_match = await db.execute(
        select(Match)
        .join(MatchPlayer, MatchPlayer.match_id == Match.id)
        .where(
            MatchPlayer.user_id == current_user.id,
            Match.game_id == game.id
        )
        .order_by(desc(Match.created_at))
        .limit(1)
    )
    latest_match = latest_match.scalar_one_or_none()
    
    return {
        "total_matches": total_matches,
        "wins": wins,
        "losses": losses,
        "draws": draws,
        "win_rate": round(win_rate, 2),
        "latest_match_id": latest_match.id if latest_match else None,
        "latest_match_date": latest_match.created_at.isoformat() if latest_match else None
    }
