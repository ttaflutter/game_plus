#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
Fix WebSocket broadcast function với logs chi tiết
"""

import os

file_path = "app/api/realtime.py"

# Đọc file
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# Replace broadcast_room_update function
old_function = '''async def broadcast_room_update(room_data: dict, update_type: str = "update"):
    """Broadcast room updates đến tất cả clients đang xem room list."""
    message = {
        "type": f"room_{update_type}",  # room_update, room_created, room_deleted
        "payload": room_data
    }
    data = json.dumps(message)
    
    for user_id, ws in list(room_list_connections.items()):
        try:
            await ws.send_text(data)
        except Exception as e:
            print(f"⚠️ Failed to send room update to user {user_id}: {e}")
            room_list_connections.pop(user_id, None)'''

new_function = '''async def broadcast_room_update(room_data: dict, update_type: str = "update"):
    """Broadcast room updates đến tất cả clients đang xem room list."""
    if not room_list_connections:
        print(f"⚠️ No room list connections to broadcast to")
        return
    
    message = {
        "type": f"room_{update_type}",
        "payload": room_data
    }
    data = json.dumps(message)
    
    print(f"📢 Broadcasting room_{update_type} to {len(room_list_connections)} clients: Room {room_data.get('id')}")
    
    disconnected = []
    for user_id, ws in list(room_list_connections.items()):
        try:
            await ws.send_text(data)
            print(f"  ✅ Sent to user {user_id}")
        except Exception as e:
            print(f"  ⚠️ Failed to send to user {user_id}: {e}")
            disconnected.append(user_id)
    
    # Cleanup disconnected
    for user_id in disconnected:
        room_list_connections.pop(user_id, None)
    
    print(f"📊 Broadcast complete. Active connections: {len(room_list_connections)}")'''

if old_function in content:
    content = content.replace(old_function, new_function)
    print("✅ Replaced broadcast_room_update function")
else:
    print("❌ Could not find old function - trying with Vietnamese characters")
    # Try with encoded characters
    lines = content.split('\n')
    for i, line in enumerate(lines):
        if 'async def broadcast_room_update' in line:
            print(f"Found function at line {i+1}")
            # Find end of function (next function or end of file)
            end_idx = i + 1
            indent_level = len(line) - len(line.lstrip())
            for j in range(i + 1, len(lines)):
                if lines[j].strip() and not lines[j].startswith(' ' * (indent_level + 1)) and not lines[j].startswith('\t'):
                    end_idx = j
                    break
            
            # Replace from async def to end
            new_lines = lines[:i] + new_function.split('\n') + lines[end_idx:]
            content = '\n'.join(new_lines)
            print("✅ Replaced using line-by-line method")
            break

# Write back
with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("✅ File updated successfully!")
print("\nNext steps:")
print("1. Restart uvicorn server")
print("2. Test WebSocket connection")
print("3. Check logs for '📢 Broadcasting' messages")
