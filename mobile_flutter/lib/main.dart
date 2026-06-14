import 'package:flutter/material.dart';
import 'screens/login_screen.dart';

void main() {
  runApp(const VibeMatchApp());
}

class VibeMatchApp extends StatelessWidget {
  const VibeMatchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VibeMatch',
      debugShowCheckedModeBanner: false, // 隱藏右上角的 Debug 標籤
      // 設定高質感的暗黑科技風主題
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121212),
        primaryColor: Colors.deepPurpleAccent,
        colorScheme: const ColorScheme.dark(
          primary: Colors.deepPurpleAccent,
          secondary: Colors.cyanAccent,
        ),
        useMaterial3: true,
      ),
      home: const LoginScreen(),
    );
  }
}