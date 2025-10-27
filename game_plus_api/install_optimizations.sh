#!/bin/bash
# install_optimizations.sh
# Bash script to install dependencies for performance optimizations

echo "🚀 Installing GamePlus API Performance Optimizations..."

# 1. Install Python packages
echo ""
echo "📦 Installing Python dependencies..."
pip install -r requirements.txt

# 2. Check Redis
echo ""
echo "🔍 Checking Redis..."
if command -v redis-server &> /dev/null; then
    if pgrep -x "redis-server" > /dev/null; then
        echo "✅ Redis is already running!"
    else
        echo "⚠️  Redis installed but not running. Start with: redis-server"
    fi
else
    echo "⚠️  Redis not found. Please install Redis:"
    echo "   Ubuntu/Debian: sudo apt install redis-server"
    echo "   macOS: brew install redis"
    echo "   Or use Docker: docker run -d -p 6379:6379 redis"
fi

# 3. Check PostgreSQL
echo ""
echo "🔍 Checking PostgreSQL..."
if command -v psql &> /dev/null; then
    echo "✅ PostgreSQL is installed!"
else
    echo "⚠️  PostgreSQL not found"
fi

# 4. Create .env if not exists
echo ""
echo "📝 Checking .env file..."
if [ -f .env ]; then
    echo "✅ .env file exists"
else
    echo "⚠️  Creating .env template..."
    cat > .env << EOF
DATABASE_URL=postgresql+asyncpg://admin:Admin123@@localhost:5432/gameplus_db
REDIS_URL=redis://localhost:6379/0
SECRET_KEY=your-secret-key-change-this-in-production
EOF
    echo "✅ Created .env file - Please update it with your values"
fi

echo ""
echo "✅ Installation complete!"
echo ""
echo "📚 Next steps:"
echo "   1. Make sure Redis is running: redis-server"
echo "   2. Update .env with your database credentials"
echo "   3. Run development: python run_dev.py"
echo "   4. Run production: python run_production.py"
echo ""
echo "📖 Read OPTIMIZATION_SUMMARY.md for details"
