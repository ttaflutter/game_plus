# app/api/rooms.py
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, or_, and_, delete
from app.core.database import get_db
from app.core.security import get_current_user, hash_password, verify_password
from app.models.models import (
    Room, RoomPlayer, RoomStatus, User, Game, Match, MatchStatus, 
    MatchPlayer, UserGameRating
)
from app.schemas.room import (
    CreateRoomRequest, JoinRoomRequest, RoomDetail, RoomListItem,
    PlayerInRoom, ReadyToggleRequest, KickPlayerRequest
)
from datetime import datetime, timezone
from typing import List, Optional
import random
import string

router = APIRouter(prefix="/api/rooms", tags=["rooms"])

# Import broadcast function from realtime
async def notify_room_change(room: Room, db: AsyncSession, action: str = "update"):
    """Helper để broadcast room changes qua WebSocket."""
    try:
        from app.api.realtime import broadcast_room_update
        from app.api.realtime_helpers import invalidate_rooms_cache
        
        # ✅ Invalidate cache khi có thay đổi
        await invalidate_rooms_cache()
        
        # ✅ EXTRACT tất cả giá trị TRƯỚC khi gọi broadcast
        room_id = room.id
        room_name = room.room_name
        room_code = room.room_code
        game_id = room.game_id
        host_id = room.host_id
        max_players = room.max_players
        status = room.status.value if hasattr(room.status, "value") else str(room.status)
        is_public = room.is_public
        created_at = room.created_at.isoformat() if room.created_at else None
        
        # ✅ Query game_name và host_username từ DB (không dùng lazy load)
        from app.models.models import User, Game
        from sqlalchemy import select
        
        game_name = None
        if game_id:
            game = await db.scalar(select(Game.name).where(Game.id == game_id))
            game_name = game
        
        host_username = None
        if host_id:
            host = await db.scalar(select(User.username).where(User.id == host_id))
            host_username = host
        
        # ✅ Query player count từ DB (không dùng lazy load)
        from app.models.models import RoomPlayer
        from sqlalchemy import func
        player_count = await db.scalar(
            select(func.count()).select_from(RoomPlayer).where(RoomPlayer.room_id == room_id)
        ) or 0
        
        # ✅ Tạo room_data với giá trị đã extract
        room_data = {
            "id": room_id,
            "name": room_name,
            "room_code": room_code,
            "game_id": game_id,
            "game_name": game_name,
            "host_id": host_id,
            "host_username": host_username,
            "max_players": max_players,
            "current_players": player_count,
            "status": status,
            "is_private": not is_public,
            "created_at": created_at,
        }
        
        await broadcast_room_update(room_data, action)
        print(f"✅ Broadcast {action} for room {room_id} successfully")
        
    except Exception as e:
        print(f"⚠️ Failed to broadcast room change: {e}")
        import traceback
        traceback.print_exc()

# ==== Helper Functions ====

def generate_room_code() -> str:
    """Tạo mã phòng 6 ký tự ngẫu nhiên."""
    return ''.join(random.choices(string.ascii_uppercase + string.digits, k=6))

async def get_room_or_404(room_id: int, db: AsyncSession) -> Room:
    """Lấy room hoặc raise 404."""
    from sqlalchemy.orm import selectinload
    
    # Eagerly load relationships để tránh lazy loading issues
    room = await db.scalar(
        select(Room)
        .where(Room.id == room_id)
        .options(selectinload(Room.host), selectinload(Room.game))
    )
    if not room:
        raise HTTPException(404, "Room not found")
    return room

async def check_is_host(room: Room, user_id: int):
    """Kiểm tra user có phải host không."""
    if room.host_id != user_id:
        raise HTTPException(403, "Only host can perform this action")

async def build_room_detail(room: Room, db: AsyncSession) -> RoomDetail:
    """Build RoomDetail với thông tin players."""
    # Lấy game_id trước để tránh lazy loading issues
    game_id = room.game_id
    room_id = room.id
    host_id = room.host_id
    
    # Lấy players
    players_query = await db.execute(
        select(RoomPlayer, User, UserGameRating.rating)
        .join(User, User.id == RoomPlayer.user_id)
        .outerjoin(
            UserGameRating,
            and_(
                UserGameRating.user_id == User.id,
                UserGameRating.game_id == game_id
            )
        )
        .where(RoomPlayer.room_id == room_id)
        .order_by(RoomPlayer.joined_at.asc())
    )
    
    players_data = []
    for rp, user, rating in players_query.all():
        players_data.append(PlayerInRoom(
            user_id=user.id,
            username=user.username,
            avatar_url=user.avatar_url,
            rating=rating if rating is not None else 1200,
            is_ready=rp.is_ready,
            is_host=(user.id == room.host_id),
            joined_at=rp.joined_at
        ))
    
    return RoomDetail(
        id=room.id,
        room_code=room.room_code,
        room_name=room.room_name,
        host_id=room.host_id,
        status=room.status.value,
        is_public=room.is_public,
        has_password=room.password is not None,
        max_players=room.max_players,
        current_players=len(players_data),
        board_rows=room.board_rows,
        board_cols=room.board_cols,
        win_len=room.win_len,
        created_at=room.created_at,
        players=players_data,
        match_id=room.match_id
    )

# ==== API Endpoints ====

@router.post("/create", response_model=RoomDetail)
async def create_room(
    data: CreateRoomRequest,
    current_user = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Tạo phòng chơi mới.
    
    - Host tự động join và là người chơi đầu tiên
    - Tạo room code 6 ký tự unique
    - Password optional
    """
    # Lấy game Caro
    game = await db.scalar(select(Game).where(Game.name == "Caro"))
    if not game:
        raise HTTPException(404, "Game 'Caro' not found")
    
    # Tạo room code unique
    room_code = generate_room_code()
    while await db.scalar(select(Room).where(Room.room_code == room_code)):
        room_code = generate_room_code()
    
    # Hash password nếu có
    hashed_password = None
    if data.password:
        hashed_password = hash_password(data.password)
    
    # Tạo room
    room = Room(
        room_code=room_code,
        room_name=data.room_name,
        host_id=current_user.id,
        game_id=game.id,
        password=hashed_password,
        is_public=data.is_public,
        max_players=data.max_players,
        board_rows=data.board_rows,
        board_cols=data.board_cols,
        win_len=data.win_len,
        status=RoomStatus.waiting,
        created_at=datetime.now(timezone.utc)
    )
    db.add(room)
    await db.flush()
    
    # Host tự động join
    room_player = RoomPlayer(
        room_id=room.id,
        user_id=current_user.id,
        is_ready=True,  # Host sẵn sàng mặc định
        joined_at=datetime.now(timezone.utc)
    )
    db.add(room_player)
    await db.commit()
    await db.refresh(room)
    
    # Broadcast room created qua WebSocket
    await notify_room_change(room, db, "created")
    
    return await build_room_detail(room, db)

@router.get("/list", response_model=List[RoomListItem])
async def list_rooms(
    status: Optional[str] = None,
    only_public: bool = True,
    skip: int = 0,
    limit: int = 20,
    db: AsyncSession = Depends(get_db)
):
    """
    Danh sách phòng công khai.
    
    - Filter theo status (waiting, playing, finished)
    - Mặc định chỉ lấy phòng công khai
    - Pagination
    """
    query = select(Room, User.username).join(User, User.id == Room.host_id)
    
    if only_public:
        query = query.where(Room.is_public == True)
    
    if status:
        try:
            status_enum = RoomStatus(status)
            query = query.where(Room.status == status_enum)
        except ValueError:
            raise HTTPException(400, f"Invalid status: {status}")
    
    query = query.order_by(Room.created_at.desc()).offset(skip).limit(limit)
    
    result = await db.execute(query)
    rooms_data = result.all()
    
    # Count players cho mỗi room
    room_ids = [room.id for room, _ in rooms_data]
    player_counts = {}
    if room_ids:
        counts_query = await db.execute(
            select(RoomPlayer.room_id, func.count(RoomPlayer.user_id))
            .where(RoomPlayer.room_id.in_(room_ids))
            .group_by(RoomPlayer.room_id)
        )
        player_counts = dict(counts_query.all())
    
    result_list = []
    for room, host_username in rooms_data:
        result_list.append(RoomListItem(
            id=room.id,
            room_code=room.room_code,
            room_name=room.room_name,
            host_username=host_username,
            status=room.status.value,
            is_public=room.is_public,
            has_password=room.password is not None,
            current_players=player_counts.get(room.id, 0),
            max_players=room.max_players,
            created_at=room.created_at
        ))
    
    return result_list

@router.get("/{room_id}", response_model=RoomDetail)
async def get_room_detail(
    room_id: int,
    current_user = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Xem chi tiết phòng."""
    room = await get_room_or_404(room_id, db)
    return await build_room_detail(room, db)

@router.post("/join", response_model=RoomDetail)
async def join_room(
    data: JoinRoomRequest,
    current_user = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Tham gia phòng bằng room code.
    
    - Kiểm tra password nếu có
    - Kiểm tra phòng còn chỗ không
    - Kiểm tra đã join chưa
    """
    # Tìm room theo code
    room = await db.scalar(
        select(Room).where(Room.room_code == data.room_code.upper())
    )
    if not room:
        raise HTTPException(404, "Room not found with this code")
    
    # Kiểm tra status
    if room.status != RoomStatus.waiting:
        raise HTTPException(400, "Room is not accepting new players")
    
    # Kiểm tra password
    if room.password:
        if not data.password:
            raise HTTPException(401, "Password required")
        if not verify_password(data.password, room.password):
            raise HTTPException(401, "Incorrect password")
    
    # Đếm số người chơi hiện tại
    current_count = await db.scalar(
        select(func.count(RoomPlayer.user_id))
        .where(RoomPlayer.room_id == room.id)
    ) or 0
    
    if current_count >= room.max_players:
        raise HTTPException(400, "Room is full")
    
    # Kiểm tra đã join chưa
    exists = await db.scalar(
        select(RoomPlayer)
        .where(RoomPlayer.room_id == room.id, RoomPlayer.user_id == current_user.id)
    )
    if exists:
        raise HTTPException(400, "You already joined this room")
    
    # Join room
    room_player = RoomPlayer(
        room_id=room.id,
        user_id=current_user.id,
        is_ready=False,
        joined_at=datetime.now(timezone.utc)
    )
    db.add(room_player)
    await db.commit()
    
    # Refresh room để tránh expired state
    await db.refresh(room)
    
    # Broadcast room updated qua WebSocket
    await notify_room_change(room, db, "update")
    
    return await build_room_detail(room, db)

@router.post("/{room_id}/ready")
async def toggle_ready(
    room_id: int,
    data: ReadyToggleRequest,
    current_user = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Toggle trạng thái ready.
    
    - Host luôn ready
    - Player khác có thể toggle
    """
    room = await get_room_or_404(room_id, db)
    
    if room.status != RoomStatus.waiting:
        raise HTTPException(400, "Room is not in waiting state")
    
    # Lấy RoomPlayer
    room_player = await db.scalar(
        select(RoomPlayer)
        .where(RoomPlayer.room_id == room_id, RoomPlayer.user_id == current_user.id)
    )
    if not room_player:
        raise HTTPException(404, "You are not in this room")
    
    # Host luôn ready
    if current_user.id == room.host_id:
        return {"message": "Host is always ready", "is_ready": True}
    
    # Update ready status
    new_ready_status = data.is_ready
    room_player.is_ready = new_ready_status
    await db.commit()
    
    # Refresh room để broadcast
    await db.refresh(room)
    
    # Broadcast room updated qua WebSocket
    await notify_room_change(room, db, "update")
    
    return {
        "message": "Ready status updated",
        "is_ready": new_ready_status
    }

@router.post("/{room_id}/kick")
async def kick_player(
    room_id: int,
    data: KickPlayerRequest,
    current_user = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Kick người chơi khỏi phòng (chỉ host).
    
    - Không thể kick chính mình
    """
    room = await get_room_or_404(room_id, db)
    await check_is_host(room, current_user.id)
    
    if room.status != RoomStatus.waiting:
        raise HTTPException(400, "Can only kick players in waiting room")
    
    if data.user_id == current_user.id:
        raise HTTPException(400, "Cannot kick yourself")
    
    # Xóa player
    result = await db.execute(
        delete(RoomPlayer)
        .where(RoomPlayer.room_id == room_id, RoomPlayer.user_id == data.user_id)
    )
    
    if result.rowcount == 0:
        raise HTTPException(404, "Player not found in room")
    
    await db.commit()
    
    # Refresh room để broadcast
    await db.refresh(room)
    
    # Broadcast room updated qua WebSocket
    await notify_room_change(room, db, "update")
    
    return {
        "message": "Player kicked successfully",
        "kicked_user_id": data.user_id
    }

@router.post("/{room_id}/leave")
async def leave_room(
    room_id: int,
    current_user = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Rời khỏi phòng.
    
    - Nếu host rời -> phòng bị xóa
    - Player khác rời -> xóa khỏi danh sách
    """
    room = await get_room_or_404(room_id, db)
    
    if room.status != RoomStatus.waiting:
        raise HTTPException(400, "Cannot leave room while playing")
    
    # Nếu là host -> xóa phòng
    if current_user.id == room.host_id:
        await db.delete(room)
        await db.commit()
        return {
            "message": "Room deleted (host left)",
            "room_deleted": True
        }
    
    # Xóa player
    result = await db.execute(
        delete(RoomPlayer)
        .where(RoomPlayer.room_id == room_id, RoomPlayer.user_id == current_user.id)
    )
    
    if result.rowcount == 0:
        raise HTTPException(404, "You are not in this room")
    
    await db.commit()
    
    return {
        "message": "Left room successfully",
        "room_deleted": False
    }

@router.post("/{room_id}/start")
async def start_game(
    room_id: int,
    current_user = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Bắt đầu game (chỉ host).
    
    - Kiểm tra tất cả players đã ready
    - Tạo Match mới
    - Update room status -> playing
    """
    room = await get_room_or_404(room_id, db)
    await check_is_host(room, current_user.id)
    
    if room.status != RoomStatus.waiting:
        raise HTTPException(400, "Room is not in waiting state")
    
    # Lấy tất cả players
    players_query = await db.execute(
        select(RoomPlayer)
        .where(RoomPlayer.room_id == room_id)
    )
    players = players_query.scalars().all()
    
    if len(players) < 2:
        raise HTTPException(400, "Need at least 2 players to start")
    
    # Kiểm tra tất cả đã ready (trừ host - host luôn ready)
    for player in players:
        if player.user_id != room.host_id and not player.is_ready:
            raise HTTPException(400, "Not all players are ready")
    
    # Tạo Match
    match = Match(
        game_id=room.game_id,
        board_rows=room.board_rows,
        board_cols=room.board_cols,
        win_len=room.win_len,
        status=MatchStatus.waiting,  # Sẽ chuyển playing khi join WebSocket
        created_at=datetime.now(timezone.utc)
    )
    db.add(match)
    await db.flush()
    
    # Thêm players vào match với symbol X, O
    symbols = ["X", "O", "A", "B"]  # Hỗ trợ tối đa 4 players
    for idx, player in enumerate(players[:room.max_players]):
        match_player = MatchPlayer(
            match_id=match.id,
            user_id=player.user_id,
            symbol=symbols[idx],
            joined_at=datetime.now(timezone.utc)
        )
        db.add(match_player)
    
    # Update room
    room.status = RoomStatus.playing
    room.match_id = match.id
    room.started_at = datetime.now(timezone.utc)
    
    # Lưu các giá trị trước khi commit
    match_id = match.id
    room_id = room.id
    
    await db.commit()
    
    # Refresh room để broadcast
    await db.refresh(room)
    
    # Broadcast room updated (status -> playing, không còn hiện trong list)
    await notify_room_change(room, db, "update")
    
    return {
        "message": "Game started successfully",
        "match_id": match_id,
        "room_id": room_id,
        "websocket_url": f"/ws/match/{match_id}"
    }

@router.delete("/{room_id}")
async def delete_room(
    room_id: int,
    current_user = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Xóa phòng (chỉ host).
    
    - Chỉ xóa được khi đang waiting
    """
    room = await get_room_or_404(room_id, db)
    await check_is_host(room, current_user.id)
    
    if room.status != RoomStatus.waiting:
        raise HTTPException(400, "Can only delete room in waiting state")
    
    # Broadcast room deleted trước khi xóa
    await notify_room_change(room, db, "deleted")
    
    await db.delete(room)
    await db.commit()
    
    return {
        "message": "Room deleted successfully",
        "room_id": room_id
    }
