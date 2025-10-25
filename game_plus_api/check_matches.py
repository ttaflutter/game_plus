import asyncio
from app.core.database import AsyncSessionLocal
from app.models.models import Match
from sqlalchemy import select

async def check():
    async with AsyncSessionLocal() as db:
        matches = await db.execute(select(Match).order_by(Match.id.desc()).limit(5))
        for m in matches.scalars():
            print(f'Match {m.id}: status={m.status}, created={m.created_at}, finished={m.finished_at}')

asyncio.run(check())
