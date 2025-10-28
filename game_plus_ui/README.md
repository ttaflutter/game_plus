# 🎮 Game Plus

<div align="center">

![Flutter](https://img.shields.io/badge/Flutter-3.9.2+-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-3.9.2+-0175C2?style=for-the-badge&logo=dart&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)
![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20Web-blue?style=for-the-badge)

**Game Plus** - Nền tảng mini-game đa người chơi trực tuyến với hệ thống phòng chơi, xếp hạng, và trò chuyện thời gian thực. Được xây dựng bởi **D8Team** với ❤️ sử dụng Flutter.

[Tính năng](#-tính-năng) • [Cài đặt](#-cài-đặt) • [Cấu hình](#-cấu-hình) • [Build & Deploy](#-build--deploy) • [Kiến trúc](#-kiến-trúc-dự-án)

</div>

---

## 📋 Mục lục

- [Tổng quan](#-tổng-quan)
- [Tính năng](#-tính-năng)
- [Công nghệ sử dụng](#-công-nghệ-sử-dụng)
- [Yêu cầu hệ thống](#-yêu-cầu-hệ-thống)
- [Cài đặt](#-cài-đặt)
- [Cấu hình](#-cấu-hình)
- [Build & Deploy](#-build--deploy)
- [Kiến trúc dự án](#-kiến-trúc-dự-án)
- [API & WebSocket](#-api--websocket)
- [Troubleshooting](#-troubleshooting)
- [Đóng góp](#-đóng-góp)
- [License](#-license)

---

## 🌟 Tổng quan

**Game Plus** là một ứng dụng mobile game đa người chơi trực tuyến được xây dựng với Flutter, cung cấp trải nghiệm chơi game mượt mà với các tính năng hiện đại:

- 🎯 **Caro (Tic-Tac-Toe)**: Trò chơi caro cổ điển với chế độ online multiplayer
- 🏆 **Hệ thống xếp hạng**: Bảng xếp hạng toàn cầu và theo từng game
- 👥 **Phòng chơi**: Tạo và tham gia phòng chơi với bạn bè
- 💬 **Chat thời gian thực**: Trò chuyện với đối thủ trong khi chơi
- 🔐 **Xác thực Google**: Đăng nhập nhanh chóng với tài khoản Google
- ⏱️ **Timer & Rating**: Hệ thống thời gian và điểm rating ELO
- 🎨 **UI/UX chuyên nghiệp**: Animations mượt mà, responsive design

---

## ✨ Tính năng

### 🎮 Game Features

- ✅ Caro game với animation đẹp mắt (flip, glow, scale effects)
- ✅ Hệ thống timer đếm ngược cho mỗi lượt
- ✅ Highlight đường thắng với hiệu ứng glow
- ✅ Rematch nhanh chóng sau khi kết thúc
- ✅ Chat trong game với số tin nhắn chưa đọc
- ✅ Surrender và disconnect handling

### 👤 User Features

- ✅ Đăng nhập Google OAuth 2.0
- ✅ Profile cá nhân với avatar, rating, thống kê
- ✅ Quản lý bạn bè (add, accept, decline)
- ✅ Lịch sử trận đấu chi tiết
- ✅ Bảng xếp hạng global

### 🔧 Technical Features

- ✅ WebSocket real-time communication
- ✅ State management với Provider
- ✅ Responsive UI cho mọi kích thước màn hình
- ✅ Sound effects và haptic feedback
- ✅ Environment configuration (.env)
- ✅ Error handling và retry logic

---

## 🛠️ Công nghệ sử dụng

### Core

- **Flutter SDK**: 3.9.2+
- **Dart**: 3.9.2+

### Key Dependencies

```yaml
dependencies:
  # State Management & Architecture
  provider: ^6.0.5 # State management

  # Networking & API
  http: ^1.1.2 # REST API calls
  dio: ^5.9.0 # Advanced HTTP client
  web_socket_channel: ^3.0.3 # WebSocket real-time

  # Authentication
  google_sign_in: ^6.2.1 # Google OAuth

  # Storage & Config
  shared_preferences: ^2.1.1 # Local storage
  flutter_dotenv: ^5.0.2 # Environment variables

  # UI & Animation
  flutter_animate: ^4.5.0 # Animations
  page_transition: ^2.1.0 # Page transitions
  dynamic_color: ^1.7.0 # Material You colors
  flutter_svg: ^2.0.10+1 # SVG support
  flutter_screenutil: ^5.9.0 # Responsive design

  # Audio & Haptics
  audioplayers: ^5.2.1 # Sound effects
  vibration: ^2.0.5 # Haptic feedback

  # Utilities
  intl: ^0.19.0 # Internationalization
  cupertino_icons: ^1.0.8 # iOS-style icons
```

---

## 📱 Yêu cầu hệ thống

### Development Environment

- **Flutter SDK**: >= 3.9.2
- **Dart SDK**: >= 3.9.2
- **Android Studio** / **VS Code** với Flutter extension
- **Git** để version control

### Android Requirements

- **Android SDK**: API Level 21+ (Android 5.0+)
- **Target SDK**: API Level 34 (Android 14)
- **JDK**: 11 hoặc mới hơn
- **Gradle**: 8.0+

### iOS Requirements (Optional)

- **Xcode**: 14.0+
- **iOS**: 12.0+
- **CocoaPods**: Latest version

### Hardware

- **RAM**: Tối thiểu 8GB (khuyến nghị 16GB)
- **Storage**: 10GB trống
- **Internet**: Kết nối ổn định (để test WebSocket)

---

## 🚀 Cài đặt

### 1. Clone Repository

```bash
git clone https://github.com/D8Team/game_plus.git
cd game_plus/game_plus_ui
```

### 2. Kiểm tra Flutter Environment

```bash
flutter doctor -v
```

Đảm bảo tất cả dependencies được cài đặt đúng. Nếu có lỗi, làm theo hướng dẫn từ `flutter doctor`.

### 3. Install Dependencies

```bash
flutter pub get
```

### 4. Clean Build (nếu cần)

```bash
flutter clean
flutter pub get
```

---

## ⚙️ Cấu hình

### 1. Environment Variables

Tạo file `.env` trong thư mục root của project:

```bash
# .env
API_BASE_URL=https://your-api-domain.com
WS_BASE_URL=wss://your-websocket-domain.com
```

**Lưu ý**: Đảm bảo file `.env` nằm trong `.gitignore` để bảo mật.

### 2. Google Sign-In Configuration

#### 2.1. Google Cloud Console Setup

1. Truy cập [Google Cloud Console](https://console.cloud.google.com/)
2. Tạo project mới hoặc chọn project hiện có
3. Enable **Google Sign-In API**
4. Tạo **OAuth 2.0 Client IDs**:
   - **Android**: Cần package name và SHA-1 certificate
   - **Web** (nếu build web): Cần origin URLs
   - **iOS** (nếu build iOS): Cần bundle ID

#### 2.2. Lấy SHA-1 Certificate Fingerprint

**Cho Debug Build:**

```powershell
# Windows PowerShell
keytool -list -v -keystore "$env:USERPROFILE\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android
```

**Cho Release Build:**

```powershell
# Thay đổi path và alias phù hợp với keystore của bạn
keytool -list -v -keystore "android/app/my-release-key.jks" -alias my-key-alias
```

Copy SHA-1 fingerprint từ output.

#### 2.3. Thêm SHA-1 vào Firebase/Google Cloud

**Option A: Firebase (Khuyến nghị)**

1. Truy cập [Firebase Console](https://console.firebase.google.com/)
2. Chọn project → Project Settings
3. Chọn Android app
4. Scroll xuống "Add fingerprint"
5. Paste SHA-1 và save
6. Download `google-services.json` mới

**Option B: Google Cloud Console**

1. APIs & Services → Credentials
2. Chọn OAuth 2.0 Client ID (Android)
3. Thêm package name: `com.example.game_plus`
4. Thêm SHA-1 certificate fingerprint
5. Save

#### 2.4. Cấu hình Android Project

**Đặt file `google-services.json`:**

```
android/app/google-services.json
```

**Kiểm tra `android/build.gradle.kts`:**

```kotlin
buildscript {
    dependencies {
        classpath("com.google.gms:google-services:4.3.15")
    }
}
```

**Kiểm tra `android/app/build.gradle.kts`:**

```kotlin
plugins {
    // ... other plugins
    id("com.google.gms.google-services")
}

android {
    defaultConfig {
        applicationId = "com.example.game_plus"
        // ...
    }
}
```

#### 2.5. Cập nhật Web Client ID (nếu build web)

Trong file `lib/services/google_auth_service.dart`:

```dart
final GoogleSignIn _googleSignIn = GoogleSignIn(
  scopes: ['email', 'profile'],
  clientId: kIsWeb
      ? 'YOUR_WEB_CLIENT_ID.apps.googleusercontent.com' // THAY ĐỔI NÀY!
      : null,
);
```

### 3. Keystore Configuration (cho Release Build)

#### 3.1. Tạo Keystore (nếu chưa có)

```bash
keytool -genkey -v -keystore android/app/my-release-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias my-key-alias
```

Lưu lại thông tin:

- **Keystore password**
- **Key password**
- **Alias name**

#### 3.2. Tạo file `key.properties`

Tạo file `android/key.properties`:

```properties
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=my-key-alias
storeFile=app/my-release-key.jks
```

**Lưu ý**: File `key.properties` phải nằm trong `.gitignore`!

#### 3.3. Verify Build Configuration

File `android/app/build.gradle.kts` đã được cấu hình:

```kotlin
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = keystoreProperties["storeFile"]?.let { file(it as String) }
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }

    buildTypes {
        getByName("release") {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}
```

---

## 🏗️ Build & Deploy

### Development Build (Debug)

```bash
# Run on connected device/emulator
flutter run

# Run with specific device
flutter devices
flutter run -d <device-id>

# Hot reload: Press 'r' in terminal
# Hot restart: Press 'R' in terminal
```

### Release Build

#### Android APK

```bash
# Clean previous builds
flutter clean

# Build release APK
flutter build apk --release

# Output: build/app/outputs/flutter-apk/app-release.apk
```

#### Android App Bundle (AAB) - For Google Play

```bash
flutter build appbundle --release

# Output: build/app/outputs/bundle/release/app-release.aab
```

#### Install Release APK on Device

```bash
# Install via ADB
adb install -r build/app/outputs/flutter-apk/app-release.apk

# Or drag & drop APK to device
```

### iOS Build (macOS only)

```bash
# Open Xcode to configure signing
open ios/Runner.xcworkspace

# Build release
flutter build ios --release

# Or build IPA for TestFlight/App Store
flutter build ipa --release
```

### Web Build

```bash
flutter build web --release

# Output: build/web/
# Deploy to Firebase Hosting, Netlify, Vercel, etc.
```

---

## 🏛️ Kiến trúc dự án

```
lib/
├── main.dart                           # Entry point
│
├── configs/                            # App configurations
│   ├── app_colors.dart
│   ├── app_text_styles.dart
│   ├── app_assets.dart
│   └── app_routes.dart
│
├── core/                               # Core utilities & base classes
│   └── [base classes, extensions, utils]
│
├── models/                             # Data models (User, Match, Room, etc.)
│   ├── user.dart
│   ├── room.dart
│   └── match.dart
│
├── schemas/                            # API request/response schemas
│   ├── auth_schemas.dart
│   └── game_schemas.dart
│
├── services/                           # Business logic & API services
│   ├── auth_service.dart              # Authentication (email/password)
│   ├── google_auth_service.dart       # Google OAuth
│   ├── caro_service.dart              # Caro game WebSocket
│   ├── room_service.dart              # Room management
│   ├── room_websocket_manager.dart    # Room real-time updates
│   ├── friend_service.dart            # Friend system
│   ├── profile_service.dart           # User profile
│   ├── leaderboard_service.dart       # Leaderboard
│   └── match_history_service.dart     # Match history
│
├── game/                               # Game implementations
│   └── caro/
│       ├── caro_controller.dart       # Game state management
│       ├── caro_board.dart            # Board widget
│       ├── caro_cell.dart             # Cell widget with animations
│       └── [other caro components]
│
└── ui/                                 # UI layer
    ├── screens/                        # App screens
    │   ├── home_screen.dart
    │   ├── login_screen.dart
    │   ├── profile_screen.dart
    │   ├── leaderboard_screen.dart
    │   ├── room_screen.dart
    │   └── game_screen.dart
    │
    └── widgets/                        # Reusable widgets
        ├── app_button.dart
        ├── gradient_background.dart
        └── [other shared widgets]
```

### Architecture Patterns

- **State Management**: Provider pattern

  - CaroController, RoomController, AuthController, etc.
  - Notify listeners pattern for reactive UI

- **Service Layer**: Separation of concerns

  - Services handle API/WebSocket communication
  - Controllers manage game/UI state
  - Screens/Widgets only render UI

- **WebSocket Communication**:
  - Real-time game state updates
  - Chat messages
  - Room events (join, leave, ready)
  - Automatic reconnection handling

---

## 🌐 API & WebSocket

### REST API Endpoints

Base URL: `https://your-api-domain.com`

#### Authentication

- `POST /auth/register` - Đăng ký tài khoản
- `POST /auth/login` - Đăng nhập email/password
- `POST /auth/google` - Đăng nhập Google OAuth
- `POST /auth/logout` - Đăng xuất
- `POST /auth/refresh` - Refresh token

#### User & Profile

- `GET /users/profile` - Lấy thông tin profile
- `PUT /users/profile` - Cập nhật profile
- `POST /users/avatar` - Upload avatar

#### Friends

- `GET /friends` - Danh sách bạn bè
- `POST /friends/request` - Gửi lời mời kết bạn
- `POST /friends/accept/:id` - Chấp nhận lời mời
- `DELETE /friends/:id` - Xóa bạn bè

#### Rooms

- `GET /rooms` - Danh sách phòng chơi
- `POST /rooms` - Tạo phòng mới
- `POST /rooms/:id/join` - Tham gia phòng
- `DELETE /rooms/:id` - Xóa phòng

#### Leaderboard

- `GET /leaderboard/global` - Bảng xếp hạng toàn cầu
- `GET /leaderboard/game/:gameType` - Xếp hạng theo game

#### Match History

- `GET /matches/history` - Lịch sử trận đấu
- `GET /matches/:id` - Chi tiết trận đấu

### WebSocket Events

#### Caro Game (`wss://your-ws-domain.com/caro/:matchId`)

**Client → Server:**

```json
{ "type": "move", "x": 3, "y": 5 }
{ "type": "chat", "message": "Good game!" }
{ "type": "surrender" }
{ "type": "rematch" }
{ "type": "ping" }
```

**Server → Client:**

```json
{ "type": "joined", "symbol": "X", "opponent": {...} }
{ "type": "start", "currentTurn": "X", "timeLeft": 30 }
{ "type": "move", "x": 3, "y": 5, "symbol": "O" }
{ "type": "win", "winnerId": "123", "winningLine": [...] }
{ "type": "draw" }
{ "type": "timeout", "userId": "123" }
{ "type": "chat", "message": "...", "senderId": "123" }
{ "type": "rematch_request", "userId": "123" }
{ "type": "rematch_accepted", "newMatchId": "456" }
{ "type": "player_left", "userId": "123" }
```

#### Room WebSocket (`wss://your-ws-domain.com/rooms/:roomId`)

**Events:**

- `player_joined` - Người chơi tham gia
- `player_left` - Người chơi rời phòng
- `player_ready` - Người chơi sẵn sàng
- `game_starting` - Game bắt đầu
- `room_updated` - Cập nhật thông tin phòng

---

## 🐛 Troubleshooting

### Google Sign-In Issues

#### Lỗi: `sign_in_failed` / `ApiException: 10`

**Nguyên nhân**: SHA-1 certificate không khớp hoặc chưa được thêm vào Google Cloud/Firebase.

**Giải pháp**:

1. Lấy SHA-1 đúng cho build type (debug/release)
2. Thêm SHA-1 vào Firebase/Google Cloud
3. Download `google-services.json` mới
4. Đặt vào `android/app/google-services.json`
5. Rebuild: `flutter clean && flutter build apk --release`

#### Lỗi: `PlatformException: sign_in_canceled`

**Nguyên nhân**: User hủy đăng nhập hoặc không có Google Services.

**Giải pháp**:

- Đảm bảo Google Play Services được cài trên device
- Kiểm tra network connection
- Thử đăng nhập lại

### Build Issues

#### Lỗi: `Gradle build failed`

```bash
# Clean cache
flutter clean
cd android
./gradlew clean
cd ..
flutter pub get
flutter build apk
```

#### Lỗi: `Execution failed for task ':app:processReleaseGoogleServices'`

**Giải pháp**: Kiểm tra `google-services.json` có đúng package name và tồn tại trong `android/app/`.

### WebSocket Issues

#### Lỗi: `WebSocket connection failed`

**Kiểm tra**:

- Backend server có đang chạy không?
- URL trong `.env` có đúng không? (wss:// cho production, ws:// cho local)
- Firewall/Network có block WebSocket không?

#### Lỗi: `Token expired` / `401 Unauthorized`

**Giải pháp**:

- Implement token refresh logic
- Lưu refresh token trong SharedPreferences
- Auto-refresh khi token hết hạn

### Performance Issues

#### App lag khi animation

**Giải pháp**:

- Enable release mode: `flutter run --release`
- Profile app: `flutter run --profile`
- Giảm số lượng AnimationController đồng thời
- Sử dụng `RepaintBoundary` cho complex widgets

---

## 🤝 Đóng góp

Chúng tôi hoan nghênh mọi đóng góp! Để contribute:

1. Fork repository
2. Tạo feature branch: `git checkout -b feature/AmazingFeature`
3. Commit changes: `git commit -m 'Add some AmazingFeature'`
4. Push to branch: `git push origin feature/AmazingFeature`
5. Open Pull Request

### Coding Standards

- Tuân thủ [Dart Style Guide](https://dart.dev/guides/language/effective-dart)
- Sử dụng `flutter analyze` để check code
- Viết comments cho logic phức tạp
- Tên biến/function phải rõ ràng, dễ hiểu

---

## 👥 Team

**D8Team** - HUTECH University

- **Trần Tuấn Anh** - Lead Developer
- [Thêm thành viên team khác]

---

## 📄 License

```
MIT License

Copyright (c) 2025 D8Team

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

---

## 🙏 Acknowledgments

- [Flutter Team](https://flutter.dev/) - Amazing framework
- [Provider Package](https://pub.dev/packages/provider) - State management
- [Google Sign-In](https://pub.dev/packages/google_sign_in) - OAuth integration
- [WebSocket Channel](https://pub.dev/packages/web_socket_channel) - Real-time communication
- [Community Contributors](https://github.com/D8Team/game_plus/graphs/contributors)

---

## 📞 Liên hệ & Hỗ trợ

- **Email**: support@d8team.com
- **GitHub Issues**: [Report a bug](https://github.com/D8Team/game_plus/issues)
- **Documentation**: [Wiki](https://github.com/D8Team/game_plus/wiki)

---

<div align="center">

**⭐ Nếu bạn thấy project hữu ích, hãy cho chúng tôi một star! ⭐**

Made with ❤️ by D8Team | © 2025

</div>
