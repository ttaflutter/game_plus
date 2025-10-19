from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, desc
from app.core.database import get_db
from app.api.auth import get_current_user
from app.models.models import Score, Game, User
from app.schemas.score import ScoreCreate, ScorePublic, LeaderboardEntry

router = APIRouter(prefix="/api/scores", tags=["Scores"])

@router.post("/", response_model=ScorePublic)
async def submit_score(
    payload: ScoreCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    res = await db.execute(select(Game).where(Game.id == payload.game_id))
    game = res.scalar_one_or_none()
    if not game:
        raise HTTPException(status_code=404, detail="Game not found")

    score = Score(user_id=current_user.id, game_id=game.id, score=payload.score, play_time=payload.play_time)
    db.add(score)
    await db.commit()
    await db.refresh(score)
    return score

@router.get("/leaderboard/{game_id}", response_model=list[LeaderboardEntry])
async def leaderboard(game_id: int, db: AsyncSession = Depends(get_db)):
    res = await db.execute(
        select(
            User.username,
            func.max(Score.score).label("high_score"),
            func.count(Score.id).label("plays")
        )
        .join(Score.user)
        .where(Score.game_id == game_id)
        .group_by(User.username)
        .order_by(desc("high_score"))
        .limit(10)
    )
    return [LeaderboardEntry(username=row.username, high_score=row.high_score, plays=row.plays) for row in res.all()]
