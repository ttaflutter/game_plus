from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine
from sqlalchemy.orm import sessionmaker, declarative_base
from sqlalchemy import text
import os
from dotenv import load_dotenv

# 🔧 Load biến môi trường từ .env
load_dotenv()

DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "postgresql+asyncpg://admin:Admin123@@localhost:5432/gameplus_db"
)

# 🚀 Tạo engine và session
engine = create_async_engine(DATABASE_URL, echo=True, future=True)
AsyncSessionLocal = sessionmaker(
    autocommit=False,
    autoflush=False,
    bind=engine,
    class_=AsyncSession
)

# 🧱 Base class cho tất cả models
Base = declarative_base()

# ⚙️ Dependency cho FastAPI
async def get_db():
    async with AsyncSessionLocal() as session:
        yield session

# 🏗️ Hàm khởi tạo DB
async def init_db():
    async with engine.begin() as conn:
        # Tạo tất cả các bảng nếu chưa có
        await conn.run_sync(Base.metadata.create_all)
        # Test query nhỏ để đảm bảo DB hoạt động
        await conn.execute(text("SELECT 1"))
    print("✅ Database initialized successfully!")
