# 🎮 GamePlus API

**Version:** 1.0.0  
**Author:** Trần Tuấn Anh

Một RESTful API backend tối giản cho hệ thống **điểm số trò chơi (leaderboard)**, được xây dựng bằng **FastAPI** và **PostgreSQL**.  
Hệ thống hỗ trợ **đăng ký/đăng nhập (JWT + Google OAuth)**, **quản lý người dùng**, **trò chơi**, và **gửi điểm số**.

---

## 🚀 Công nghệ chính

| Thành phần     | Mô tả                                   |
| -------------- | --------------------------------------- |
| **Framework**  | FastAPI                                 |
| **Server**     | Uvicorn                                 |
| **Database**   | PostgreSQL (asyncpg + SQLAlchemy Async) |
| **Auth**       | JWT (python-jose), bcrypt (passlib)     |
| **Validation** | Pydantic v2                             |

Cấu trúc ứng dụng tuân theo mô hình `app/` rõ ràng, dễ mở rộng.

---

## 📂 Cấu trúc dự án

```
.
├─ app/
│  ├─ main.py                # Entrypoint, khởi tạo FastAPI app
│  ├─ api/                   # Routers: auth, users, games, scores
│  │   ├─ auth.py            # Đăng ký / đăng nhập local (JWT)
│  │   ├─ auth_google.py     # Đăng nhập Google OAuth
│  │   ├─ users.py           # Thông tin & cập nhật người dùng
│  │   ├─ games.py           # Danh sách trò chơi
│  │   └─ scores.py          # Gửi điểm và lấy leaderboard
│  ├─ core/                  # Config, DB, bảo mật, middleware
│  │   ├─ config.py
│  │   ├─ database.py
│  │   ├─ security.py
│  │   └─ middleware.py
│  ├─ models/                # SQLAlchemy models (User, Game, Score)
│  └─ schemas/               # Pydantic models cho request/response
├─ docker-compose.yml        # Dịch vụ Postgres
├─ requirements.txt
└─ README.md
```

---

## ⚙️ Thiết lập môi trường

### 1️⃣ Yêu cầu hệ thống

- Python **3.11+**
- **Docker** & **Docker Compose**
- **Windows PowerShell** (khuyến nghị khi phát triển trên Windows)

### 2️⃣ Tạo file `.env` ở thư mục gốc

```bash
DATABASE_URL=postgresql+asyncpg://admin:Admin123%40@localhost:5432/gameplus_db
SECRET_KEY=thay_the_bang_mot_chuoi_bao_mat
ACCESS_TOKEN_EXPIRE_MINUTES=60
```

> ⚠️ Ghi chú:
>
> - Nếu password chứa ký tự `@`, cần **URL-encode** (ví dụ `@` → `%40`).
> - `DATABASE_URL` là bắt buộc. Nếu không có, ứng dụng sẽ không khởi động.

---

## 🧩 Cài đặt & chạy ứng dụng (Local)

### Bước 1: Tạo môi trường ảo và cài đặt dependencies

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
```

### Bước 2: Chạy PostgreSQL bằng Docker

```powershell
docker compose up -d
```

Kiểm tra container hoạt động:

```powershell
docker compose ps
```

### Bước 3: Khởi chạy ứng dụng

```powershell
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Ứng dụng sẽ chạy tại:  
👉 http://127.0.0.1:8000

- Docs API: [http://127.0.0.1:8000/docs](http://127.0.0.1:8000/docs)
- Test DB: [http://127.0.0.1:8000/api/test-db](http://127.0.0.1:8000/api/test-db)

---

## 🐳 Sử dụng Docker cho toàn bộ stack

Nếu muốn container hóa hoàn toàn, chỉ cần:

```powershell
docker compose up -d
```

Các lệnh hữu ích:

```powershell
# Dừng container
docker compose down

# Dừng và xóa cả volume dữ liệu (mất dữ liệu)
docker compose down -v

# Xem logs Postgres
docker compose logs -f db

# Truy cập psql
docker exec -it gameplus_db psql -U admin -d gameplus_db
```

---

## 🧠 Các endpoint chính

| Phương thức | Endpoint                            | Mô tả                              |
| ----------- | ----------------------------------- | ---------------------------------- |
| `POST`      | `/api/auth/register`                | Đăng ký tài khoản (local / google) |
| `POST`      | `/api/auth/login`                   | Đăng nhập local (JWT)              |
| `POST`      | `/api/auth/google-login`            | Đăng nhập bằng Google              |
| `GET`       | `/api/auth/me`                      | Lấy thông tin user hiện tại        |
| `GET`       | `/api/users/me`                     | Lấy profile                        |
| `PUT`       | `/api/users/me`                     | Cập nhật profile                   |
| `GET`       | `/api/games/`                       | Danh sách trò chơi                 |
| `POST`      | `/api/scores/`                      | Gửi điểm                           |
| `GET`       | `/api/scores/leaderboard/{game_id}` | Top 10 leaderboard                 |
| `GET`       | `/api/test-db`                      | Kiểm tra kết nối DB                |

> ⚠️ Các endpoint có `Bearer Token` yêu cầu header:  
> `Authorization: Bearer <token>`

---

## 🧰 Debug & Troubleshooting

| Vấn đề              | Giải pháp                                                                    |
| ------------------- | ---------------------------------------------------------------------------- |
| ❌ Không kết nối DB | Kiểm tra `DATABASE_URL`, Docker Postgres có đang chạy, port 5432 có bị chiếm |
| ⚠️ JWT 401          | Kiểm tra token hợp lệ và còn hạn                                             |
| ⚙️ Import lỗi       | Kích hoạt `.venv` và `pip install -r requirements.txt`                       |
| 🧾 Xem SQL query    | Mở `echo=True` trong `database.py`                                           |

---

## 🚀 Gợi ý mở rộng

- 🧩 Thêm **Alembic** để quản lý migration
- 🐳 Thêm **Dockerfile API** và chạy cùng Postgres
- 🧪 Viết **unit test** và **integration test**
- 🔒 Giới hạn CORS cho production
- 🔐 Tạo `SECRET_KEY` mạnh và lưu qua biến môi trường

---

## 🏁 Tổng kết

`GamePlus API` là nền tảng backend mẫu gọn nhẹ, dễ mở rộng cho hệ thống **leaderboard game**.  
Chạy được nhanh chóng chỉ với **Python + Docker + FastAPI**.

---

**Last updated:** 2025-10-19
