"""
Script để fix các match bị stuck ở status playing
"""
import asyncio
from app.core.database import AsyncSessionLocal
from app.models.models import Match, MatchStatus
from sqlalchemy import select, update
from datetime import datetime, timezone, timedelta

async def fix_stuck_matches():
    async with AsyncSessionLocal() as db:
        # Tìm các match đang playing nhưng created > 1 hour ago
        one_hour_ago = datetime.now(timezone.utc) - timedelta(hours=1)
        
        stuck_matches = await db.execute(
            select(Match).where(
                Match.status == MatchStatus.playing,
                Match.created_at < one_hour_ago
            )
        )
        
        stuck_list = stuck_matches.scalars().all()
        
        if not stuck_list:
            print("✅ No stuck matches found")
            return
        
        print(f"Found {len(stuck_list)} stuck matches:")
        for m in stuck_list:
            print(f"  - Match {m.id}: created {m.created_at}")
        
        # Fix them
        confirm = input("\nDo you want to mark these as finished? (yes/no): ")
        if confirm.lower() == 'yes':
            result = await db.execute(
                update(Match).where(
                    Match.status == MatchStatus.playing,
                    Match.created_at < one_hour_ago
                ).values(
                    status=MatchStatus.finished,
                    finished_at=datetime.now(timezone.utc)
                )
            )
            await db.commit()
            print(f"✅ Fixed {result.rowcount} matches")
        else:
            print("❌ Cancelled")

if __name__ == "__main__":
    asyncio.run(fix_stuck_matches())
