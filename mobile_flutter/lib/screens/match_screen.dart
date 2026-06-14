import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class MatchScreen extends StatefulWidget {
  const MatchScreen({super.key});

  @override
  State<MatchScreen> createState() => _MatchScreenState();
}

// 加上 SingleTickerProviderStateMixin 來支援雷達動畫
class _MatchScreenState extends State<MatchScreen> with SingleTickerProviderStateMixin {
  WebSocketChannel? _channel;
  String _statusMessage = "連線中...";
  bool _isMatching = false;
  bool _isMatched = false;
  String _roomId = "";
  String _myUserId = "";
  
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _scrollController = ScrollController(); // 控制聊天室捲動
  final List<Map<String, String>> _messages = [];

  // 雷達動畫控制器
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    
    // 初始化雷達脈衝動畫 (設定 1.5 秒放大並重複)
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.5).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOut),
    );

    _connectWebSocket();
  }

  Future<void> _connectWebSocket() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');
    _myUserId = prefs.getString('userId') ?? "";

    if (token == null) {
      setState(() => _statusMessage = "找不到授權憑證，請重新登入");
      return;
    }

    try {
      final wsUrl = Uri.parse('ws://localhost:8080/ws?token=$token');
      _channel = WebSocketChannel.connect(wsUrl);

      setState(() => _statusMessage = "✅ 系統待命完成，請啟動雷達");

      _channel!.stream.listen(
        (message) {
          final data = jsonDecode(message);
          
          if (data['action'] == 'matched') {
            setState(() {
              _isMatching = false;
              _isMatched = true;
              _pulseController.stop(); // 停止雷達動畫
              _roomId = data['roomId'];
              _statusMessage = "🎉 配對成功！房間通道已建立";
            });
          } else if (data['action'] == 'chat') {
            setState(() {
              final isMe = data['senderId'] == _myUserId;
              _messages.add({
                "sender": isMe ? "我" : "對方",
                "text": data['message'],
              });
            });
            _scrollToBottom(); // 收到新訊息時自動捲動到底部
          }
        },
        onDone: () {
          setState(() => _statusMessage = "❌ 伺服器連線已斷開");
        },
        onError: (error) {
          setState(() => _statusMessage = "⚠️ 連線發生異常");
        },
      );
    } catch (e) {
      setState(() => _statusMessage = "連線失敗: $e");
    }
  }

  void _findMatch() {
    if (_channel != null) {
      setState(() {
        _isMatching = true;
        _statusMessage = "🔍 進入高併發佇列，即時演算配對中...";
      });
      _pulseController.repeat(reverse: true); // 啟動呼吸脈衝
      _channel!.sink.add(jsonEncode({"action": "find_match"}));
    }
  }

  void _sendMessage() {
    final text = _chatController.text.trim();
    if (text.isNotEmpty && _isMatched && _channel != null) {
      _channel!.sink.add(jsonEncode({
        "action": "chat",
        "roomId": _roomId,
        "message": text,
      }));
      _chatController.clear();
    }
  }

  // 自動捲動到底部的魔法
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // 離開房間：清空對話、關閉當前 WS 並重新連線
  void _leaveRoom() {
    _channel?.sink.close();
    setState(() {
      _isMatched = false;
      _isMatching = false;
      _messages.clear();
      _roomId = "";
      _statusMessage = "重新建立安全連線中...";
    });
    _connectWebSocket();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _scrollController.dispose();
    _channel?.sink.close();
    _chatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isMatched ? '加密對話室' : 'VibeMatch 空間站'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          // 如果已配對，右上角顯示「離開房間」的按鈕
          if (_isMatched)
            IconButton(
              icon: const Icon(Icons.exit_to_app, color: Colors.redAccent),
              tooltip: '離開房間',
              onPressed: () {
                // 跳出確認對話框
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: Colors.grey[900],
                    title: const Text('終止通訊？'),
                    content: const Text('確定要離開這個聊天室嗎？這將會中斷目前的配對。'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('取消', style: TextStyle(color: Colors.grey)),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _leaveRoom();
                        },
                        child: const Text('確認離開', style: TextStyle(color: Colors.redAccent)),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 頂部透明進度追蹤器
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _isMatched ? Icons.lock_outline : Icons.wifi_tethering,
                    color: _isMatched ? Colors.greenAccent : Colors.cyanAccent,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _statusMessage,
                    style: TextStyle(
                      fontSize: 14,
                      color: _isMatched ? Colors.greenAccent : Colors.cyanAccent,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            // 主畫面區域切換：雷達 or 聊天室
            Expanded(
              child: !_isMatched ? _buildRadarView() : _buildChatView(),
            ),
          ],
        ),
      ),
    );
  }

  // 抽出雷達畫面的 Widget
  Widget _buildRadarView() {
    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 動畫擴散波紋
          if (_isMatching)
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _pulseAnimation.value,
                  child: Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.deepPurpleAccent.withOpacity(0.2 - (_pulseAnimation.value - 0.8) * 0.2),
                    ),
                  ),
                );
              },
            ),
          // 核心按鈕
          GestureDetector(
            onTap: _isMatching ? null : _findMatch,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: _isMatching
                      ? [Colors.grey[800]!, Colors.grey[700]!]
                      : [Colors.deepPurpleAccent, Colors.purpleAccent],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _isMatching ? Colors.transparent : Colors.deepPurpleAccent.withOpacity(0.5),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  _isMatching ? Icons.radar : Icons.power_settings_new,
                  size: 60,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 抽出聊天室畫面的 Widget
  Widget _buildChatView() {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            itemCount: _messages.length,
            itemBuilder: (context, index) {
              final msg = _messages[index];
              final isMe = msg['sender'] == '我';
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (!isMe) ...[
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: Colors.grey[700],
                        child: const Icon(Icons.person, size: 18, color: Colors.white),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        decoration: BoxDecoration(
                          gradient: isMe
                              ? const LinearGradient(colors: [Colors.deepPurpleAccent, Colors.purpleAccent])
                              : LinearGradient(colors: [Colors.grey[800]!, Colors.grey[700]!]),
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(20),
                            topRight: const Radius.circular(20),
                            bottomLeft: Radius.circular(isMe ? 20 : 0),
                            bottomRight: Radius.circular(isMe ? 0 : 20),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 5,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          msg['text']!,
                          style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.3),
                        ),
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 8),
                      const CircleAvatar(
                        radius: 16,
                        backgroundColor: Colors.deepPurpleAccent,
                        child: Icon(Icons.person, size: 18, color: Colors.white),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
        // 底部輸入區
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
          ),
          child: SafeArea(
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _chatController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: '輸入訊息...',
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: _sendMessage,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: Colors.deepPurpleAccent,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.send_rounded, color: Colors.white, size: 22),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}