from fastapi import FastAPI
from app.core.database import init_db
from app.core.middleware import setup_cors
from app.api import auth, auth_google, users, games, scores

app = FastAPI(title="GamePlus API", version="1.0.0")

@app.on_event("startup")
async def startup_event():
    await init_db()

setup_cors(app)

# Routers
app.include_router(auth.router)
app.include_router(auth_google.router)
app.include_router(users.router)
app.include_router(games.router)
app.include_router(scores.router)

@app.get("/api/test-db")
async def test_db():
    return {"status": "Database OK"}
