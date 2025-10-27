-- Migration: Add Room System
-- Created: 2025-10-26

-- Create room_status enum
CREATE TYPE room_status AS ENUM ('waiting', 'playing', 'finished');

-- Create rooms table
CREATE TABLE rooms (
    id SERIAL PRIMARY KEY,
    room_code VARCHAR(6) UNIQUE NOT NULL,
    room_name VARCHAR(100) NOT NULL,
    host_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    game_id INTEGER NOT NULL REFERENCES games(id) ON DELETE CASCADE,
    
    -- Room settings
    password VARCHAR(255),
    is_public BOOLEAN DEFAULT TRUE,
    max_players INTEGER DEFAULT 2,
    board_rows INTEGER DEFAULT 15,
    board_cols INTEGER DEFAULT 19,
    win_len INTEGER DEFAULT 5,
    
    -- Status
    status room_status NOT NULL DEFAULT 'waiting',
    match_id INTEGER REFERENCES matches(id) ON DELETE SET NULL,
    
    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    started_at TIMESTAMP WITH TIME ZONE,
    finished_at TIMESTAMP WITH TIME ZONE,
    
    -- Constraints
    CONSTRAINT ck_room_max_players CHECK (max_players >= 2 AND max_players <= 4)
);

-- Create room_players table
CREATE TABLE room_players (
    room_id INTEGER NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    is_ready BOOLEAN DEFAULT FALSE,
    joined_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    PRIMARY KEY (room_id, user_id)
);

-- Indexes
CREATE INDEX ix_rooms_room_code ON rooms(room_code);
CREATE INDEX ix_rooms_status ON rooms(status);
CREATE INDEX ix_rooms_host ON rooms(host_id);
CREATE INDEX ix_room_players_user ON room_players(user_id);

-- Comments
COMMENT ON TABLE rooms IS 'Phòng chơi với room code, host, và settings';
COMMENT ON TABLE room_players IS 'Người chơi trong phòng với trạng thái ready';
COMMENT ON COLUMN rooms.room_code IS 'Mã phòng 6 ký tự để join';
COMMENT ON COLUMN rooms.password IS 'Hash của password nếu phòng có mật khẩu';
COMMENT ON COLUMN rooms.is_public IS 'Phòng công khai hay riêng tư';
COMMENT ON COLUMN room_players.is_ready IS 'Trạng thái sẵn sàng của người chơi';
