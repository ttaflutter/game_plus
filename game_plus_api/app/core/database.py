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

# 🚀 Tạo engine và session với connection pooling tối ưu cho 50 concurrent users
engine = create_async_engine(
    DATABASE_URL,
    echo=False,  # Tắt echo trong production để giảm overhead
    future=True,
    pool_size=20,  # Số connections pool mặc định (tăng từ 5 lên 20)
    max_overflow=10,  # Số connections tạm thời thêm khi cần (tăng từ 10 lên 10)
    pool_pre_ping=True,  # Kiểm tra connection trước khi dùng
    pool_recycle=3600,  # Recycle connections sau 1 giờ để tránh stale
)
AsyncSessionLocal = sessionmaker(
    autocommit=False,
    autoflush=False,
    bind=engine,
    class_=AsyncSession,
    expire_on_commit=False,  # Giảm lazy loading issues
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
