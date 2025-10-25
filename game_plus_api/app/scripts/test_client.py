"""
Test WebSocket Client cho game Caro
Chạy 2 instances này để test 2 người chơi
"""
import asyncio
import json
import websockets
import requests
from datetime import datetime

# ===== CONFIG =====
API_BASE = "http://localhost:8000"
WS_BASE = "ws://localhost:8000"

# Test users - thay đổi credentials tùy ý
USERNAME = "player1"
PASSWORD = "password123"
# ==================

def get_token():
    """Login và lấy JWT token"""
    try:
        response = requests.post(
            f"{API_BASE}/api/auth/login",
            json={"username": USERNAME, "password": PASSWORD}
        )
        if response.status_code == 200:
            return response.json()["access_token"]
        else:
            print(f"❌ Login failed: {response.json()}")
            return None
    except Exception as e:
        print(f"❌ Error during login: {e}")
        return None

def quick_join():
    """Tìm/tạo trận đấu"""
    token = get_token()
    if not token:
        return None, None
    
    try:
        response = requests.post(
            f"{API_BASE}/api/matches/join",
            headers={"Authorization": f"Bearer {token}"}
        )
        if response.status_code == 200:
            data = response.json()
            print(f"✅ Joined match {data['match_id']}, status: {data['status']}")
            return data["match_id"], token
        else:
            print(f"❌ Join failed: {response.json()}")
            return None, None
    except Exception as e:
        print(f"❌ Error joining match: {e}")
        return None, None

async def play_game(match_id: int, token: str):
    """Kết nối WebSocket và chơi game"""
    uri = f"{WS_BASE}/ws/match/{match_id}?token={token}"
    
    print(f"🔌 Connecting to {uri}")
    
    async with websockets.connect(uri) as websocket:
        print("✅ Connected!")
        
        # Nhận snapshot đầu tiên
        msg = await websocket.recv()
        data = json.loads(msg)
        print(f"📩 Received: {data['type']}")
        
        if data['type'] == 'joined':
            payload = data['payload']
            print(f"👤 You are: {payload['you']}")
            print(f"👥 Players: {payload['players']}")
            print(f"🎯 Current turn: {payload['turn']}")
            print(f"📊 Status: {payload['status']}")
            
            if payload.get('board'):
                print("🎲 Board loaded from DB")
        
        # Task để nhận message
        async def receive_messages():
            try:
                while True:
                    msg = await websocket.recv()
                    data = json.loads(msg)
                    timestamp = datetime.now().strftime("%H:%M:%S")
                    
                    if data['type'] == 'start':
                        print(f"\n[{timestamp}] 🎮 Game started!")
                        print(f"   Turn: {data['payload']['turn']}")
                        print(f"   Time limit: {data['payload']['time_limit']}s")
                    
                    elif data['type'] == 'move':
                        p = data['payload']
                        print(f"\n[{timestamp}] ♟️  Move: {p['symbol']} at ({p['x']}, {p['y']})")
                        print(f"   Turn #{p['turn_no']}")
                        print(f"   Next: {p['next_turn']} ({p['time_limit']}s)")
                    
                    elif data['type'] == 'win':
                        p = data['payload']
                        print(f"\n[{timestamp}] 🏆 WINNER: User {p['winner_user_id']} ({p['symbol']})")
                        print(f"   Winning line: {p['line']}")
                        break
                    
                    elif data['type'] == 'draw':
                        print(f"\n[{timestamp}] 🤝 DRAW!")
                        print(f"   Reason: {data['payload'].get('reason', 'N/A')}")
                        break
                    
                    elif data['type'] == 'timeout':
                        p = data['payload']
                        print(f"\n[{timestamp}] ⏰ TIMEOUT!")
                        print(f"   Loser: User {p['loser_user_id']}")
                        print(f"   Winner: User {p['winner_user_id']}")
                        break
                    
                    elif data['type'] == 'surrender':
                        p = data['payload']
                        print(f"\n[{timestamp}] 🏳️  SURRENDER!")
                        print(f"   Surrendered: User {p['surrendered_user_id']}")
                        print(f"   Winner: User {p['winner_user_id']}")
                        break
                    
                    elif data['type'] == 'disconnect':
                        p = data['payload']
                        print(f"\n[{timestamp}] 🔌 DISCONNECT!")
                        print(f"   Disconnected: User {p['disconnected_user_id']}")
                        print(f"   Winner: User {p['winner_user_id']}")
                        break
                    
                    elif data['type'] == 'chat':
                        p = data['payload']
                        print(f"\n[{timestamp}] 💬 Chat from User {p['from']}: {p['message']}")
                    
                    elif data['type'] == 'error':
                        print(f"\n[{timestamp}] ❌ Error: {data['payload']}")
                    
                    elif data['type'] == 'pong':
                        print(f"[{timestamp}] 🏓 Pong")
                    
                    else:
                        print(f"\n[{timestamp}] 📩 {data}")
            
            except websockets.exceptions.ConnectionClosed:
                print("\n🔌 Connection closed")
        
        # Task để gửi command
        async def send_commands():
            await asyncio.sleep(1)
            print("\n" + "="*50)
            print("📝 Commands:")
            print("   move <x> <y>  - Make a move")
            print("   chat <msg>    - Send chat message")
            print("   surrender     - Give up")
            print("   ping          - Test connection")
            print("   quit          - Exit")
            print("="*50 + "\n")
            
            try:
                while True:
                    cmd = await asyncio.get_event_loop().run_in_executor(
                        None, input, "Enter command: "
                    )
                    
                    if cmd.lower() == 'quit':
                        break
                    
                    elif cmd.startswith('move '):
                        parts = cmd.split()
                        if len(parts) == 3:
                            x, y = int(parts[1]), int(parts[2])
                            await websocket.send(json.dumps({
                                "type": "move",
                                "payload": {"x": x, "y": y}
                            }))
                            print(f"⬆️  Sent move: ({x}, {y})")
                    
                    elif cmd.startswith('chat '):
                        message = cmd[5:].strip()
                        await websocket.send(json.dumps({
                            "type": "chat",
                            "payload": {"message": message}
                        }))
                        print(f"⬆️  Sent chat")
                    
                    elif cmd == 'surrender':
                        await websocket.send(json.dumps({
                            "type": "surrender",
                            "payload": {}
                        }))
                        print(f"⬆️  Surrendered")
                        break
                    
                    elif cmd == 'ping':
                        await websocket.send(json.dumps({
                            "type": "ping",
                            "payload": {}
                        }))
                        print(f"⬆️  Sent ping")
                    
                    else:
                        print("❓ Unknown command")
            
            except KeyboardInterrupt:
                print("\n👋 Interrupted")
        
        # Chạy cả 2 tasks
        await asyncio.gather(
            receive_messages(),
            send_commands()
        )

def main():
    print("🎮 Caro WebSocket Test Client")
    print("=" * 50)
    
    # Login và join match
    match_id, token = quick_join()
    
    if not match_id or not token:
        print("❌ Failed to join match")
        return
    
    print(f"\n🎯 Match ID: {match_id}")
    print("Starting WebSocket connection...\n")
    
    # Chơi game
    try:
        asyncio.run(play_game(match_id, token))
    except KeyboardInterrupt:
        print("\n👋 Goodbye!")
    except Exception as e:
        print(f"\n❌ Error: {e}")

if __name__ == "__main__":
    main()
