import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'match_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  // 真實呼叫 Node.js API 的登入邏輯
  Future<void> _handleLogin() async {
    // 取得輸入的值並去除前後空白
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    // 1. 基本防呆
    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請輸入信箱與密碼！')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // 2. 發送 POST 請求到 Node.js 後端
      // 注意：因為我們目前編譯成 Chrome 網頁版，所以可以直接用 localhost
      final response = await http.post(
        Uri.parse('http://localhost:3000/api/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      // 解析後端回傳的 JSON
      final data = jsonDecode(response.body);

      if (!mounted) return; // Flutter 最佳實踐：確保畫面還在才更新 UI

      if (response.statusCode == 200 && data['success'] == true) {
        // 3. 登入成功！把 Token 存入 SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('accessToken', data['data']['accessToken']);
        await prefs.setString('userId', data['data']['user']['id']); // 順便存下使用者 ID

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('登入成功！Token 已安全儲存。'),
            backgroundColor: Colors.green,
          ),
        );

        // TODO: 這裡之後要寫跳轉到「配對首頁」的程式碼
if (mounted) {
  Navigator.pushReplacement(
    context,
    MaterialPageRoute(builder: (context) => const MatchScreen()),
  );
}
      } else {
        // 登入失敗（例如密碼錯誤）
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? '登入失敗，請檢查帳號密碼'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('網路錯誤，請確認 Node.js 伺服器已啟動：$e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo 或 App 名稱
              const Text(
                'VibeMatch',
                style: TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2.0,
                  color: Colors.deepPurpleAccent,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                '尋找與你同頻的靈魂',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 50),

              // 信箱輸入框
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  hintText: 'Email',
                  prefixIcon: const Icon(Icons.email_outlined),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // 密碼輸入框
              TextField(
                controller: _passwordController,
                obscureText: true, // 隱藏密碼字元
                decoration: InputDecoration(
                  hintText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 40),

              // 登入按鈕
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurpleAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _isLoading ? null : _handleLogin,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          '登入',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}