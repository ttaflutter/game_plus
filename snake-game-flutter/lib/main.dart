import 'package:flutter/material.dart';
import 'snake_play_screen.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    // Chỉ return màn chơi
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: SnakePlayScreen(),
    );
  }
}
