# app/api/friends.py
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, or_, and_, func
from app.core.database import get_db
from app.core.security import get_current_user
from app.models.models import (
    User, Friend, FriendRequest, FriendRequestStatus, 
    UserGameRating, Game, Challenge, ChallengeStatus,
    Match, MatchStatus, MatchPlayer
)
from app.schemas.friend import (
    FriendRequestCreate, FriendRequestResponse, FriendRequestAction,
    FriendResponse, SearchUserResponse,
    ChallengeCreate, ChallengeResponse, ChallengeAction
)
from typing import List
from datetime import datetime, timezone, timedelta

router = APIRouter(prefix="/api/friends", tags=["friends"])

# ==== Helper Functions ====

def normalize_friendship(user1_id: int, user2_id: int):
    """Đảm bảo user1_id < user2_id để tránh duplicate."""
    return (min(user1_id, user2_id), max(user1_id, user2_id))

async def get_user_rating(db: AsyncSession, user_id: int) -> int:
    """Lấy rating Caro của user."""
    game = await db.scalar(select(Game).where(Game.name == "Caro"))
    if not game:
        return 1200
    
    rating_obj = await db.scalar(
        select(UserGameRating.rating)
        .where(UserGameRating.user_id == user_id)
        .where(UserGameRating.game_id == game.id)
    )
    return rating_obj if rating_obj is not None else 1200

async def check_friendship(db: AsyncSession, user1_id: int, user2_id: int) -> bool:
    """Kiểm tra 2 người đã là bạn chưa."""
    u1, u2 = normalize_friendship(user1_id, user2_id)
    friend = await db.scalar(
        select(Friend).where(Friend.user1_id == u1, Friend.user2_id == u2)
    )
    return friend is not None

async def check_pending_request(db: AsyncSession, user1_id: int, user2_id: int) -> bool:
    """Kiểm tra có lời mời đang pending không (cả 2 chiều)."""
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

# ==== Search Users ====

@router.get("/search", response_model=List[SearchUserResponse])
async def search_users(
    query: str = Query(..., min_length=1),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Tìm user theo username để thêm bạn.
    Không trả về chính mình.
    """
    # Search users by username (case-insensitive)
    users = await db.execute(
        select(User)
        .where(User.username.ilike(f"%{query}%"))
        .where(User.id != current_user.id)
        .limit(20)
    )
    users = users.scalars().all()
    
    result = []
    for user in users:
        # Check friendship
        is_friend = await check_friendship(db, current_user.id, user.id)
        
        # Check pending request
        has_pending = await check_pending_request(db, current_user.id, user.id)
        
        # Get rating
        rating = await get_user_rating(db, user.id)
        
        result.append(SearchUserResponse(
            id=user.id,
            username=user.username,
            avatar_url=user.avatar_url,
            rating=rating,
            is_friend=is_friend,
            has_pending_request=has_pending
        ))
    
    return result

# ==== Friend Requests ====

@router.post("/requests", response_model=FriendRequestResponse)
async def send_friend_request(
    data: FriendRequestCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Gửi lời mời kết bạn."""
    # Tìm receiver
    receiver = await db.scalar(
        select(User).where(User.username == data.receiver_username)
    )
    if not receiver:
        raise HTTPException(404, "User not found")
    
    if receiver.id == current_user.id:
        raise HTTPException(400, "Cannot send friend request to yourself")
    
    # Kiểm tra đã là bạn chưa
    if await check_friendship(db, current_user.id, receiver.id):
        raise HTTPException(400, "Already friends")
    
    # Kiểm tra đã có request pending chưa (cả 2 chiều)
    existing = await db.scalar(
        select(FriendRequest).where(
            or_(
                and_(FriendRequest.sender_id == current_user.id, FriendRequest.receiver_id == receiver.id),
                and_(FriendRequest.sender_id == receiver.id, FriendRequest.receiver_id == current_user.id)
            ),
            FriendRequest.status == FriendRequestStatus.pending
        )
    )
    if existing:
        raise HTTPException(400, "Friend request already pending")
    
    # Kiểm tra có request cũ bị rejected không -> xóa đi để gửi lại
    old_request = await db.scalar(
        select(FriendRequest).where(
            FriendRequest.sender_id == current_user.id,
            FriendRequest.receiver_id == receiver.id,
            FriendRequest.status.in_([FriendRequestStatus.rejected, FriendRequestStatus.accepted])
        )
    )
    if old_request:
        await db.delete(old_request)
        await db.flush()  # Flush để xóa trước khi insert
    
    # Tạo friend request
    friend_request = FriendRequest(
        sender_id=current_user.id,
        receiver_id=receiver.id,
        status=FriendRequestStatus.pending
    )
    db.add(friend_request)
    await db.commit()
    await db.refresh(friend_request)
    
    return FriendRequestResponse(
        id=friend_request.id,
        sender_id=current_user.id,
        receiver_id=receiver.id,
        status=friend_request.status.value,
        created_at=friend_request.created_at,
        sender_username=current_user.username,
        sender_avatar_url=current_user.avatar_url,
        receiver_username=receiver.username,
        receiver_avatar_url=receiver.avatar_url
    )

@router.get("/requests/received", response_model=List[FriendRequestResponse])
async def get_received_requests(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Lấy danh sách lời mời kết bạn nhận được (pending)."""
    requests = await db.execute(
        select(FriendRequest, User)
        .join(User, User.id == FriendRequest.sender_id)
        .where(FriendRequest.receiver_id == current_user.id)
        .where(FriendRequest.status == FriendRequestStatus.pending)
        .order_by(FriendRequest.created_at.desc())
    )
    requests = requests.all()
    
    result = []
    for req, sender in requests:
        result.append(FriendRequestResponse(
            id=req.id,
            sender_id=req.sender_id,
            receiver_id=req.receiver_id,
            status=req.status.value,
            created_at=req.created_at,
            sender_username=sender.username,
            sender_avatar_url=sender.avatar_url,
            receiver_username=current_user.username,
            receiver_avatar_url=current_user.avatar_url
        ))
    
    return result

@router.get("/requests/sent", response_model=List[FriendRequestResponse])
async def get_sent_requests(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Lấy danh sách lời mời kết bạn đã gửi (pending)."""
    requests = await db.execute(
        select(FriendRequest, User)
        .join(User, User.id == FriendRequest.receiver_id)
        .where(FriendRequest.sender_id == current_user.id)
        .where(FriendRequest.status == FriendRequestStatus.pending)
        .order_by(FriendRequest.created_at.desc())
    )
    requests = requests.all()
    
    result = []
    for req, receiver in requests:
        result.append(FriendRequestResponse(
            id=req.id,
            sender_id=req.sender_id,
            receiver_id=req.receiver_id,
            status=req.status.value,
            created_at=req.created_at,
            sender_username=current_user.username,
            sender_avatar_url=current_user.avatar_url,
            receiver_username=receiver.username,
            receiver_avatar_url=receiver.avatar_url
        ))
    
    return result

@router.put("/requests/{request_id}", response_model=FriendRequestResponse)
async def respond_friend_request(
    request_id: int,
    action: FriendRequestAction,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Chấp nhận hoặc từ chối lời mời kết bạn."""
    # Lấy friend request
    friend_request = await db.scalar(
        select(FriendRequest).where(FriendRequest.id == request_id)
    )
    if not friend_request:
        raise HTTPException(404, "Friend request not found")
    
    # Chỉ receiver mới có thể respond
    if friend_request.receiver_id != current_user.id:
        raise HTTPException(403, "Not authorized")
    
    # Kiểm tra status
    if friend_request.status != FriendRequestStatus.pending:
        raise HTTPException(400, "Request already processed")
    
    # Validate action
    if action.action not in ["accept", "reject"]:
        raise HTTPException(400, "Invalid action. Use 'accept' or 'reject'")
    
    # Lưu IDs trước khi commit (để tránh detached instance error)
    sender_id = friend_request.sender_id
    receiver_id = friend_request.receiver_id
    request_created_at = friend_request.created_at
    
    # Update status
    if action.action == "accept":
        friend_request.status = FriendRequestStatus.accepted
        friend_request.updated_at = datetime.now(timezone.utc)
        
        # Tạo friendship (user1_id < user2_id)
        u1, u2 = normalize_friendship(current_user.id, sender_id)
        friendship = Friend(user1_id=u1, user2_id=u2)
        db.add(friendship)
    else:
        friend_request.status = FriendRequestStatus.rejected
        friend_request.updated_at = datetime.now(timezone.utc)
    
    await db.commit()
    
    # Refresh để lấy status mới nhất
    await db.refresh(friend_request)
    
    # Lấy thông tin sender và receiver
    sender = await db.scalar(select(User).where(User.id == sender_id))
    receiver = await db.scalar(select(User).where(User.id == receiver_id))
    
    return FriendRequestResponse(
        id=friend_request.id,
        sender_id=sender_id,
        receiver_id=receiver_id,
        status=friend_request.status.value,
        created_at=request_created_at,
        sender_username=sender.username,
        sender_avatar_url=sender.avatar_url,
        receiver_username=receiver.username,
        receiver_avatar_url=receiver.avatar_url
    )

@router.delete("/requests/{request_id}")
async def cancel_friend_request(
    request_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Hủy lời mời kết bạn đã gửi."""
    friend_request = await db.scalar(
        select(FriendRequest).where(FriendRequest.id == request_id)
    )
    if not friend_request:
        raise HTTPException(404, "Friend request not found")
    
    # Chỉ sender mới có thể cancel
    if friend_request.sender_id != current_user.id:
        raise HTTPException(403, "Not authorized")
    
    # Chỉ cancel được request pending
    if friend_request.status != FriendRequestStatus.pending:
        raise HTTPException(400, "Cannot cancel processed request")
    
    await db.delete(friend_request)
    await db.commit()
    
    return {"message": "Friend request cancelled"}

# ==== Friends List ====

@router.get("", response_model=List[FriendResponse])
async def get_friends(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Lấy danh sách bạn bè."""
    # Lấy friendships (cả 2 chiều)
    friendships = await db.execute(
        select(Friend).where(
            or_(Friend.user1_id == current_user.id, Friend.user2_id == current_user.id)
        ).order_by(Friend.created_at.desc())
    )
    friendships = friendships.scalars().all()
    
    result = []
    for friendship in friendships:
        # Xác định friend_id (người còn lại)
        friend_id = friendship.user2_id if friendship.user1_id == current_user.id else friendship.user1_id
        
        # Lấy thông tin friend
        friend = await db.scalar(select(User).where(User.id == friend_id))
        if not friend:
            continue
        
        # Lấy rating
        rating = await get_user_rating(db, friend_id)
        
        result.append(FriendResponse(
            id=friendship.id,
            user_id=friend.id,
            username=friend.username,
            avatar_url=friend.avatar_url,
            rating=rating,
            is_online=False,  # TODO: implement online status
            created_at=friendship.created_at
        ))
    
    return result

@router.delete("/{friend_id}")
async def remove_friend(
    friend_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Hủy kết bạn."""
    if friend_id == current_user.id:
        raise HTTPException(400, "Cannot unfriend yourself")
    
    # Tìm friendship
    u1, u2 = normalize_friendship(current_user.id, friend_id)
    friendship = await db.scalar(
        select(Friend).where(Friend.user1_id == u1, Friend.user2_id == u2)
    )
    
    if not friendship:
        raise HTTPException(404, "Friendship not found")
    
    await db.delete(friendship)
    await db.commit()
    
    return {"message": "Friend removed"}

# ==== Challenge System ====

@router.post("/challenges", response_model=ChallengeResponse)
async def send_challenge(
    data: ChallengeCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Gửi thách đấu cho bạn bè."""
    # Kiểm tra không thách đấu chính mình
    if data.opponent_id == current_user.id:
        raise HTTPException(400, "Cannot challenge yourself")
    
    # Kiểm tra opponent tồn tại
    opponent = await db.scalar(select(User).where(User.id == data.opponent_id))
    if not opponent:
        raise HTTPException(404, "User not found")
    
    # Kiểm tra có phải bạn bè không
    is_friend = await check_friendship(db, current_user.id, data.opponent_id)
    if not is_friend:
        raise HTTPException(400, "You can only challenge friends")
    
    # Kiểm tra có challenge pending nào không
    existing = await db.scalar(
        select(Challenge).where(
            or_(
                and_(Challenge.challenger_id == current_user.id, Challenge.opponent_id == data.opponent_id),
                and_(Challenge.challenger_id == data.opponent_id, Challenge.opponent_id == current_user.id)
            ),
            Challenge.status == ChallengeStatus.pending
        )
    )
    if existing:
        raise HTTPException(400, "Already has a pending challenge with this user")
    
    # Lấy game Caro
    game = await db.scalar(select(Game).where(Game.name == "Caro"))
    if not game:
        raise HTTPException(500, "Caro game not found")
    
    # Tạo challenge (expire sau 5 phút)
    challenge = Challenge(
        challenger_id=current_user.id,
        opponent_id=data.opponent_id,
        game_id=game.id,
        message=data.message,
        status=ChallengeStatus.pending,
        expires_at=datetime.now(timezone.utc) + timedelta(minutes=5)
    )
    db.add(challenge)
    await db.commit()
    await db.refresh(challenge)
    
    # Gửi notification cho opponent qua WebSocket
    from app.api.realtime import send_notification
    await send_notification(data.opponent_id, {
        "type": "challenge_received",
        "payload": {
            "challenge_id": challenge.id,
            "challenger_id": current_user.id,
            "challenger_username": current_user.username,
            "challenger_avatar_url": current_user.avatar_url,
            "message": challenge.message,
            "expires_at": challenge.expires_at.isoformat() if challenge.expires_at else None
        }
    })
    
    # Lấy ratings
    challenger_rating = await get_user_rating(db, current_user.id)
    opponent_rating = await get_user_rating(db, data.opponent_id)
    
    return ChallengeResponse(
        id=challenge.id,
        challenger_id=current_user.id,
        opponent_id=data.opponent_id,
        game_id=game.id,
        match_id=None,
        status=challenge.status.value,
        message=challenge.message,
        created_at=challenge.created_at,
        expires_at=challenge.expires_at,
        challenger_username=current_user.username,
        challenger_avatar_url=current_user.avatar_url,
        challenger_rating=challenger_rating,
        opponent_username=opponent.username,
        opponent_avatar_url=opponent.avatar_url,
        opponent_rating=opponent_rating
    )

@router.get("/challenges/received", response_model=List[ChallengeResponse])
async def get_received_challenges(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Lấy danh sách thách đấu nhận được (pending)."""
    challenges = await db.execute(
        select(Challenge, User)
        .join(User, User.id == Challenge.challenger_id)
        .where(Challenge.opponent_id == current_user.id)
        .where(Challenge.status == ChallengeStatus.pending)
        .order_by(Challenge.created_at.desc())
    )
    challenges = challenges.all()
    
    result = []
    for challenge, challenger in challenges:
        # Kiểm tra expired
        if challenge.expires_at and datetime.now(timezone.utc) > challenge.expires_at:
            challenge.status = ChallengeStatus.expired
            await db.commit()
            continue
        
        challenger_rating = await get_user_rating(db, challenge.challenger_id)
        opponent_rating = await get_user_rating(db, current_user.id)
        
        result.append(ChallengeResponse(
            id=challenge.id,
            challenger_id=challenge.challenger_id,
            opponent_id=challenge.opponent_id,
            game_id=challenge.game_id,
            match_id=challenge.match_id,
            status=challenge.status.value,
            message=challenge.message,
            created_at=challenge.created_at,
            expires_at=challenge.expires_at,
            challenger_username=challenger.username,
            challenger_avatar_url=challenger.avatar_url,
            challenger_rating=challenger_rating,
            opponent_username=current_user.username,
            opponent_avatar_url=current_user.avatar_url,
            opponent_rating=opponent_rating
        ))
    
    return result

@router.get("/challenges/sent", response_model=List[ChallengeResponse])
async def get_sent_challenges(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Lấy danh sách thách đấu đã gửi (pending)."""
    challenges = await db.execute(
        select(Challenge, User)
        .join(User, User.id == Challenge.opponent_id)
        .where(Challenge.challenger_id == current_user.id)
        .where(Challenge.status == ChallengeStatus.pending)
        .order_by(Challenge.created_at.desc())
    )
    challenges = challenges.all()
    
    result = []
    for challenge, opponent in challenges:
        # Kiểm tra expired
        if challenge.expires_at and datetime.now(timezone.utc) > challenge.expires_at:
            challenge.status = ChallengeStatus.expired
            await db.commit()
            continue
        
        challenger_rating = await get_user_rating(db, current_user.id)
        opponent_rating = await get_user_rating(db, challenge.opponent_id)
        
        result.append(ChallengeResponse(
            id=challenge.id,
            challenger_id=challenge.challenger_id,
            opponent_id=challenge.opponent_id,
            game_id=challenge.game_id,
            match_id=challenge.match_id,
            status=challenge.status.value,
            message=challenge.message,
            created_at=challenge.created_at,
            expires_at=challenge.expires_at,
            challenger_username=current_user.username,
            challenger_avatar_url=current_user.avatar_url,
            challenger_rating=challenger_rating,
            opponent_username=opponent.username,
            opponent_avatar_url=opponent.avatar_url,
            opponent_rating=opponent_rating
        ))
    
    return result

@router.put("/challenges/{challenge_id}", response_model=ChallengeResponse)
async def respond_challenge(
    challenge_id: int,
    action: ChallengeAction,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Chấp nhận hoặc từ chối thách đấu."""
    # Lấy challenge
    challenge = await db.scalar(select(Challenge).where(Challenge.id == challenge_id))
    if not challenge:
        raise HTTPException(404, "Challenge not found")
    
    # Chỉ opponent mới có thể respond
    if challenge.opponent_id != current_user.id:
        raise HTTPException(403, "Not authorized")
    
    # Kiểm tra status
    if challenge.status != ChallengeStatus.pending:
        raise HTTPException(400, "Challenge already processed")
    
    # Kiểm tra expired
    if challenge.expires_at and datetime.now(timezone.utc) > challenge.expires_at:
        challenge.status = ChallengeStatus.expired
        await db.commit()
        raise HTTPException(400, "Challenge has expired")
    
    # Validate action
    if action.action not in ["accept", "reject"]:
        raise HTTPException(400, "Invalid action. Use 'accept' or 'reject'")
    
    # Update status
    if action.action == "accept":
        challenge.status = ChallengeStatus.accepted
        
        # Tạo match mới
        match = Match(
            game_id=challenge.game_id,
            board_rows=15,
            board_cols=19,
            win_len=5,
            status=MatchStatus.waiting,
            created_at=datetime.now(timezone.utc)
        )
        db.add(match)
        await db.flush()
        
        # Thêm 2 players vào match (challenger = X, opponent = O)
        player1 = MatchPlayer(
            match_id=match.id,
            user_id=challenge.challenger_id,
            symbol="X"
        )
        player2 = MatchPlayer(
            match_id=match.id,
            user_id=challenge.opponent_id,
            symbol="O"
        )
        db.add(player1)
        db.add(player2)
        
        # Cập nhật challenge với match_id
        challenge.match_id = match.id
    else:
        challenge.status = ChallengeStatus.rejected
    
    challenge.updated_at = datetime.now(timezone.utc)
    await db.commit()
    await db.refresh(challenge)
    
    # Lấy thông tin users
    challenger = await db.scalar(select(User).where(User.id == challenge.challenger_id))
    opponent = await db.scalar(select(User).where(User.id == challenge.opponent_id))
    
    challenger_rating = await get_user_rating(db, challenge.challenger_id)
    opponent_rating = await get_user_rating(db, challenge.opponent_id)
    
    return ChallengeResponse(
        id=challenge.id,
        challenger_id=challenge.challenger_id,
        opponent_id=challenge.opponent_id,
        game_id=challenge.game_id,
        match_id=challenge.match_id,
        status=challenge.status.value,
        message=challenge.message,
        created_at=challenge.created_at,
        expires_at=challenge.expires_at,
        challenger_username=challenger.username,
        challenger_avatar_url=challenger.avatar_url,
        challenger_rating=challenger_rating,
        opponent_username=opponent.username,
        opponent_avatar_url=opponent.avatar_url,
        opponent_rating=opponent_rating
    )

@router.delete("/challenges/{challenge_id}")
async def cancel_challenge(
    challenge_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Hủy thách đấu đã gửi."""
    challenge = await db.scalar(select(Challenge).where(Challenge.id == challenge_id))
    if not challenge:
        raise HTTPException(404, "Challenge not found")
    
    # Chỉ challenger mới có thể cancel
    if challenge.challenger_id != current_user.id:
        raise HTTPException(403, "Not authorized")
    
    # Chỉ cancel được challenge pending
    if challenge.status != ChallengeStatus.pending:
        raise HTTPException(400, "Cannot cancel processed challenge")
    
    await db.delete(challenge)
    await db.commit()
    
    return {"message": "Challenge cancelled"}
