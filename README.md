# 🎮 Game Flus

> 🚀 **Game Flus** for mini-games like Snake, Caro, Sudoku, and more. Built with ❤️ using [Flame Engine](https://pub.dev/packages/flame), it provides a clean, extensible foundation for both students and indie developers.

---

## 🧱 Project Structure

```
lib/
├── main.dart                  # App entry point
├── app.dart                   # Routes, theme, global config
│
├── configs/                   # App-level configs and constants
│   ├── app_colors.dart
│   ├── app_text_styles.dart
│   ├── app_assets.dart
│   └── app_routes.dart
│
├── ui/                        # UI outside the game
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
├── game/                      # Game logic (Flame or CustomPainter)
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
└── utils/                     # Reusable helpers/extensions
    ├── extensions.dart
    └── helpers.dart
```

---

## ⚙️ Tech Stack

- 🐦 **Flutter 3.22+**
- 🔥 **Flame Engine 1.14.0+**
- 🎵 `audioplayers` for sound effects
- 💾 `shared_preferences` for local save data
- 🧩 `google_fonts` for modern typography

---

## 🎨 Features

✅ Clean modular architecture  
✅ Ready-to-play Snake demo (Flame)  
✅ Game overlays (Pause / Restart / Score)  
✅ Responsive layout across all devices  
✅ Easy to switch between different games (Caro, Sudoku, etc.)  
✅ Light/Dark theme ready  
✅ Sound & storage service abstraction

---

## 🚀 Getting Started

```bash
git clone https://github.com/yourname/flutter_game_template.git
cd flutter_game_template
flutter pub get
flutter run
```

---

## 🕹️ Example: Snake Game

```dart
class SnakeGame extends FlameGame with HasCollisionDetection {
  late Snake snake;
  late Food food;

  @override
  Future<void> onLoad() async {
    snake = Snake();
    food = Food();
    addAll([snake, food]);
  }
}
```

---

## 🧠 Folder Philosophy

| Folder     | Purpose                                   |
| ---------- | ----------------------------------------- |
| `configs`  | Theme, assets, colors, routes             |
| `ui`       | All non-game UI (menu, leaderboard, etc.) |
| `game`     | Core game logic, visuals, and components  |
| `services` | Sound, storage, and high-score management |
| `utils`    | Extensions & helper functions             |

---

## 🏗️ How to Add a New Game

1. Create a new folder in `/game/` → e.g., `caro_game.dart`
2. Implement your `FlameGame` class
3. Add its route in `app_routes.dart`
4. Add to `home_screen` list of games
5. Done! 🎯

---

## 🧩 Planned Extensions

- 🔥 Particle effects for game over
- 🌐 Online leaderboard (Firebase)
- 🪙 Achievement & XP system
- 📱 Responsive gamepad support

---

## 💚 Credits

Built by **D8Team** with the goal of making **Flutter Game Development** accessible and elegant.

> ⭐ If you like this template, give it a star and share it with your friends!

---

## 🖼️ Preview

🎮 Home Menu → 🐍 Snake Gameplay → 🏆 Leaderboard → ⚙️ Settings

---

## 📜 License

MIT License © 2025 D8Team
