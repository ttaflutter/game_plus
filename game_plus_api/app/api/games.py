from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.core.database import get_db
from app.models.models import Game
from app.schemas.game import GamePublic

router = APIRouter(prefix="/api/games", tags=["Games"])

@router.get("/", response_model=list[GamePublic])
async def list_games(db: AsyncSession = Depends(get_db)):
    res = await db.execute(select(Game))
    games = res.scalars().all()
    return games
