from fastapi import FastAPI
from app.core.database import init_db
from app.core.middleware import setup_cors
from app.api import (
    auth, auth_google, users, games, scores, realtime, 
    matches, friends, leaderboard, match_history, profile, rooms
)

app = FastAPI(title="GamePlus API", version="1.0.0")

# Setup CORS TRƯỚC KHI init DB
setup_cors(app)

@app.on_event("startup")
async def startup_event():
    await init_db()

# Routers
app.include_router(auth.router)
app.include_router(auth_google.router)
app.include_router(users.router)
app.include_router(games.router)
app.include_router(scores.router)
app.include_router(realtime.router)
app.include_router(matches.router)
app.include_router(friends.router)
app.include_router(leaderboard.router)
app.include_router(match_history.router)
app.include_router(profile.router)
app.include_router(rooms.router)

@app.get("/api/test-db")
async def test_db():
    return {"status": "Database OK"}
