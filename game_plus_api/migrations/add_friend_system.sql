"""Add friend system tables

Revision ID: add_friend_system
Revises: 
Create Date: 2025-01-25

"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

def upgrade():
    # Create friend_requests table
    op.create_table(
        'friend_requests',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('sender_id', sa.Integer(), nullable=False),
        sa.Column('receiver_id', sa.Integer(), nullable=False),
        sa.Column('status', sa.Enum('pending', 'accepted', 'rejected', name='friendrequeststatus'), nullable=False),
        sa.Column('created_at', sa.TIMESTAMP(timezone=True), server_default=sa.text('now()'), nullable=True),
        sa.Column('updated_at', sa.TIMESTAMP(timezone=True), server_default=sa.text('now()'), nullable=True),
        sa.CheckConstraint('sender_id != receiver_id', name='ck_no_self_friend_request'),
        sa.ForeignKeyConstraint(['receiver_id'], ['users.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['sender_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('sender_id', 'receiver_id', name='uq_friend_request_once')
    )
    op.create_index('ix_friend_requests_receiver_status', 'friend_requests', ['receiver_id', 'status'])
    op.create_index('ix_friend_requests_sender', 'friend_requests', ['sender_id'])

    # Create friends table
    op.create_table(
        'friends',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('user1_id', sa.Integer(), nullable=False),
        sa.Column('user2_id', sa.Integer(), nullable=False),
        sa.Column('created_at', sa.TIMESTAMP(timezone=True), server_default=sa.text('now()'), nullable=True),
        sa.CheckConstraint('user1_id < user2_id', name='ck_user1_less_than_user2'),
        sa.ForeignKeyConstraint(['user1_id'], ['users.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['user2_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('user1_id', 'user2_id', name='uq_friendship_once')
    )
    op.create_index('ix_friends_user1', 'friends', ['user1_id'])
    op.create_index('ix_friends_user2', 'friends', ['user2_id'])

def downgrade():
    op.drop_index('ix_friends_user2', table_name='friends')
    op.drop_index('ix_friends_user1', table_name='friends')
    op.drop_table('friends')
    
    op.drop_index('ix_friend_requests_sender', table_name='friend_requests')
    op.drop_index('ix_friend_requests_receiver_status', table_name='friend_requests')
    op.drop_table('friend_requests')
    
    op.execute('DROP TYPE friendrequeststatus')
