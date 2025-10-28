# 🎮 GamePlus — Full Stack Multiplayer Game Platform

<div align="center">

![Flutter](https://img.shields.io/badge/Flutter-3.9.2+-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![FastAPI](https://img.shields.io/badge/FastAPI-0.115.0+-009688?style=for-the-badge&logo=fastapi&logoColor=white)
![Redis](https://img.shields.io/badge/Redis-7.0+-DC382D?style=for-the-badge&logo=redis&logoColor=white)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-15+-336791?style=for-the-badge&logo=postgresql&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)
![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20Web%20%7C%20API-blue?style=for-the-badge)

**GamePlus** — Nền tảng mini-game đa người chơi trực tuyến với hệ thống phòng chơi, xếp hạng, bạn bè và trò chuyện thời gian thực.  
Phát triển bởi **D8Team (HUTECH University)** với ❤️ bằng **Flutter + FastAPI**.

</div>

---

## 📘 Tổng quan dự án

GamePlus bao gồm hai thành phần chính:

| Thành phần | Mô tả | Công nghệ chính |
|-------------|--------|----------------|
| 🎨 **game_plus_ui** | Ứng dụng Flutter client cho Android, iOS và Web | Flutter 3.9.2+, Dart |
| ⚙️ **game_plus_api** | Backend server hỗ trợ WebSocket real-time và REST API | FastAPI, PostgreSQL, Redis |

> Mục tiêu: cung cấp trải nghiệm chơi **Caro Online** mượt mà, có xếp hạng, bạn bè và hệ thống matchmaking tự động.

---

## ✨ Tính năng nổi bật

### 🔹 Frontend (Flutter UI)
- 🎮 **Game Offline**
- 🧩 **Game Caro Online** — Chơi real-time qua WebSocket
- 🧑‍🤝‍🧑 **Phòng chơi & Chat trực tiếp**
- 🥇 **Bảng xếp hạng toàn cầu**
- 🔐 **Đăng nhập Google OAuth 2.0**
- 🧠 **Hệ thống rating ELO & thống kê người chơi**
- 🎨 **UI/UX hiện đại**: animation mượt mà, responsive, haptic feedback

### 🔹 Backend (FastAPI API)
- ⚡ **WebSocket real-time server** (Caro, Matchmaking, Notifications)
- 🔑 **Authentication**: JWT + Google OAuth
- 🧠 **Matchmaking tự động** theo rating
- 🧩 **Friend system & challenge rooms**
- 📜 **Replay trận đấu và thống kê chi tiết**
- 🧰 **Caching bằng Redis** giảm 70% truy vấn DB
- 🚀 **Multi-worker + uvloop + httptools** tăng throughput 3x

---

## 🏗️ Kiến trúc hệ thống

```
┌──────────────────────────┐
│      Flutter Client      │
│  (game_plus_ui)          │
└──────────┬───────────────┘
           │ HTTP / WebSocket
           ↓
┌──────────────────────────┐
│      FastAPI Server      │
│  (game_plus_api)         │
│ ┌──────────┐ ┌──────────┐│
│ │ REST API │ │ WebSocket││
│ └──────────┘ └──────────┘│
└──────────┬───────────────┘
           │
   ┌───────┴────────┐
   │ PostgreSQL 15+ │
   │ Redis 7+ Cache │
   └────────────────┘
```

---

## 🧰 Công nghệ chính

| Layer | Stack | Ghi chú |
|-------|--------|---------|
| **Frontend** | Flutter, Dart, Provider, WebSocket Channel | Responsive UI, Google Sign-In |
| **Backend** | FastAPI, SQLAlchemy, uvicorn, asyncio | Async API + Realtime |
| **Database** | PostgreSQL 15 | ORM với SQLAlchemy 2.0 |
| **Cache & Queue** | Redis 7 + hiredis | Pub/Sub, rate limiting |
| **Auth** | JWT + Google OAuth | Secure login flow |
| **Deployment** | Docker, Nginx, Systemd | Production-ready setup |

---

## ⚙️ Cài đặt nhanh

### 🧱 Clone dự án

```bash
git clone https://github.com/D8Team/game_plus.git
cd game_plus
```

### 📦 Cấu trúc thư mục

```
game_plus/
├── game_plus_ui/     # Flutter app (client)
├── game_plus_api/    # FastAPI backend (server)
└── README.md         # Tài liệu tổng hợp
```

---

## 🚀 Hướng dẫn khởi chạy

### 1️⃣ Backend (FastAPI)
```bash
cd game_plus_api
cp .env.example .env
docker-compose up -d  # Khởi động PostgreSQL + Redis
python run_dev.py     # Chạy server phát triển
```
> API Docs: http://localhost:8000/api/docs  
> WebSocket: ws://localhost:8000/ws

### 2️⃣ Frontend (Flutter)
```bash
cd game_plus_ui
flutter pub get
flutter run
```
> Cập nhật `.env`:
```bash
API_BASE_URL=http://localhost:8000/api
WS_BASE_URL=ws://localhost:8000/ws
```

---


## 🧪 Testing & Monitoring

- ✅ `pytest` — Unit test toàn bộ API
- 🧠 `test_load.py` — Load test 100 người chơi cùng lúc
- 🧩 `test_redis_connection.py` — Kiểm tra cache hoạt động
- 📊 Monitoring qua **Nginx logs**, **Redis monitor**, **pg_stat_activity**

---

## 📦 Triển khai Production

- **Backend**: Docker + Systemd service + Nginx reverse proxy
- **SSL**: Certbot + Let's Encrypt (`sudo certbot --nginx -d api.gameplus.com`)
- **Frontend**: Build Flutter Web (`flutter build web --release`) → deploy Netlify/Vercel/Firebase

---

## 👥 Đội ngũ phát triển

**D8Team — HUTECH University**  
- 🧑‍💻 **Trần Tuấn Anh**
- 🧑‍💻 **Trần Tấn Đạt**
- 🎨 **Nguyễn Hữu Ngự Bình**
- 🎨 **Trần Văn Bắc**
- ⚙️ **Lê Văn Kiệt**

---

## 📜 License

MIT License © 2025 D8Team  
Xem chi tiết trong từng module `game_plus_ui` và `game_plus_api`.

---

## 🌟 Ghi nhận

- Flutter & FastAPI community  
- PostgreSQL + Redis ecosystem  
- OpenAI & AI-powered optimization tools  
- HUTECH Innovation Projects 2025

---

<div align="center">

**⭐ Nếu bạn thích dự án, hãy cho chúng tôi một Star trên GitHub! ⭐**  
**Made with ❤️ by D8Team — 2025**

</div>
