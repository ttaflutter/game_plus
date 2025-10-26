# app/api/realtime.py
from __future__ import annotations
from fastapi import APIRouter, WebSocket, WebSocketDisconnect, Query, Depends
from jose import jwt, JWTError
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, insert, update
from sqlalchemy.dialects.postgresql import insert as pg_insert
from app.core.database import get_db
from app.models.models import Match, MatchPlayer, Move, MatchStatus, User, UserGameRating
from datetime import datetime, timezone
import asyncio
import json
import os
from typing import Dict, Tuple, List

router = APIRouter(prefix="/ws", tags=["realtime"])

SECRET_KEY = os.getenv("SECRET_KEY", "changeme")
ALGORITHM = "HS256"


MOVE_TIMEOUT = 30  # seconds per move

class Connection:
    def __init__(self, ws: WebSocket, user_id: int):
        self.ws = ws
        self.user_id = user_id
        self.last_ping = datetime.now(timezone.utc)

class RoomState:
    def __init__(self, match_id: int, board_rows: int, board_cols: int, win_len: int):
        self.match_id = match_id
        self.board_rows = board_rows
        self.board_cols = board_cols
        self.win_len = win_len
        self.board = [["" for _ in range(board_cols)] for _ in range(board_rows)]
        self.turn_symbol = "X"
        self.turn_no = 0
        self.status: str = "waiting"  # waiting | playing | finished
        self.connections: Dict[int, Connection] = {}  # user_id -> conn
        self.players: Dict[int, str] = {}            # user_id -> 'X'|'O'
        self.player_info: Dict[int, dict] = {}       # user_id -> {username, avatar_url}
        self.lock = asyncio.Lock()
        self.loaded_from_db = False  # Ä‘Ã£ khÃ´i phá»¥c bÃ n tá»« DB chÆ°a?
        self.turn_start_time: datetime | None = None  # thá»i Ä‘iá»ƒm báº¯t Ä‘áº§u lÆ°á»£t hiá»‡n táº¡i
        self.timeout_task: asyncio.Task | None = None  # task Ä‘áº¿m thá»i gian
        self.rematch_requests: set[int] = set()  # user_ids Ä‘Ã£ gá»­i yÃªu cáº§u rematch

    def snapshot(self, you_id: int):
        time_left = None
        if self.status == "playing" and self.turn_start_time:
            elapsed = (datetime.now(timezone.utc) - self.turn_start_time).total_seconds()
            time_left = max(0, MOVE_TIMEOUT - elapsed)
        
        # Táº¡o danh sÃ¡ch players vá»›i Ä'áº§y Ä'á»§ thÃ´ng tin
        players_list = []
        for uid, sym in self.players.items():
            player_data = {"user_id": uid, "symbol": sym}
            if uid in self.player_info:
                player_data.update(self.player_info[uid])
            players_list.append(player_data)
        
        return {
            "type": "joined",
            "payload": {
                "you": {"user_id": you_id, "symbol": self.players.get(you_id)},
                "players": players_list,
                "turn": self.turn_symbol,
                "turn_no": self.turn_no,
                "status": self.status,
                "time_left": time_left,
                "board": [[cell for cell in row] for row in self.board],  # gá»­i cáº£ bÃ n cá»
            },
        }

rooms: Dict[int, RoomState] = {}

# â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
# Utils
# â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
async def decode_token(token: str) -> int:
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        sub = payload.get("sub")
        return int(sub)
    except Exception as e:
        raise ValueError(f"Invalid token: {e}")

def check_win(board: List[List[str]], x: int, y: int, win_len: int, symbol: str) -> List[Tuple[int,int]] | None:
    H, W = len(board), len(board[0])
    dirs = [(1,0),(0,1),(1,1),(1,-1)]
    for dx,dy in dirs:
        line = [(x,y)]
        i,j = x+dx, y+dy
        while 0 <= i < H and 0 <= j < W and board[i][j] == symbol:
            line.append((i,j)); i += dx; j += dy
        i,j = x-dx, y-dy
        while 0 <= i < H and 0 <= j < W and board[i][j] == symbol:
            line.insert(0,(i,j)); i -= dx; j -= dy
        if len(line) >= win_len:
            return line
    return None

async def broadcast(state: RoomState, message: dict):
    data = json.dumps(message)
    for conn in list(state.connections.values()):
        try:
            await conn.ws.send_text(data)
        except Exception:
            # bá» qua client Ä‘Ã£ Ä‘á»©t
            pass

async def end_match(state: RoomState, db: AsyncSession, winner_id: int | None, reason: str = "normal"):
    """Káº¿t thÃºc tráº­n Ä‘áº¥u vÃ  cáº­p nháº­t database."""
    print(f"ðŸ Ending match {state.match_id}, winner: {winner_id}, reason: {reason}")
    
    state.status = "finished"
    
    # Cancel timeout task náº¿u cÃ³
    if state.timeout_task and not state.timeout_task.done():
        state.timeout_task.cancel()
    
    try:
        # Cáº­p nháº­t match status
        result = await db.execute(
            update(Match).where(Match.id == state.match_id).values(
                status=MatchStatus.finished,
                finished_at=datetime.now(timezone.utc)
            )
        )
        print(f"âœ… Updated match {state.match_id} status to finished (rows affected: {result.rowcount})")
        
        # Cáº­p nháº­t winner/loser
        if winner_id:
            result = await db.execute(
                update(MatchPlayer)
                .where(MatchPlayer.match_id == state.match_id, MatchPlayer.user_id == winner_id)
                .values(is_winner=True)
            )
            print(f"âœ… Set winner {winner_id} (rows: {result.rowcount})")
            
            loser_ids = [uid for uid in state.players.keys() if uid != winner_id]
            if loser_ids:
                result2 = await db.execute(
                    update(MatchPlayer)
                    .where(MatchPlayer.match_id == state.match_id, MatchPlayer.user_id.in_(loser_ids))
                    .values(is_winner=False)
                )
                print(f"âœ… Set losers {loser_ids} (rows: {result2.rowcount})")
        else:
            # Draw - cáº£ 2 Ä‘á»u khÃ´ng tháº¯ng
            result = await db.execute(
                update(MatchPlayer)
                .where(MatchPlayer.match_id == state.match_id)
                .values(is_winner=None)
            )
            print(f"âœ… Set draw (rows: {result.rowcount})")
        
        print(f"ðŸ’¾ About to COMMIT match {state.match_id}...")
        await db.commit()
        print(f"âœ… COMMITTED match {state.match_id} to database!")
        
        # Cáº­p nháº­t rating
        print(f"ðŸ“Š Updating ratings for match {state.match_id}...")
        rating_changes = await update_ratings(state, db, winner_id)
        print(f"âœ… Ratings updated for match {state.match_id}")
        
        return rating_changes
        
    except Exception as e:
        print(f"âŒ ERROR in end_match: {type(e).__name__}: {e}")
        import traceback
        traceback.print_exc()
        await db.rollback()
        return {}

async def update_ratings(state: RoomState, db: AsyncSession, winner_id: int | None):
    """Cáº­p nháº­t ELO rating sau tráº­n Ä‘áº¥u."""
    from app.models.models import UserGameRating
    
    try:
        print(f"ðŸ“Š Starting update_ratings for match {state.match_id}, winner: {winner_id}")
        
        # Láº¥y game_id
        match = await db.scalar(select(Match).where(Match.id == state.match_id))
        if not match:
            print(f"âš ï¸  Match {state.match_id} not found!")
            return
        
        player_ids = list(state.players.keys())
        if len(player_ids) != 2:
            print(f"âš ï¸  Not exactly 2 players: {player_ids}")
            return
        
        print(f"ðŸ‘¥ Players: {player_ids}")
        
        # Láº¥y rating hiá»‡n táº¡i
        ratings = {}
        for uid in player_ids:
            rating_obj = await db.scalar(
                select(UserGameRating).where(
                    UserGameRating.user_id == uid,
                    UserGameRating.game_id == match.game_id
                )
            )
            if not rating_obj:
                # Táº¡o rating má»›i
                rating_obj = UserGameRating(
                    user_id=uid,
                    game_id=match.game_id,
                    rating=1200,
                    wins=0,
                    losses=0,
                    draws=0
                )
                db.add(rating_obj)
                await db.flush()
            ratings[uid] = rating_obj
        
        print(f"ðŸ“ˆ Current ratings: {[(uid, r.rating) for uid, r in ratings.items()]}")
        
        # TÃ­nh ELO má»›i
        K = 32  # K-factor
        player1_id, player2_id = player_ids[0], player_ids[1]
        r1, r2 = ratings[player1_id].rating, ratings[player2_id].rating
        
        # Expected scores
        e1 = 1 / (1 + 10 ** ((r2 - r1) / 400))
        e2 = 1 / (1 + 10 ** ((r1 - r2) / 400))
        
        # Actual scores
        if winner_id == player1_id:
            s1, s2 = 1.0, 0.0
            ratings[player1_id].wins += 1
            ratings[player2_id].losses += 1
        elif winner_id == player2_id:
            s1, s2 = 0.0, 1.0
            ratings[player1_id].losses += 1
            ratings[player2_id].wins += 1
        else:
            s1, s2 = 0.5, 0.5
            ratings[player1_id].draws += 1
            ratings[player2_id].draws += 1
        
        # Update ratings
        new_r1 = int(r1 + K * (s1 - e1))
        new_r2 = int(r2 + K * (s2 - e2))
        
        ratings[player1_id].rating = new_r1
        ratings[player2_id].rating = new_r2
        
        # Tính rating changes
        rating_changes = {
            str(player1_id): new_r1 - r1,
            str(player2_id): new_r2 - r2
        }
        
        print(f"📈 New ratings: {player1_id}:{r1}->{new_r1} ({rating_changes[str(player1_id)]:+d}), {player2_id}:{r2}->{new_r2} ({rating_changes[str(player2_id)]:+d})")
        
        print(f"ðŸ’¾ Committing ratings...")
        await db.commit()
        print(f"âœ… Ratings committed!")
        
        return rating_changes
        
    except Exception as e:
        print(f"âŒ ERROR in update_ratings: {type(e).__name__}: {e}")
        import traceback
        traceback.print_exc()
        await db.rollback()
        return {}

async def handle_timeout(state: RoomState):
    """Xá»­ lÃ½ khi háº¿t thá»i gian - ngÆ°á»i chÆ¡i hiá»‡n táº¡i thua."""
    from app.core.database import AsyncSessionLocal, engine
    from sqlalchemy import text
    
    print(f"â° TIMEOUT for match {state.match_id}, current turn: {state.turn_symbol}")
    
    async with state.lock:
        if state.status != "playing":
            print(f"âš ï¸  Match {state.match_id} not playing anymore, skip timeout")
            return
        
        state.status = "finished"
        
        # TÃ¬m ngÆ°á»i thua (ngÆ°á»i Ä‘ang cÃ³ lÆ°á»£t)
        loser_id = None
        winner_id = None
        for uid, sym in state.players.items():
            if sym == state.turn_symbol:
                loser_id = uid
            else:
                winner_id = uid
        
        print(f"â° Timeout: loser={loser_id}, winner={winner_id}")
        
        # Update trá»±c tiáº¿p báº±ng raw SQL Ä‘á»ƒ trÃ¡nh session issues
        try:
            async with engine.begin() as conn:
                now = datetime.now(timezone.utc)
                
                # Update match
                await conn.execute(
                    text("UPDATE matches SET status = 'finished', finished_at = :now WHERE id = :match_id"),
                    {"now": now, "match_id": state.match_id}
                )
                print(f"âœ… Updated match {state.match_id} to finished")
                
                # Update winner
                if winner_id:
                    await conn.execute(
                        text("UPDATE match_players SET is_winner = true WHERE match_id = :match_id AND user_id = :user_id"),
                        {"match_id": state.match_id, "user_id": winner_id}
                    )
                    print(f"âœ… Set winner {winner_id}")
                    
                    # Update loser
                    if loser_id:
                        await conn.execute(
                            text("UPDATE match_players SET is_winner = false WHERE match_id = :match_id AND user_id = :user_id"),
                            {"match_id": state.match_id, "user_id": loser_id}
                        )
                        print(f"âœ… Set loser {loser_id}")
                
                print(f"âœ… Transaction committed for match {state.match_id}")
            
            # Update ratings sau khi commit match
            async with AsyncSessionLocal() as db:
                rating_changes = await update_ratings(state, db, winner_id)
            
            # Broadcast káº¿t quáº£
            await broadcast(state, {
                "type": "timeout",
                "payload": {
                    "reason": "timeout",
                    "winner_user_id": winner_id,
                    "loser_user_id": loser_id,
                    "rating_changes": rating_changes,
                }
            })
            print(f"âœ… Timeout handled for match {state.match_id}")
            
        except Exception as e:
            print(f"âŒ Error in handle_timeout: {e}")
            import traceback
            traceback.print_exc()

async def start_turn_timer(state: RoomState):
    """Báº¯t Ä‘áº§u Ä‘áº¿m thá»i gian cho lÆ°á»£t chÆ¡i."""
    if state.timeout_task and not state.timeout_task.done():
        state.timeout_task.cancel()
    
    state.turn_start_time = datetime.now(timezone.utc)
    
    async def timer():
        try:
            await asyncio.sleep(MOVE_TIMEOUT)
            await handle_timeout(state)
        except asyncio.CancelledError:
            pass
    
    state.timeout_task = asyncio.create_task(timer())

async def load_room_from_db(state: RoomState, db: AsyncSession):
    """KhÃ´i phá»¥c bÃ n cá», lÆ°á»£t, tráº¡ng thÃ¡i tá»« DB (moves + match.status)."""
    if state.loaded_from_db:
        return
    match = await db.scalar(select(Match).where(Match.id == state.match_id))
    if not match:
        return
    state.status = match.status.value if hasattr(match.status, "value") else str(match.status)
    
    # load players vÃ  user info
    mp_rows = (await db.execute(
        select(MatchPlayer, User)
        .join(User, User.id == MatchPlayer.user_id)
        .where(MatchPlayer.match_id == state.match_id)
    )).all()
    for mp, user in mp_rows:
        state.players[mp.user_id] = mp.symbol
        
        # Lấy rating
        rating = None
        rating_obj = await db.scalar(
            select(UserGameRating.rating)
            .where(UserGameRating.user_id == mp.user_id)
            .where(UserGameRating.game_id == match.game_id)
        )
        rating = rating_obj if rating_obj is not None else 1200
        
        state.player_info[mp.user_id] = {
            "username": user.username,
            "avatar_url": user.avatar_url,
            "rating": rating,
        }
    
    # load moves theo turn_no
    mv_rows = (await db.execute(
        select(Move).where(Move.match_id == state.match_id).order_by(Move.turn_no.asc())
    )).scalars().all()
    for mv in mv_rows:
        if 0 <= mv.x < state.board_rows and 0 <= mv.y < state.board_cols and not state.board[mv.x][mv.y]:
            state.board[mv.x][mv.y] = mv.symbol
            state.turn_no = mv.turn_no
            state.turn_symbol = 'O' if mv.symbol == 'X' else 'X'
    state.loaded_from_db = True

# â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
# WebSocket handler
# â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
@router.websocket("/match/{match_id}")
async def websocket_match(
    websocket: WebSocket,
    match_id: int,
    token: str = Query(...),
    db: AsyncSession = Depends(get_db),
):
    # 1) Auth
    try:
        user_id = await decode_token(token)
    except ValueError:
        await websocket.close(code=4001)
        return

    await websocket.accept()

    # 2) Match tá»“n táº¡i khÃ´ng?
    match_obj = await db.scalar(select(Match).where(Match.id == match_id))
    if not match_obj:
        await websocket.send_text(json.dumps({"type": "error", "payload": "Match not found"}))
        await websocket.close()
        return

    # 3) Láº¥y / táº¡o room + khÃ´i phá»¥c bÃ n tá»« DB náº¿u cáº§n
    if match_id not in rooms:
        rooms[match_id] = RoomState(match_id, match_obj.board_rows, match_obj.board_cols, match_obj.win_len)
    state = rooms[match_id]
    await load_room_from_db(state, db)

    conn = Connection(websocket, user_id)

    # 4) Join room
    async with state.lock:
        # Náº¿u user Ä'Ã£ cÃ³ connection cÅ© (reconnect), Ä'Ã³ng connection cÅ© 
        if user_id in state.connections:
            old_conn = state.connections[user_id]
            try:
                await old_conn.ws.close()
                print(f"🔄 Closed old connection for user {user_id}")
            except Exception as e:
                print(f"⚠️ Failed to close old connection: {e}")
        
        state.connections[user_id] = conn

        # Láº¥y thÃ´ng tin user náº¿u chÆ°a cÃ³
        if user_id not in state.player_info:
            user_obj = await db.scalar(select(User).where(User.id == user_id))
            if user_obj:
                # Lấy rating cho game hiện tại
                from app.models.models import Game
                rating = None
                rating_obj = await db.scalar(
                    select(UserGameRating.rating)
                    .where(UserGameRating.user_id == user_id)
                    .where(UserGameRating.game_id == match_obj.game_id)
                )
                rating = rating_obj if rating_obj is not None else 1200
                
                state.player_info[user_id] = {
                    "username": user_obj.username,
                    "avatar_url": user_obj.avatar_url,
                    "rating": rating,
                }

        # Chá»‰ cho tá»'i Ä'a 2 player cáº§m quÃ¢n (cÃ²n láº¡i lÃ  spectator)
        if user_id not in state.players and len(state.players) < 2 and state.status != "finished":
            symbol = "X" if "X" not in state.players.values() else "O"
            state.players[user_id] = symbol

            # Upsert vÃ o DB trÃ¡nh Ä'á»¥ng Ä'á»™
            stmt = pg_insert(MatchPlayer).values(
                match_id=match_id, user_id=user_id, symbol=symbol
            ).on_conflict_do_nothing(
                index_elements=[MatchPlayer.match_id, MatchPlayer.user_id]
            )
            await db.execute(stmt)
            await db.commit()

        # Náº¿u Ä‘á»§ 2 ngÆ°á»i vÃ  Ä‘ang waiting â†’ chuyá»ƒn playing
        if state.status == "waiting" and len([s for s in state.players.values() if s in ("X","O")]) == 2:
            state.status = "playing"
            await db.execute(
                update(Match)
                .where(Match.id == match_id)
                .values(status=MatchStatus.playing, started_at=datetime.now(timezone.utc))
            )
            await db.commit()
            
            # Báº¯t Ä'áº§u Ä'áº¿m giá» cho ngÆ°á»i chÆ¡i X
            await start_turn_timer(state)
            
            # Táº¡o players list vá»›i thÃ´ng tin Ä'áº§y Ä'á»§
            players_with_info = []
            for uid, sym in state.players.items():
                player_data = {"user_id": uid, "symbol": sym}
                if uid in state.player_info:
                    player_data.update(state.player_info[uid])
                players_with_info.append(player_data)
            
            await broadcast(state, {
                "type": "start",
                "payload": {
                    "turn": state.turn_symbol,
                    "players": players_with_info,
                    "time_limit": MOVE_TIMEOUT,
                },
            })

    # Gá»­i snapshot cho client vá»«a join
    await websocket.send_text(json.dumps(state.snapshot(user_id)))

    # 5) Main loop
    try:
        while True:
            raw = await websocket.receive_text()
            try:
                msg = json.loads(raw)
            except Exception:
                await websocket.send_text(json.dumps({"type": "error", "payload": "Invalid JSON"}))
                continue

            mtype = msg.get("type")
            payload = msg.get("payload", {})

            async with state.lock:
                # Ä‘Ã£ káº¿t thÃºc thÃ¬ chá»‰ cho chat
                if mtype == "move" and state.status != "playing":
                    await websocket.send_text(json.dumps({"type":"error","payload":"Match is not in playing state"}))
                    continue

                if mtype == "move":
                    if state.status != "playing":
                        await websocket.send_text(
                            json.dumps({
                                    "type": "error",
                                    "payload": "Match already finished"
                            })
                        )
                        continue
                    sym = state.players.get(user_id)
                    if sym not in ("X","O"):
                        await websocket.send_text(json.dumps({"type":"error","payload":"Spectator cannot move"}))
                        continue
                    if sym != state.turn_symbol:
                        await websocket.send_text(json.dumps({"type":"error","payload":"Not your turn"}))
                        continue

                    try:
                        x = int(payload["x"]); y = int(payload["y"])
                    except Exception:
                        await websocket.send_text(json.dumps({"type":"error","payload":"Invalid coordinates"}))
                        continue

                    if not (0 <= x < state.board_rows and 0 <= y < state.board_cols) or state.board[x][y]:
                        await websocket.send_text(json.dumps({"type":"error","payload":"Invalid cell"}))
                        continue

                    # Apply move
                    state.board[x][y] = sym
                    state.turn_no += 1

                    await db.execute(insert(Move).values(
                        match_id=match_id, turn_no=state.turn_no, user_id=user_id, x=x, y=y, symbol=sym
                    ))
                    await db.commit()

                    # Win / Draw
                    win_line = check_win(state.board, x, y, state.win_len, sym)
                    if win_line:
                        rating_changes = await end_match(state, db, user_id, "win")
                        
                        await broadcast(state, {
                            "type": "win",
                            "payload": {
                                "winner_user_id": user_id,
                                "symbol": sym,
                                "line": [{"x": i, "y": j} for i, j in win_line],
                                "rating_changes": rating_changes,
                            },
                        })
                    elif state.turn_no == state.board_rows * state.board_cols:
                        rating_changes = await end_match(state, db, None, "draw")
                        await broadcast(state, {
                            "type": "draw",
                            "payload": {
                                "reason": "board_full",
                                "rating_changes": rating_changes,
                            }
                        })
                    else:
                        # Chuyá»ƒn lÆ°á»£t
                        state.turn_symbol = "O" if sym == "X" else "X"
                        await start_turn_timer(state)
                        
                        await broadcast(state, {
                            "type": "move",
                            "payload": {
                                "x": x, "y": y, "symbol": sym,
                                "turn_no": state.turn_no,
                                "next_turn": state.turn_symbol,
                                "time_limit": MOVE_TIMEOUT,
                            },
                        })

                elif mtype == "surrender":
                    # Äáº§u hÃ ng - Ä‘á»‘i thá»§ tháº¯ng
                    if user_id not in state.players:
                        await websocket.send_text(json.dumps({"type":"error","payload":"You are not a player"}))
                        continue
                    
                    if state.status != "playing":
                        await websocket.send_text(json.dumps({"type":"error","payload":"Match is not playing"}))
                        continue
                    
                    # TÃ¬m Ä‘á»‘i thá»§
                    winner_id = None
                    for uid in state.players.keys():
                        if uid != user_id:
                            winner_id = uid
                            break
                    
                    rating_changes = await end_match(state, db, winner_id, "surrender")
                    
                    await broadcast(state, {
                        "type": "surrender",
                        "payload": {
                            "surrendered_user_id": user_id,
                            "winner_user_id": winner_id,
                            "rating_changes": rating_changes,
                        },
                    })

                elif mtype == "chat":
                    msgtxt = str(payload.get("message","")).strip()
                    if not msgtxt:
                        continue
                    if len(msgtxt) > 300:
                        msgtxt = msgtxt[:300]
                    await broadcast(state, {
                        "type": "chat",
                        "payload": {
                            "from": user_id,
                            "message": msgtxt,
                            "time": datetime.now(timezone.utc).isoformat(),
                        },
                    })

                elif mtype == "ping":
                    await websocket.send_text(json.dumps({"type":"pong"}))

                elif mtype == "rematch":
                    # YÃªu cáº§u chÆ¡i láº¡i
                    if user_id not in state.players:
                        await websocket.send_text(json.dumps({"type":"error","payload":"You are not a player"}))
                        continue
                    
                    if state.status != "finished":
                        await websocket.send_text(json.dumps({"type":"error","payload":"Match is not finished yet"}))
                        continue
                    
                    # ThÃªm user vÃ o danh sÃ¡ch yÃªu cáº§u rematch
                    state.rematch_requests.add(user_id)
                    
                    # Broadcast yÃªu cáº§u rematch
                    await broadcast(state, {
                        "type": "rematch_request",
                        "payload": {
                            "from_user_id": user_id,
                            "total_requests": len(state.rematch_requests),
                            "total_players": len(state.players)
                        }
                    })
                    
                    # Náº¿u cáº£ 2 ngÆ°á»i chÆ¡i Ä‘á»u Ä‘á»“ng Ã½ -> táº¡o tráº­n má»›i
                    if len(state.rematch_requests) == len(state.players) and len(state.players) == 2:
                        # Táº¡o match má»›i
                        from app.models.models import Game
                        
                        game = await db.scalar(select(Game).where(Game.name == "Caro"))
                        if game:
                            new_match = Match(
                                game_id=game.id,
                                board_rows=state.board_rows,
                                board_cols=state.board_cols,
                                win_len=state.win_len,
                                status=MatchStatus.waiting,
                                created_at=datetime.now(timezone.utc),
                            )
                            db.add(new_match)
                            await db.flush()
                            
                            new_match_id = new_match.id
                            
                            # KHÃNG thÃªm players tá»± Ä'á»™ng - Ä'á»ƒ clients tá»± join khi reconnect
                            # VÃ¬ náº¿u thÃªm sáºµn 2 players, client thá»© 2 join sáº½ trigger "playing" ngay
                            
                            await db.commit()
                            
                            # Broadcast thÃ´ng bÃ¡o match má»›i
                            await broadcast(state, {
                                "type": "rematch_accepted",
                                "payload": {
                                    "new_match_id": new_match_id,
                                    "message": "Both players accepted! New match created."
                                }
                            })
                            
                            print(f"ðŸ”„ Rematch created: {state.match_id} -> {new_match_id}")

                else:
                    await websocket.send_text(json.dumps({"type":"error","payload":f"Unknown type: {mtype}"}))

    except WebSocketDisconnect:
        async with state.lock:
            state.connections.pop(user_id, None)
            
            # Náº¿u ngÆ°á»i chÆ¡i disconnect khi Ä‘ang chÆ¡i -> Ä‘á»‘i thá»§ tháº¯ng
            if state.status == "playing" and user_id in state.players:
                # TÃ¬m Ä‘á»‘i thá»§
                winner_id = None
                for uid in state.players.keys():
                    if uid != user_id:
                        winner_id = uid
                        break
                
                if winner_id:
                    rating_changes = await end_match(state, db, winner_id, "disconnect")
                    
                    await broadcast(state, {
                        "type": "disconnect",
                        "payload": {
                            "disconnected_user_id": user_id,
                            "winner_user_id": winner_id,
                            "reason": "Player disconnected",
                            "rating_changes": rating_changes,
                        }
                    })

            
            # 🚨 CRITICAL: Nếu match đã finished và player disconnect -> notify opponent
            elif state.status == "finished":
                print(f"👋 User {user_id} left finished match {state.match_id}")
                
                # Gửi player_left cho tất cả players còn lại
                await broadcast(state, {
                    "type": "player_left",
                    "payload": {
                        "user_id": user_id,
                        "match_id": state.match_id
                    }
                })
                
                # Nếu có pending rematch request -> cancel
                if user_id in state.rematch_requests:
                    state.rematch_requests.discard(user_id)
                    
                    await broadcast(state, {
                        "type": "rematch_cancelled",
                        "payload": {
                            "reason": "player_left",
                            "left_user_id": user_id
                        }
                    })
                    print(f"❌ Rematch cancelled because user {user_id} left")

            # Nếu tất cả đều rời -> dọn phòng sau 3s
            if not state.connections and state.status == "finished":
                async def cleanup_room():
                    await asyncio.sleep(3)
                    rooms.pop(match_id, None)
                    print(f"ðŸ§¹ Room {match_id} cleaned up after all players left.")
                
                asyncio.create_task(cleanup_room())

    except Exception as e:
        print(f"âŒ Error in websocket handler: {e}")
        async with state.lock:
            state.connections.pop(user_id, None)

# Note: Removed the redundant cleanup at the end since it's now handled in disconnect


# â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
# Matchmaking WebSocket - Ä‘á»ƒ thÃ´ng bÃ¡o khi tÃ¬m Ä‘Æ°á»£c Ä‘á»‘i thá»§
# â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
matchmaking_queue: Dict[int, WebSocket] = {}  # user_id -> websocket

@router.websocket("/matchmaking")
async def websocket_matchmaking(
    websocket: WebSocket,
    token: str = Query(...),
    db: AsyncSession = Depends(get_db),
):
    """WebSocket endpoint cho matchmaking - tÃ¬m Ä‘á»‘i thá»§ tá»± Ä‘á»™ng."""
    # 1) Auth
    try:
        await websocket.accept()
        user_id = await decode_token(token)
    except ValueError:
        await websocket.close(code=4001)
        return

    print(f"ðŸ” User {user_id} joined matchmaking queue")
    
    # ThÃªm vÃ o queue
    matchmaking_queue[user_id] = websocket
    
    try:
        # Gá»­i thÃ´ng bÃ¡o Ä‘Ã£ vÃ o queue
        await websocket.send_text(json.dumps({
            "type": "searching",
            "payload": {
                "message": "Searching for opponent...",
                "queue_size": len(matchmaking_queue)
            }
        }))
        
        # TÃ¬m hoáº§c táº¡o match
        from app.models.models import Game
        
        game = await db.scalar(select(Game).where(Game.name == "Caro"))
        if not game:
            await websocket.send_text(json.dumps({
                "type": "error",
                "payload": "Game not found"
            }))
            await websocket.close()
            return
        
        # LÆ°u game_id Ä'á»ƒ sá»­ dá»¥ng sau
        game_id = game.id
        
        # TÃ¬m match Ä'ang waiting
        match = await db.scalar(
            select(Match)
            .where(Match.game_id == game_id)
            .where(Match.status == MatchStatus.waiting)
        )
        
        match_id = None
        is_match_ready = False
        
        if not match:
            # Táº¡o match má»›i
            new_match = Match(
                game_id=game_id,
                board_rows=15,
                board_cols=19,
                win_len=5,
                status=MatchStatus.waiting,
                created_at=datetime.now(timezone.utc),
            )
            db.add(new_match)
            await db.flush()
            match_id = new_match.id
            print(f"âœ¨ Created new match {match_id} for user {user_id}")
        else:
            match_id = match.id
            print(f"ðŸ'¥ User {user_id} joining existing match {match_id}")
        
        # Kiá»ƒm tra user Ä‘Ã£ trong match chÆ°a
        exists = await db.scalar(
            select(MatchPlayer).where(
                MatchPlayer.match_id == match_id,
                MatchPlayer.user_id == user_id,
            )
        )
        
        if not exists:
            # Äáº¿m sá»‘ ngÆ°á»i chÆ¡i hiá»‡n táº¡i
            current_players = await db.execute(
                select(MatchPlayer).where(MatchPlayer.match_id == match_id)
            )
            player_count = len(current_players.all())
            symbol = "X" if player_count == 0 else "O"
            
            # ThÃªm player
            db.add(MatchPlayer(
                match_id=match_id,
                user_id=user_id,
                symbol=symbol
            ))
            
            # Náº¿u Ä‘á»§ 2 ngÆ°á»i -> match ready
            if player_count + 1 == 2:
                is_match_ready = True
                await db.execute(
                    update(Match)
                    .where(Match.id == match_id)
                    .values(status=MatchStatus.playing, started_at=datetime.now(timezone.utc))
                )
            
            await db.commit()
            print(f"âœ… User {user_id} added to match {match_id} as {symbol}")
        
        # Náº¿u match Ä'Ã£ ready, thÃ´ng bÃ¡o cho Cáº¢ 2 ngÆ°á»i chÆ¡i
        if is_match_ready:
            # Láº¥y thÃ´ng tin cáº£ 2 players
            players_result = await db.execute(
                select(MatchPlayer, User)
                .join(User, User.id == MatchPlayer.user_id)
                .where(MatchPlayer.match_id == match_id)
            )
            players_data = players_result.all()
            
            players_info = []
            for mp, user in players_data:
                # Láº¥y rating riÃªng biá»‡t Ä'á»ƒ trÃ¡nh lá»—i greenlet
                rating_obj = await db.scalar(
                    select(UserGameRating.rating)
                    .where(UserGameRating.user_id == user.id)
                    .where(UserGameRating.game_id == game_id)
                )
                
                players_info.append({
                    "user_id": user.id,
                    "username": user.username,
                    "avatar_url": user.avatar_url,
                    "symbol": mp.symbol,
                    "rating": rating_obj if rating_obj is not None else 1200,
                })
            
            match_ready_msg = json.dumps({
                "type": "match_found",
                "payload": {
                    "match_id": match_id,
                    "players": players_info,
                    "message": "Match found! Starting game..."
                }
            })
            
            # Gá»­i cho táº¥t cáº£ players trong matchmaking queue
            for mp, user in players_data:
                if mp.user_id in matchmaking_queue:
                    try:
                        await matchmaking_queue[mp.user_id].send_text(match_ready_msg)
                        print(f"âœ‰ï¸ Sent match_found to user {mp.user_id}")
                    except Exception as e:
                        print(f"âš ï¸ Failed to notify user {mp.user_id}: {e}")
            
            # Äá»£i 2 giÃ¢y rá»“i Ä‘Ã³ng connection
            await asyncio.sleep(2)
            await websocket.close()
            matchmaking_queue.pop(user_id, None)
            return
        
        # Náº¿u chÆ°a Ä'á»§ ngÆ°á»i, giá»¯ connection vÃ  Ä'á»£i
        while True:
            try:
                # Äá»£i message tá»« client hoáº·c timeout Ä'á»ƒ check status
                try:
                    raw = await asyncio.wait_for(websocket.receive_text(), timeout=3.0)
                    msg = json.loads(raw)
                    
                    # Xá»­ lÃ½ message cancel
                    if msg.get("type") == "cancel":
                        print(f"âŒ User {user_id} cancelled matchmaking")
                        
                        # XÃ³a user khá»i match náº¿u chÆ°a cÃ³ Ä'á»'i thá»§
                        from sqlalchemy import delete
                        player_result = await db.execute(
                            select(MatchPlayer).where(MatchPlayer.match_id == match_id)
                        )
                        player_count = len(player_result.all())
                        
                        if player_count == 1:
                            # Chá»‰ cÃ³ 1 ngÆ°á»i -> xÃ³a luÃ´n match
                            await db.execute(delete(MatchPlayer).where(MatchPlayer.match_id == match_id))
                            await db.execute(delete(Match).where(Match.id == match_id))
                            await db.commit()
                            print(f"ðŸ—'ï¸ Deleted empty match {match_id}")
                        
                        await websocket.send_text(json.dumps({
                            "type": "cancelled",
                            "payload": {"message": "Matchmaking cancelled"}
                        }))
                        break
                        
                except asyncio.TimeoutError:
                    # Timeout - gá»­i ping vÃ  tiáº¿p tá»¥c
                    await websocket.send_text(json.dumps({"type": "ping"}))
                except json.JSONDecodeError:
                    # Invalid JSON - ignore
                    pass
                
                # Kiá»ƒm tra match Ä'Ã£ cÃ³ Ä'á»§ ngÆ°á»i chÆ°a
                match_check = await db.scalar(select(Match).where(Match.id == match_id))
                if match_check and match_check.status == MatchStatus.playing:
                    # Match Ä'Ã£ sáºµn sÃ ng
                    players_result = await db.execute(
                        select(MatchPlayer, User)
                        .join(User, User.id == MatchPlayer.user_id)
                        .where(MatchPlayer.match_id == match_id)
                    )
                    players_data = players_result.all()
                    
                    players_info = []
                    for mp, user in players_data:
                        # Láº¥y rating riÃªng biá»‡t
                        rating_obj = await db.scalar(
                            select(UserGameRating.rating)
                            .where(UserGameRating.user_id == user.id)
                            .where(UserGameRating.game_id == game_id)
                        )
                        
                        players_info.append({
                            "user_id": user.id,
                            "username": user.username,
                            "avatar_url": user.avatar_url,
                            "symbol": mp.symbol,
                            "rating": rating_obj if rating_obj is not None else 1200,
                        })
                    
                    await websocket.send_text(json.dumps({
                        "type": "match_found",
                        "payload": {
                            "match_id": match_id,
                            "players": players_info,
                            "message": "Match found! Starting game..."
                        }
                    }))
                    
                    await asyncio.sleep(2)
                    break
                
            except WebSocketDisconnect:
                break
            except Exception as e:
                print(f"âŒ Error in matchmaking: {e}")
                break
    
    except WebSocketDisconnect:
        print(f"ðŸšª User {user_id} left matchmaking queue")
    except Exception as e:
        print(f"âŒ Error in matchmaking handler: {e}")
    finally:
        # Cleanup
        matchmaking_queue.pop(user_id, None)
        try:
            await websocket.close()
        except:
            pass



@router.websocket("/notifications")
async def websocket_notifications(
    websocket: WebSocket,
    token: str = Query(...),
):
    """WebSocket endpoint cho notifications real-time."""
    # Auth
    try:
        await websocket.accept()
        user_id = await decode_token(token)
    except ValueError:
        await websocket.close(code=4001)
        return
    
    print(f"ðŸ"" User {user_id} connected to notifications")
    
    # Äóng connection cÅ© náº¿u cÃ³
    if user_id in notification_connections:
        try:
            await notification_connections[user_id].close()
        except:
            pass
    
    # ThÃªm connection má»›i
    notification_connections[user_id] = websocket
    
    try:
        # Giá»¯ connection vÃ  nghe ping
        while True:
            try:
                raw = await asyncio.wait_for(websocket.receive_text(), timeout=30.0)
                msg = json.loads(raw)
                
                # Respond to ping
                if msg.get("type") == "ping":
                    await websocket.send_text(json.dumps({"type": "pong"}))
                    
            except asyncio.TimeoutError:
                # Send ping to keep alive
                await websocket.send_text(json.dumps({"type": "ping"}))
            except json.JSONDecodeError:
                pass
                
    except WebSocketDisconnect:
        print(f"ðŸšª User {user_id} disconnected from notifications")
    except Exception as e:
        print(f"âŒ Error in notifications handler: {e}")
    finally:
        notification_connections.pop(user_id, None)
        try:
            await websocket.close()
        except:
            pass

async def send_notification(user_id: int, notification: dict):
    """Gá»­i notification cho user qua WebSocket."""
    if user_id in notification_connections:
        try:
            await notification_connections[user_id].send_text(json.dumps(notification))
            print(f"âœ‰ï¸ Sent notification to user {user_id}: {notification.get('type')}")
        except Exception as e:
            print(f"âš ï¸ Failed to send notification to user {user_id}: {e}")
            notification_connections.pop(user_id, None)



