"""
Test Room WebSocket - Real-time updates
"""
import asyncio
import websockets
import json
import sys

async def test_room_websocket():
    # Replace with your JWT token
    token = input("Enter your JWT token: ").strip()
    
    if not token:
        print("❌ Token required!")
        return
    
    uri = f"ws://localhost:8000/ws/rooms?token={token}"
    
    try:
        async with websockets.connect(uri) as websocket:
            print("✅ Connected to room WebSocket!")
            print("📋 Listening for room updates...\n")
            
            # Lắng nghe messages
            async for message in websocket:
                try:
                    data = json.loads(message)
                    msg_type = data.get("type")
                    
                    if msg_type == "rooms_list":
                        rooms = data["payload"]["rooms"]
                        print(f"📜 Room List ({len(rooms)} rooms):")
                        for room in rooms:
                            print(f"  - [{room['id']}] {room['name']} ({room['current_players']}/{room['max_players']}) - {room['status']}")
                        print()
                        
                    elif msg_type == "room_created":
                        room = data["payload"]
                        print(f"🆕 Room Created: [{room['id']}] {room['name']} by {room['host_username']}")
                        print()
                        
                    elif msg_type == "room_update":
                        room = data["payload"]
                        print(f"🔄 Room Updated: [{room['id']}] {room['name']} - {room['current_players']}/{room['max_players']} players - {room['status']}")
                        print()
                        
                    elif msg_type == "room_deleted":
                        room = data["payload"]
                        print(f"🗑️ Room Deleted: [{room['id']}] {room['name']}")
                        print()
                        
                    elif msg_type == "ping":
                        # Send pong
                        await websocket.send(json.dumps({"type": "pong"}))
                        
                    elif msg_type == "pong":
                        print("💓 Pong received")
                        
                    else:
                        print(f"❓ Unknown message type: {msg_type}")
                        print(f"   Data: {data}")
                        print()
                        
                except json.JSONDecodeError:
                    print(f"❌ Invalid JSON: {message}")
                except Exception as e:
                    print(f"❌ Error processing message: {e}")
                    
    except websockets.exceptions.InvalidStatusCode as e:
        if e.status_code == 403:
            print("❌ Authentication failed! Invalid token.")
        else:
            print(f"❌ Connection error: {e}")
    except Exception as e:
        print(f"❌ Error: {e}")

if __name__ == "__main__":
    print("🧪 Room WebSocket Test Client")
    print("=" * 50)
    print()
    
    try:
        asyncio.run(test_room_websocket())
    except KeyboardInterrupt:
        print("\n\n👋 Disconnected!")
