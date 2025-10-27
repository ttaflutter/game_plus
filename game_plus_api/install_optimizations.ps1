# install_optimizations.ps1
# PowerShell script để cài đặt các dependencies cho performance optimizations

Write-Host "🚀 Installing GamePlus API Performance Optimizations..." -ForegroundColor Green

# 1. Install Python packages
Write-Host "`n📦 Installing Python dependencies..." -ForegroundColor Cyan
pip install -r requirements.txt

# 2. Check Redis
Write-Host "`n🔍 Checking Redis..." -ForegroundColor Cyan
try {
    $redisRunning = Get-Process redis-server -ErrorAction SilentlyContinue
    if ($redisRunning) {
        Write-Host "✅ Redis is already running!" -ForegroundColor Green
    } else {
        Write-Host "⚠️  Redis not found. Please install Redis:" -ForegroundColor Yellow
        Write-Host "   Option 1: Use WSL - wsl sudo apt install redis-server" -ForegroundColor White
        Write-Host "   Option 2: Download from https://github.com/microsoftarchive/redis/releases" -ForegroundColor White
        Write-Host "   Option 3: Use Docker - docker run -d -p 6379:6379 redis" -ForegroundColor White
    }
} catch {
    Write-Host "⚠️  Could not check Redis status" -ForegroundColor Yellow
}

# 3. Check PostgreSQL
Write-Host "`n🔍 Checking PostgreSQL..." -ForegroundColor Cyan
try {
    $pgRunning = Get-Service postgresql* -ErrorAction SilentlyContinue | Where-Object {$_.Status -eq 'Running'}
    if ($pgRunning) {
        Write-Host "✅ PostgreSQL is running!" -ForegroundColor Green
    } else {
        Write-Host "⚠️  PostgreSQL might not be running" -ForegroundColor Yellow
    }
} catch {
    Write-Host "⚠️  Could not check PostgreSQL status" -ForegroundColor Yellow
}

# 4. Create .env if not exists
Write-Host "`n📝 Checking .env file..." -ForegroundColor Cyan
if (Test-Path .env) {
    Write-Host "✅ .env file exists" -ForegroundColor Green
} else {
    Write-Host "⚠️  Creating .env template..." -ForegroundColor Yellow
    @"
DATABASE_URL=postgresql+asyncpg://admin:Admin123@@localhost:5432/gameplus_db
REDIS_URL=redis://localhost:6379/0
SECRET_KEY=your-secret-key-change-this-in-production
"@ | Out-File -FilePath .env -Encoding UTF8
    Write-Host "✅ Created .env file - Please update it with your values" -ForegroundColor Green
}

Write-Host "`n✅ Installation complete!" -ForegroundColor Green
Write-Host "`n📚 Next steps:" -ForegroundColor Cyan
Write-Host "   1. Make sure Redis is running: redis-server" -ForegroundColor White
Write-Host "   2. Update .env with your database credentials" -ForegroundColor White
Write-Host "   3. Run development: python run_dev.py" -ForegroundColor White
Write-Host "   4. Run production: python run_production.py" -ForegroundColor White
Write-Host "`n📖 Read OPTIMIZATION_SUMMARY.md for details" -ForegroundColor Cyan
