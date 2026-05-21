import 'dart:ui';
import 'package:flutter/material.dart';

// ── 聊天消息 model ─────────────────────────────────────────────────────────
class ChatMessage {
  final String text;        // 文字消息，sticker 时为空
  final String? stickerPath; // sticker 图片路径，文字消息时为 null
  final bool isMe;          // true = 自己发的，false = 对方发的
  final DateTime time;

  ChatMessage({
    this.text = '',
    this.stickerPath,
    required this.isMe,
    DateTime? time,
  }) : time = time ?? DateTime.now();

  bool get isSticker => stickerPath != null; // 判断是不是 sticker
}

// ── 可用的 sticker 列表（用已有的猫咪 gif）─────────────────────────────────
const List<Map<String, String>> kStickers = [
  {'path': 'widgets/tabby/kitten/kit_happy.gif',   'label': 'Happy'},
  {'path': 'widgets/tabby/kitten/kit_idle.gif',    'label': 'Idle'},
  {'path': 'widgets/tabby/kitten/kit_sleep.gif',   'label': 'Sleep'},
  {'path': 'widgets/orange/kitten/orkt_happy.gif', 'label': 'Happy'},
  {'path': 'widgets/orange/kitten/orkt_idle.gif',  'label': 'Idle'},
  {'path': 'widgets/orange/kitten/orkt_sleep.gif', 'label': 'Sleep'},
  {'path': 'widgets/tabby/cat/cat_happy.gif',      'label': 'Cat Happy'},
  {'path': 'widgets/tabby/cat/cat_idle.gif',       'label': 'Cat Idle'},
  {'path': 'widgets/orange/cat/org_happy.gif',     'label': 'Cat Happy'},
  {'path': 'widgets/orange/cat/org_idle.gif',      'label': 'Cat Idle'},
];

// ── ChatPage ───────────────────────────────────────────────────────────────
class ChatPage extends StatefulWidget {
  final String friendUsername; // 朋友的用户名
  final String friendSpecies;  // 朋友的猫咪种类（显示头像用）
  final int friendLevel;       // 朋友的等级

  const ChatPage({
    super.key,
    required this.friendUsername,
    required this.friendSpecies,
    required this.friendLevel,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _msgCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _showStickerPicker = false; // 控制 sticker 面板显示/隐藏

  // ── 颜色 ──────────────────────────────────────────────────────────────────
  static const Color _primary = Color(0xFF0F5238);
  static const Color _bubble = Color(0xFFB1F0CE);     // 自己的气泡颜色
  static const Color _bubbleFriend = Color(0xFFF0F0F0); // 对方的气泡颜色

  @override
  void initState() {
    super.initState();
    // 加几条 mock 消息作为示例
    _messages.addAll([
      ChatMessage(text: 'Hey! How\'s your garden doing? 🌱', isMe: false,
          time: DateTime.now().subtract(const Duration(minutes: 5))),
      ChatMessage(text: 'Pretty good! Just unlocked a new tree 🎉', isMe: true,
          time: DateTime.now().subtract(const Duration(minutes: 4))),
      ChatMessage(stickerPath: 'widgets/tabby/kitten/kit_happy.gif', isMe: false,
          time: DateTime.now().subtract(const Duration(minutes: 3))),
    ]);
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ── 获取朋友的猫咪头像 gif ─────────────────────────────────────────────
  String get _friendGif {
    final s = widget.friendSpecies.toLowerCase();
    final folder2 = widget.friendLevel <= 3 ? 'kitten' : 'cat';
    final prefix = s == 'tabby'
        ? (widget.friendLevel <= 3 ? 'kit_' : 'cat_')
        : (widget.friendLevel <= 3 ? 'orkt_' : 'org_');
    return 'widgets/$s/$folder2/${prefix}idle.gif';
  }

  // ── 滚动到底部 ────────────────────────────────────────────────────────────
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── 发送文字消息 ──────────────────────────────────────────────────────────
  void _sendText() {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _messages.add(ChatMessage(text: text, isMe: true));
      _msgCtrl.clear();
      _showStickerPicker = false;
    });
    _scrollToBottom();
  }

  // ── 发送 sticker ──────────────────────────────────────────────────────────
  void _sendSticker(String path) {
    setState(() {
      _messages.add(ChatMessage(stickerPath: path, isMe: true));
      _showStickerPicker = false; // 发完自动关闭面板
    });
    _scrollToBottom();
  }

  // ── 格式化时间 ────────────────────────────────────────────────────────────
  String _formatTime(DateTime t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  // ── 构建单条消息气泡 ──────────────────────────────────────────────────────
  Widget _buildBubble(ChatMessage msg) {
    final isMe = msg.isMe;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 对方头像（只有对方消息才显示）
          if (!isMe) ...[
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFECEEEA),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Padding(
                padding: const EdgeInsets.all(3),
                child: Image.asset(_friendGif,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.none),
              ),
            ),
            const SizedBox(width: 8),
          ],

          // 消息内容
          Column(
            crossAxisAlignment:
                isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              // sticker 或者文字气泡
              if (msg.isSticker)
                // sticker：直接显示图片，没有气泡背景
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Image.asset(msg.stickerPath!,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.none),
                )
              else
                // 文字气泡
                Container(
                  constraints: const BoxConstraints(maxWidth: 230),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isMe ? _bubble : _bubbleFriend,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(isMe ? 18 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 18),
                    ),
                  ),
                  child: Text(
                    msg.text,
                    style: TextStyle(
                      fontSize: 15,
                      color: isMe
                          ? const Color(0xFF002114)
                          : const Color(0xFF191C1A),
                    ),
                  ),
                ),

              const SizedBox(height: 3),
              // 时间戳
              Text(
                _formatTime(msg.time),
                style: const TextStyle(
                    fontSize: 10, color: Color(0xFF9E9E9E)),
              ),
            ],
          ),

          // 自己头像占位（保持对称，不显示）
          if (isMe) const SizedBox(width: 44),
        ],
      ),
    );
  }

  // ── Sticker 选择面板 ──────────────────────────────────────────────────────
  Widget _buildStickerPicker() {
    return Container(
      height: 180,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
            top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 5,   // 每行 5 个 sticker
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: kStickers.length,
        itemBuilder: (_, i) {
          final sticker = kStickers[i];
          return GestureDetector(
            onTap: () => _sendSticker(sticker['path']!),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(6),
              child: Image.asset(
                sticker['path']!,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.none,
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF6),
      // ── AppBar ──────────────────────────────────────────────────────────
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF404943)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            // 朋友猫咪头像
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFECEEEA),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Padding(
                padding: const EdgeInsets.all(3),
                child: Image.asset(_friendGif,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.none),
              ),
            ),
            const SizedBox(width: 12),
            // 朋友名字
            Text(
              widget.friendUsername,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF191C1A),
              ),
            ),
          ],
        ),
      ),

      // ── Body ─────────────────────────────────────────────────────────────
      body: Column(
        children: [
          // 消息列表
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              itemCount: _messages.length,
              itemBuilder: (_, i) => _buildBubble(_messages[i]),
            ),
          ),

          // Sticker 面板（按下按钮才显示）
          if (_showStickerPicker) _buildStickerPicker(),

          // ── 输入栏 ────────────────────────────────────────────────────
          Container(
            padding: EdgeInsets.only(
              left: 12,
              right: 12,
              top: 10,
              bottom: MediaQuery.of(context).padding.bottom + 10,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                // Sticker 按钮
                GestureDetector(
                  onTap: () => setState(
                      () => _showStickerPicker = !_showStickerPicker),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _showStickerPicker
                          ? const Color(0xFFB1F0CE)
                          : const Color(0xFFECEEEA),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.emoji_emotions_outlined,
                        size: 22, color: Color(0xFF0F5238)),
                  ),
                ),
                const SizedBox(width: 10),

                // 文字输入框
                Expanded(
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2F4F0),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: TextField(
                      controller: _msgCtrl,
                      style: const TextStyle(fontSize: 15),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendText(), // 键盘回车发送
                      decoration: const InputDecoration(
                        hintText: 'Type a message...',
                        hintStyle: TextStyle(
                            color: Color(0xFFBFC9C1), fontSize: 15),
                        border: InputBorder.none,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // 发送按钮
                GestureDetector(
                  onTap: _sendText,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _primary,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.send_rounded,
                        color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}