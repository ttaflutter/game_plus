-- Migration: Add Challenge System Table
-- Date: 2025-01-25

-- Create Enum for Challenge Status
CREATE TYPE challengestatus AS ENUM ('pending', 'accepted', 'rejected', 'expired');

-- Create Challenges Table
CREATE TABLE IF NOT EXISTS challenges (
    id SERIAL PRIMARY KEY,
    challenger_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    opponent_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    game_id INTEGER NOT NULL REFERENCES games(id) ON DELETE CASCADE,
    match_id INTEGER REFERENCES matches(id) ON DELETE SET NULL,
    status challengestatus NOT NULL DEFAULT 'pending',
    message TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    expires_at TIMESTAMP WITH TIME ZONE,
    
    CONSTRAINT ck_no_self_challenge CHECK (challenger_id != opponent_id)
);

-- Create indexes for challenges
CREATE INDEX ix_challenges_opponent_status ON challenges(opponent_id, status);
CREATE INDEX ix_challenges_challenger ON challenges(challenger_id);
CREATE INDEX ix_challenges_match ON challenges(match_id);

-- Comments
COMMENT ON TABLE challenges IS 'Thách đấu giữa bạn bè';
COMMENT ON COLUMN challenges.expires_at IS 'Challenge tự động expire sau X phút';
COMMENT ON COLUMN challenges.match_id IS 'Match được tạo khi accept challenge';
