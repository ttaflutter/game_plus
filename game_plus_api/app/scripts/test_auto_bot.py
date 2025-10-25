"""
Auto Bot Test - Tự động chơi game Caro
Bot sẽ tự động đánh ngẫu nhiên vào ô trống
"""
import asyncio
import json
import websockets
import requests
import random
from datetime import datetime

# ===== CONFIG =====
API_BASE = "http://localhost:8000"
WS_BASE = "ws://localhost:8000"

# Bot credentials
BOT_USERNAME = "bot1"
BOT_PASSWORD = "botpass123"

# Board config
BOARD_ROWS = 15
BOARD_COLS = 19
# ==================

def get_token(username, password):
    """Login và lấy JWT token"""
    try:
        response = requests.post(
            f"{API_BASE}/api/auth/login",
            json={"username": username, "password": password}
        )
        if response.status_code == 200:
            return response.json()["access_token"]
        else:
            print(f"❌ Login failed for {username}")
            return None
    except Exception as e:
        print(f"❌ Error during login: {e}")
        return None

def quick_join(token):
    """Tìm/tạo trận đấu"""
    try:
        response = requests.post(
            f"{API_BASE}/api/matches/join",
            headers={"Authorization": f"Bearer {token}"}
        )
        if response.status_code == 200:
            data = response.json()
            print(f"✅ Joined match {data['match_id']}")
            return data["match_id"]
        else:
            print(f"❌ Join failed: {response.json()}")
            return None
    except Exception as e:
        print(f"❌ Error joining match: {e}")
        return None

class CaroBot:
    def __init__(self, name: str):
        self.name = name
        self.board = [["" for _ in range(BOARD_COLS)] for _ in range(BOARD_ROWS)]
        self.my_symbol = None
        self.my_turn = False
    
    def update_board(self, x: int, y: int, symbol: str):
        """Cập nhật bàn cờ"""
        if 0 <= x < BOARD_ROWS and 0 <= y < BOARD_COLS:
            self.board[x][y] = symbol
    
    def get_random_move(self):
        """Lấy nước đi ngẫu nhiên"""
        empty_cells = []
        for i in range(BOARD_ROWS):
            for j in range(BOARD_COLS):
                if not self.board[i][j]:
                    empty_cells.append((i, j))
        
        if empty_cells:
            return random.choice(empty_cells)
        return None
    
    def get_smart_move(self):
        """Lấy nước đi thông minh hơn - block đối thủ hoặc tạo cơ hội"""
        # Đơn giản: ưu tiên ô gần tâm bàn cờ
        center_x, center_y = BOARD_ROWS // 2, BOARD_COLS // 2
        
        # Tìm ô trống gần trung tâm nhất
        best_move = None
        min_dist = float('inf')
        
        for i in range(max(0, center_x - 5), min(BOARD_ROWS, center_x + 5)):
            for j in range(max(0, center_y - 5), min(BOARD_COLS, center_y + 5)):
                if not self.board[i][j]:
                    dist = abs(i - center_x) + abs(j - center_y)
                    if dist < min_dist:
                        min_dist = dist
                        best_move = (i, j)
        
        return best_move if best_move else self.get_random_move()

async def bot_play(bot_name: str, username: str, password: str, smart: bool = True):
    """Bot tự động chơi"""
    print(f"🤖 [{bot_name}] Starting...")
    
    # Login
    token = get_token(username, password)
    if not token:
        return
    
    # Join match
    match_id = quick_join(token)
    if not match_id:
        return
    
    # Connect WebSocket
    uri = f"{WS_BASE}/ws/match/{match_id}?token={token}"
    print(f"🔌 [{bot_name}] Connecting to match {match_id}")
    
    bot = CaroBot(bot_name)
    
    try:
        async with websockets.connect(uri) as websocket:
            print(f"✅ [{bot_name}] Connected!")
            
            while True:
                try:
                    msg = await asyncio.wait_for(websocket.recv(), timeout=35)
                    data = json.loads(msg)
                    timestamp = datetime.now().strftime("%H:%M:%S")
                    
                    if data['type'] == 'joined':
                        payload = data['payload']
                        bot.my_symbol = payload['you'].get('symbol')
                        print(f"👤 [{bot_name}] Symbol: {bot.my_symbol}")
                        
                        # Load board nếu có
                        if payload.get('board'):
                            bot.board = payload['board']
                            print(f"📋 [{bot_name}] Board loaded")
                        
                        bot.my_turn = (payload['turn'] == bot.my_symbol and payload['status'] == 'playing')
                    
                    elif data['type'] == 'start':
                        print(f"🎮 [{bot_name}] Game started!")
                        bot.my_turn = (data['payload']['turn'] == bot.my_symbol)
                        
                        # Nếu là lượt của bot, đánh ngay
                        if bot.my_turn:
                            await asyncio.sleep(random.uniform(0.5, 2.0))  # Delay ngẫu nhiên
                            move = bot.get_smart_move() if smart else bot.get_random_move()
                            if move:
                                x, y = move
                                await websocket.send(json.dumps({
                                    "type": "move",
                                    "payload": {"x": x, "y": y}
                                }))
                                print(f"♟️  [{bot_name}] Moved to ({x}, {y})")
                    
                    elif data['type'] == 'move':
                        p = data['payload']
                        bot.update_board(p['x'], p['y'], p['symbol'])
                        print(f"📍 [{bot_name}] Opponent moved: ({p['x']}, {p['y']})")
                        
                        bot.my_turn = (p['next_turn'] == bot.my_symbol)
                        
                        # Nếu là lượt của bot
                        if bot.my_turn:
                            await asyncio.sleep(random.uniform(0.5, 2.0))
                            move = bot.get_smart_move() if smart else bot.get_random_move()
                            if move:
                                x, y = move
                                await websocket.send(json.dumps({
                                    "type": "move",
                                    "payload": {"x": x, "y": y}
                                }))
                                print(f"♟️  [{bot_name}] Moved to ({x}, {y})")
                    
                    elif data['type'] == 'win':
                        winner = data['payload']['winner_user_id']
                        print(f"🏆 [{bot_name}] Game over! Winner: {winner}")
                        break
                    
                    elif data['type'] == 'draw':
                        print(f"🤝 [{bot_name}] Game over! Draw")
                        break
                    
                    elif data['type'] == 'timeout':
                        print(f"⏰ [{bot_name}] Game over! Timeout")
                        break
                    
                    elif data['type'] == 'surrender':
                        print(f"🏳️  [{bot_name}] Game over! Someone surrendered")
                        break
                    
                    elif data['type'] == 'disconnect':
                        print(f"🔌 [{bot_name}] Game over! Disconnect")
                        break
                    
                    elif data['type'] == 'error':
                        print(f"❌ [{bot_name}] Error: {data['payload']}")
                
                except asyncio.TimeoutError:
                    print(f"⏰ [{bot_name}] Timeout waiting for message")
                    break
    
    except Exception as e:
        print(f"❌ [{bot_name}] Error: {e}")

async def run_bot_match():
    """Chạy 2 bots đấu với nhau"""
    print("🤖 Starting Bot Match")
    print("=" * 50)
    
    # Chạy 2 bots song song
    await asyncio.gather(
        bot_play("Bot1", "bot1", "botpass123", smart=True),
        bot_play("Bot2", "bot2", "botpass123", smart=True)
    )
    
    print("\n✅ Match completed!")

def main():
    """Main entry point"""
    try:
        asyncio.run(run_bot_match())
    except KeyboardInterrupt:
        print("\n👋 Interrupted")
    except Exception as e:
        print(f"\n❌ Error: {e}")

if __name__ == "__main__":
    main()
