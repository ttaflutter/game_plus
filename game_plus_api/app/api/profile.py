# app/api/profile.py
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, or_, and_
from app.core.database import get_db
from app.core.security import get_current_user, hash_password, verify_password
from app.models.models import (
    User, UserGameRating, Game, MatchPlayer, Match, MatchStatus,
    Friend
)
from app.schemas.user import (
    UserProfileDetail, UserUpdate, ChangePasswordRequest,
    UpdateAvatarRequest, NotificationSettings, UserSettings
)
from typing import Optional
from datetime import datetime, timezone

router = APIRouter(prefix="/api/profile", tags=["profile"])

# ==== Helper Functions ====

async def get_user_from_auth(current_user, db: AsyncSession) -> User:
    """
    Helper function để lấy User object từ SimpleNamespace của get_current_user.
    """
    user = await db.scalar(select(User).where(User.id == current_user.id))
    if not user:
        raise HTTPException(404, "User not found")
    return user

async def get_user_stats(db: AsyncSession, user_id: int, game_name: str = "Caro") -> dict:
    """Lấy thống kê của user."""
    # Tìm game
    game = await db.scalar(select(Game).where(Game.name == game_name))
    if not game:
        return {
            "rating": 1200,
            "total_matches": 0,
            "wins": 0,
            "losses": 0,
            "draws": 0,
            "win_rate": 0.0
        }
    
    # Lấy rating
    rating_obj = await db.scalar(
        select(UserGameRating.rating)
        .where(UserGameRating.user_id == user_id)
        .where(UserGameRating.game_id == game.id)
    )
    rating = rating_obj if rating_obj is not None else 1200
    
    # Đếm wins
    wins = await db.scalar(
        select(func.count())
        .select_from(MatchPlayer)
        .join(Match, Match.id == MatchPlayer.match_id)
        .where(
            MatchPlayer.user_id == user_id,
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
            MatchPlayer.user_id == user_id,
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
            MatchPlayer.user_id == user_id,
            Match.game_id == game.id,
            Match.status == MatchStatus.finished,
            MatchPlayer.is_winner == None
        )
    ) or 0
    
    total_matches = wins + losses + draws
    win_rate = (wins / total_matches * 100) if total_matches > 0 else 0.0
    
    return {
        "rating": rating,
        "total_matches": total_matches,
        "wins": wins,
        "losses": losses,
        "draws": draws,
        "win_rate": round(win_rate, 2)
    }

async def get_total_friends(db: AsyncSession, user_id: int) -> int:
    """Đếm số lượng bạn bè."""
    count = await db.scalar(
        select(func.count())
        .select_from(Friend)
        .where(or_(Friend.user1_id == user_id, Friend.user2_id == user_id))
    ) or 0
    return count

# ==== API Endpoints ====

@router.get("/me", response_model=UserProfileDetail)
async def get_my_profile(
    current_user = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Lấy thông tin profile đầy đủ của người dùng hiện tại.
    
    Bao gồm:
    - Thông tin cá nhân
    - Stats (rating, wins, losses, draws, win rate)
    - Số lượng bạn bè
    """
    # Query User object từ database để có đủ fields
    user = await db.scalar(select(User).where(User.id == current_user.id))
    if not user:
        raise HTTPException(404, "User not found")
    
    # Lấy stats
    stats = await get_user_stats(db, user.id)
    
    # Đếm số bạn bè
    total_friends = await get_total_friends(db, user.id)
    
    return UserProfileDetail(
        id=user.id,
        username=user.username,
        email=user.email,
        avatar_url=user.avatar_url,
        bio=user.bio,
        provider=user.provider,
        created_at=user.created_at,
        rating=stats["rating"],
        total_matches=stats["total_matches"],
        wins=stats["wins"],
        losses=stats["losses"],
        draws=stats["draws"],
        win_rate=stats["win_rate"],
        total_friends=total_friends
    )

@router.put("/update", response_model=UserProfileDetail)
async def update_profile(
    data: UserUpdate,
    current_user = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Cập nhật thông tin profile.
    
    - Username (nếu chưa tồn tại)
    - Bio
    - Avatar URL
    """
    # Get full User object
    user = await get_user_from_auth(current_user, db)
    
    # Nếu update username, kiểm tra trùng
    if data.username and data.username != user.username:
        existing = await db.scalar(
            select(User).where(User.username == data.username, User.id != user.id)
        )
        if existing:
            raise HTTPException(400, "Username already taken")
        user.username = data.username
    
    # Update bio
    if data.bio is not None:
        user.bio = data.bio
    
    # Update avatar
    if data.avatar_url is not None:
        user.avatar_url = data.avatar_url
    
    user.updated_at = datetime.now(timezone.utc)
    await db.commit()
    await db.refresh(user)
    
    # Return updated profile
    return await get_my_profile(current_user, db)

@router.put("/avatar", response_model=UserProfileDetail)
async def update_avatar(
    data: UpdateAvatarRequest,
    current_user = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Cập nhật avatar.
    
    Endpoint riêng để update avatar dễ dàng hơn.
    """
    # Get full User object
    user = await get_user_from_auth(current_user, db)
    
    user.avatar_url = data.avatar_url
    user.updated_at = datetime.now(timezone.utc)
    await db.commit()
    await db.refresh(user)
    
    return await get_my_profile(current_user, db)

@router.post("/change-password")
async def change_password(
    data: ChangePasswordRequest,
    current_user = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Đổi mật khẩu.
    
    - Yêu cầu mật khẩu cũ đúng
    - Mật khẩu mới phải khác mật khẩu cũ
    - Chỉ áp dụng cho account local (không phải Google OAuth)
    """
    # Get full User object
    user = await get_user_from_auth(current_user, db)
    
    # Kiểm tra provider
    if user.provider != "local":
        raise HTTPException(
            400, 
            f"Cannot change password for {user.provider} account. Please use {user.provider} to manage your password."
        )
    
    # Kiểm tra có mật khẩu không
    if not user.hashed_password:
        raise HTTPException(400, "This account doesn't have a password set")
    
    # Verify mật khẩu cũ
    if not verify_password(data.old_password, user.hashed_password):
        raise HTTPException(400, "Incorrect old password")
    
    # Kiểm tra mật khẩu mới khác mật khẩu cũ
    if data.old_password == data.new_password:
        raise HTTPException(400, "New password must be different from old password")
    
    # Update mật khẩu
    user.hashed_password = hash_password(data.new_password)
    user.updated_at = datetime.now(timezone.utc)
    await db.commit()
    
    return {
        "message": "Password changed successfully",
        "success": True
    }

@router.delete("/delete-account")
async def delete_account(
    password: Optional[str] = None,
    current_user = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Xóa tài khoản.
    
    - Yêu cầu xác nhận mật khẩu (nếu là local account)
    - Xóa tất cả dữ liệu liên quan (cascade)
    """
    # Get full User object
    user = await get_user_from_auth(current_user, db)
    
    # Nếu là local account, yêu cầu mật khẩu
    if user.provider == "local":
        if not password:
            raise HTTPException(400, "Password required to delete account")
        
        if not user.hashed_password:
            raise HTTPException(400, "This account doesn't have a password set")
        
        if not verify_password(password, user.hashed_password):
            raise HTTPException(400, "Incorrect password")
    
    # Xóa user (cascade sẽ xóa tất cả dữ liệu liên quan)
    await db.delete(user)
    await db.commit()
    
    return {
        "message": "Account deleted successfully",
        "success": True
    }

@router.get("/stats")
async def get_detailed_stats(
    game_name: str = "Caro",
    current_user = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Lấy thống kê chi tiết hơn.
    
    - Stats theo game
    - Thêm thông tin như average game duration, v.v.
    """
    stats = await get_user_stats(db, current_user.id, game_name)
    
    # TODO: Thêm các stats khác nếu cần
    # - Average game duration
    # - Longest winning streak
    # - Favorite opponent
    # etc.
    
    return stats

# ==== Settings Endpoints ====

@router.get("/settings", response_model=UserSettings)
async def get_settings(
    current_user = Depends(get_current_user)
):
    """
    Lấy cài đặt người dùng.
    
    TODO: Lưu settings vào database nếu cần persistence.
    Hiện tại return default settings.
    """
    return UserSettings()

@router.put("/settings")
async def update_settings(
    settings: UserSettings,
    current_user = Depends(get_current_user)
):
    """
    Cập nhật cài đặt người dùng.
    
    TODO: Lưu vào database nếu cần.
    """
    # TODO: Implement settings storage
    return {
        "message": "Settings updated successfully",
        "settings": settings
    }

@router.post("/logout")
async def logout(
    current_user = Depends(get_current_user)
):
    """
    Đăng xuất.
    
    Note: Với JWT, logout được xử lý ở client bằng cách xóa token.
    Endpoint này chỉ để confirm action.
    
    Để implement blacklist token (nếu cần), có thể:
    1. Lưu token vào Redis với TTL
    2. Check token trong middleware
    """
    return {
        "message": "Logged out successfully",
        "success": True,
        "instruction": "Please delete the access token from client storage"
    }
