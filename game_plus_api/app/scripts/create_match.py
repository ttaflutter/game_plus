import asyncio
import sys, os
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "../..")))

from app.core.database import AsyncSessionLocal
from app.models.models import Match, Game

async def main():
    async with AsyncSessionLocal() as db:
        game = await db.get(Game, 1)
        if not game:
            game = Game(id=1, name="Caro", description="Caro Online 15x19")
            db.add(game)
            await db.commit()

        match = Match(game_id=1, board_rows=15, board_cols=19, win_len=5)
        db.add(match)
        await db.flush()   # ✅ lấy id ngay mà không cần commit
        print(f"✅ Created match id = {match.id}")

        await db.commit()  # commit sau cùng

asyncio.run(main())
