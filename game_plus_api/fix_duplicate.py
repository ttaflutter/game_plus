#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
Fix duplicate broadcast_room_update function
"""

file_path = "app/api/realtime.py"

# Đọc file
with open(file_path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

# Tìm function broadcast_room_update
func_starts = []
for i, line in enumerate(lines):
    if 'async def broadcast_room_update' in line:
        func_starts.append(i)

print(f"Found {len(func_starts)} occurrences of broadcast_room_update")

if len(func_starts) > 1:
    print("Removing duplicate...")
    # Keep first occurrence, find where it ends
    start_idx = func_starts[0]
    
    # Tìm end của function đầu tiên (dòng trống hoặc function/class mới)
    end_idx = start_idx + 1
    indent_level = len(lines[start_idx]) - len(lines[start_idx].lstrip())
    
    for j in range(start_idx + 1, len(lines)):
        line = lines[j]
        if line.strip() == '':
            continue
        current_indent = len(line) - len(line.lstrip())
        if current_indent <= indent_level:
            end_idx = j
            break
    
    print(f"First function: lines {start_idx+1} to {end_idx+1}")
    print(f"Second function starts at: line {func_starts[1]+1}")
    
    # Xóa từ line end_idx đến hết second function
    second_start = func_starts[1]
    second_end = second_start + 1
    for j in range(second_start + 1, len(lines)):
        line = lines[j]
        if line.strip() == '':
            continue
        current_indent = len(line) - len(line.lstrip())
        if current_indent <= indent_level:
            second_end = j
            break
    
    # Remove duplicate (from end of first to end of second)
    new_lines = lines[:end_idx] + lines[second_end:]
    
    with open(file_path, 'w', encoding='utf-8') as f:
        f.writelines(new_lines)
    
    print(f"✅ Removed duplicate (lines {end_idx+1} to {second_end+1})")
else:
    print("✅ No duplicates found")

print("\n✅ Done!")
