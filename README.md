# 🎮 GamePlus — Full Stack Game Platform

GamePlus là một nền tảng mini-game hoàn chỉnh gồm hai phần:
1. **GamePlus UI** — Ứng dụng Flutter (Flame Engine) cho các mini game như Snake, Caro, Sudoku,...  
2. **GamePlus API** — RESTful API backend xây dựng bằng FastAPI + PostgreSQL cho hệ thống điểm số (leaderboard) và xác thực người dùng.

---

# 🧩 1️⃣ GamePlus UI (Flutter + Flame Engine)

> 🚀 Ứng dụng Flutter dùng [Flame Engine](https://pub.dev/packages/flame), hỗ trợ nhiều trò chơi mini, giao diện gọn nhẹ và dễ mở rộng.

## 🧱 Cấu trúc dự án

```
lib/
├── main.dart                  # App entry point
├── app.dart                   # Routes, theme, global config
│
├── configs/                   # App-level configs và constants
│   ├── app_colors.dart
│   ├── app_text_styles.dart
│   ├── app_assets.dart
│   └── app_routes.dart
│
├── ui/                        # UI ngoài phần game
│   ├── screens/
│   │   ├── home_screen.dart
│   │   ├── settings_screen.dart
│   │   ├── leaderboard_screen.dart
│   │   └── about_screen.dart
│   ├── widgets/
│   │   ├── app_button.dart
│   │   ├── score_display.dart
│   │   └── gradient_background.dart
│   └── theme/
│       ├── app_theme.dart
│       └── app_fonts.dart
│
├── game/                      # Logic của các game (Flame hoặc CustomPainter)
│   ├── snake_game.dart
│   ├── components/
│   │   ├── snake.dart
│   │   ├── food.dart
│   │   └── wall.dart
│   ├── game_manager.dart
│   └── game_overlay.dart
│
├── services/                  # Audio, storage, leaderboard
│   ├── audio_service.dart
│   ├── prefs_service.dart
│   └── score_service.dart
│
└── utils/                     # Helpers và extensions
    ├── extensions.dart
    └── helpers.dart
```

---

## ⚙️ Tech Stack

- 🐦 **Flutter 3.22+**
- 🔥 **Flame Engine 1.14.0+**
- 🎵 `audioplayers` — hiệu ứng âm thanh
- 💾 `shared_preferences` — lưu dữ liệu cục bộ
- 🧩 `google_fonts` — font chữ hiện đại

---

## 🎨 Tính năng nổi bật

✅ Giao diện gọn gàng, modular  
✅ Sẵn game Snake (Flame demo)  
✅ Hỗ trợ overlay: Pause / Restart / Score  
✅ Responsive trên mọi thiết bị  
✅ Tách biệt logic game và UI  
✅ Hỗ trợ Light/Dark theme  
✅ Tích hợp âm thanh và lưu điểm offline

---

## 🚀 Cài đặt & chạy Flutter project

```bash
git clone https://github.com/yourname/gameplus_ui.git
cd gameplus_ui
flutter pub get
flutter run
```

---

## 🧠 Cách thêm game mới

1. Tạo file trong thư mục `/game/`, ví dụ `caro_game.dart`
2. Tạo lớp `FlameGame` của riêng bạn
3. Thêm route trong `app_routes.dart`
4. Cập nhật danh sách game trong `home_screen`
5. Chạy lại app — hoàn tất! 🎯

---

## 🧩 Planned Extensions

- 🌐 Online leaderboard (qua GamePlus API hoặc Firebase)
- 🪙 Achievement & XP system
- 🔥 Particle effect khi Game Over
- 📱 Gamepad / Controller Support

---

## 💚 Credits

Phát triển bởi **D8Team** với mục tiêu biến phát triển **Game bằng Flutter** trở nên dễ dàng và chuyên nghiệp.

---

# ⚙️ 2️⃣ GamePlus API (FastAPI + PostgreSQL)

> Backend RESTful API phục vụ cho hệ thống điểm số, xác thực người dùng và quản lý trò chơi.

---

## 🚀 Công nghệ chính

| Thành phần     | Mô tả                                   |
| -------------- | --------------------------------------- |
| **Framework**  | FastAPI                                 |
| **Server**     | Uvicorn                                 |
| **Database**   | PostgreSQL (asyncpg + SQLAlchemy Async) |
| **Auth**       | JWT (python-jose), bcrypt (passlib)     |
| **Validation** | Pydantic v2                             |

---

## 📂 Cấu trúc dự án

```
.
├─ app/
│  ├─ main.py                # Entrypoint, khởi tạo FastAPI app
│  ├─ api/                   # Routers: auth, users, games, scores
│  │   ├─ auth.py
│  │   ├─ auth_google.py
│  │   ├─ users.py
│  │   ├─ games.py
│  │   └─ scores.py
│  ├─ core/                  # Config, DB, bảo mật, middleware
│  ├─ models/                # SQLAlchemy models (User, Game, Score)
│  └─ schemas/               # Pydantic models cho request/response
├─ docker-compose.yml        # Postgres service
├─ requirements.txt
└─ README.md
```

---

## ⚙️ Cấu hình môi trường

Tạo file `.env` tại thư mục gốc:

```bash
DATABASE_URL=postgresql+asyncpg://admin:Admin123%40@localhost:5432/gameplus_db
SECRET_KEY=thay_the_bang_mot_chuoi_bao_mat
ACCESS_TOKEN_EXPIRE_MINUTES=60
```

> ⚠️ **Chú ý:** Nếu password chứa ký tự `@`, cần **URL-encode** (ví dụ `@` → `%40`).

---

## 🧩 Cài đặt & chạy ứng dụng

### 1️⃣ Cài môi trường ảo & dependencies

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
```

### 2️⃣ Chạy PostgreSQL bằng Docker

```powershell
docker compose up -d
```

### 3️⃣ Khởi chạy API

```powershell
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Docs:  
👉 [http://127.0.0.1:8000/docs](http://127.0.0.1:8000/docs)  
Health Check: [http://127.0.0.1:8000/api/test-db](http://127.0.0.1:8000/api/test-db)

---

## 🧠 Endpoint chính

| Method | Endpoint | Mô tả |
|--------|-----------|-------|
| POST | `/api/auth/register` | Đăng ký tài khoản |
| POST | `/api/auth/login` | Đăng nhập JWT |
| POST | `/api/auth/google-login` | Đăng nhập bằng Google |
| GET | `/api/auth/me` | Lấy thông tin người dùng hiện tại |
| GET | `/api/users/me` | Lấy profile |
| PUT | `/api/users/me` | Cập nhật profile |
| GET | `/api/games/` | Danh sách trò chơi |
| POST | `/api/scores/` | Gửi điểm |
| GET | `/api/scores/leaderboard/{game_id}` | Lấy leaderboard top 10 |
| GET | `/api/test-db` | Kiểm tra kết nối DB |

---

## 🧰 Troubleshooting

| Vấn đề | Giải pháp |
|--------|------------|
| ❌ Không kết nối DB | Kiểm tra `DATABASE_URL` và Docker Postgres |
| ⚠️ JWT 401 | Token hết hạn hoặc không hợp lệ |
| 🧾 Không tạo bảng | Kiểm tra `Base.metadata.create_all` trong `database.py` |
| ⚙️ Import lỗi | Kích hoạt `.venv` và cài lại dependencies |

---

## 🌐 Kiến trúc tổng thể (UI ↔ API)

```
[Flutter Game UI] → gửi điểm → [GamePlus API] → lưu vào PostgreSQL
         ↑                                           ↓
   Hiển thị leaderboard ← API trả dữ liệu JSON ← DB
```

- UI giao tiếp qua HTTP REST API (Bearer JWT)
- API lưu dữ liệu người chơi, game, điểm
- Dễ mở rộng cho hệ thống đăng nhập và leaderboard toàn cầu

---

## 🧩 Gợi ý mở rộng

- 🧩 Alembic migrations  
- 🐳 Dockerfile API container riêng  
- 🧪 Unit test cho các router  
- 🔒 CORS hạn chế cho production  
- 🔐 SECRET_KEY mạnh và lưu env

---

## 🏁 Tổng kết

**GamePlus** là nền tảng fullstack mẫu cho mini-games hiện đại, dễ deploy và dễ mở rộng.  
Dùng để học, nghiên cứu hoặc khởi đầu dự án thực tế.  
Kết hợp **Flutter + FastAPI + Docker + PostgreSQL** tạo nên hệ thống hoàn chỉnh.  

---

**Last updated:** 2025-10-19  
