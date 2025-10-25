-- Migration: Add Friend System Tables
-- Date: 2025-01-25

-- Create Enum for Friend Request Status
CREATE TYPE friendrequeststatus AS ENUM ('pending', 'accepted', 'rejected');

-- Create Friend Requests Table
CREATE TABLE IF NOT EXISTS friend_requests (
    id SERIAL PRIMARY KEY,
    sender_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    receiver_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    status friendrequeststatus NOT NULL DEFAULT 'pending',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    CONSTRAINT ck_no_self_friend_request CHECK (sender_id != receiver_id),
    CONSTRAINT uq_friend_request_once UNIQUE (sender_id, receiver_id)
);

-- Create indexes for friend_requests
CREATE INDEX ix_friend_requests_receiver_status ON friend_requests(receiver_id, status);
CREATE INDEX ix_friend_requests_sender ON friend_requests(sender_id);

-- Create Friends Table
CREATE TABLE IF NOT EXISTS friends (
    id SERIAL PRIMARY KEY,
    user1_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    user2_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    CONSTRAINT ck_user1_less_than_user2 CHECK (user1_id < user2_id),
    CONSTRAINT uq_friendship_once UNIQUE (user1_id, user2_id)
);

-- Create indexes for friends
CREATE INDEX ix_friends_user1 ON friends(user1_id);
CREATE INDEX ix_friends_user2 ON friends(user2_id);

-- Comments
COMMENT ON TABLE friend_requests IS 'Lời mời kết bạn giữa users';
COMMENT ON TABLE friends IS 'Quan hệ bạn bè (user1_id < user2_id để tránh duplicate)';
