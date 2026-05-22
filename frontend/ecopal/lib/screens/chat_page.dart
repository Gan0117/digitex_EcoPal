import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/api_service.dart'; // Ensure this path is correct

// ── Chat Message Model ───────────────────────────────────────────────────────
class ChatMessage {
  final String text;          // Text message content
  final String? stickerPath;  // Null if it's a text message
  final bool isMe;            // true = sent by current user, false = received
  final DateTime time;

  ChatMessage({
    this.text = '',
    this.stickerPath,
    required this.isMe,
    required this.time,
  });

  bool get isSticker => stickerPath != null; 
}

// ── Available Stickers (Using existing cat GIFs) ─────────────────────────────
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
  final String friendUid;      // 🔥 NEW: We need their ID to send messages!
  final String friendUsername; 
  final String friendSpecies;  
  final int friendLevel;       

  const ChatPage({
    super.key,
    required this.friendUid,
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
  List<ChatMessage> _messages = [];
  bool _showStickerPicker = false; 
  String _myUid = '';

  // Supabase realtime subscription
  RealtimeChannel? _messageSubscription;

  // ── Colors ──────────────────────────────────────────────────────────────────
  static const Color _primary = Color(0xFF0F5238);
  static const Color _bubble = Color(0xFFB1F0CE);     // My bubble color
  static const Color _bubbleFriend = Color(0xFFF0F0F0); // Friend bubble color

  @override
  void initState() {
    super.initState();
    _myUid = Supabase.instance.client.auth.currentUser?.id ?? '';
    _loadChatHistory();
    _setupRealtimeListener();
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    _messageSubscription?.unsubscribe(); // 🔥 Clean up the listener when leaving
    super.dispose();
  }

  // ── 1. Load Past Messages ─────────────────────────────────────────────────
  Future<void> _loadChatHistory() async {
    try {
      // Ask Supabase directly for history between these two users
      final data = await Supabase.instance.client
          .from('messages')
          .select()
          .or('and(sender_id.eq.$_myUid,receiver_id.eq.${widget.friendUid}),and(sender_id.eq.${widget.friendUid},receiver_id.eq.$_myUid)')
          .order('created_at', ascending: true);

      setState(() {
        _messages = data.map<ChatMessage>((row) => ChatMessage(
          text: row['text'] ?? '',
          stickerPath: row['sticker_path'],
          isMe: row['sender_id'] == _myUid,
          time: DateTime.parse(row['created_at']).toLocal(),
        )).toList();
      });
      _scrollToBottom();
    } catch (e) {
      debugPrint("Error loading history: $e");
    }
  }

  // ── 2. The Live Walkie-Talkie (Realtime) ──────────────────────────────────
  void _setupRealtimeListener() {
    _messageSubscription = Supabase.instance.client
        .channel('public:messages')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          callback: (payload) {
            final newRow = payload.newRecord;
            
            // Safety check: ensure it's not null before trying to read it
            if (newRow == null) return;

            // Only show it if it belongs to this specific chat room
            if ((newRow['sender_id'] == _myUid && newRow['receiver_id'] == widget.friendUid) ||
                (newRow['sender_id'] == widget.friendUid && newRow['receiver_id'] == _myUid)) {
              
              setState(() {
                _messages.add(ChatMessage(
                  text: newRow['text'] ?? '',
                  stickerPath: newRow['sticker_path'],
                  isMe: newRow['sender_id'] == _myUid,
                  time: DateTime.parse(newRow['created_at']).toLocal(),
                ));
              });
              _scrollToBottom();
            }
          },
        )
        .subscribe();
  }

  // ── Get Friend Avatar GIF ─────────────────────────────────────────────
  String get _friendGif {
    final s = widget.friendSpecies.toLowerCase();
    final folder2 = widget.friendLevel <= 3 ? 'kitten' : 'cat';
    final prefix = s == 'tabby'
        ? (widget.friendLevel <= 3 ? 'kit_' : 'cat_')
        : (widget.friendLevel <= 3 ? 'orkt_' : 'org_');
    return 'widgets/$s/$folder2/${prefix}idle.gif';
  }

  // ── Scroll to Bottom ──────────────────────────────────────────────────────
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

  // ── Send Text Message ─────────────────────────────────────────────────────
  Future<void> _sendText() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    
    // Clear UI instantly for better feel, backend handles the save
    _msgCtrl.clear(); 
    setState(() => _showStickerPicker = false);

    try {
      await ApiService.sendMessage(widget.friendUid, text: text);
    } catch (e) {
      debugPrint("Failed to send text: $e");
    }
  }

  // ── Send Sticker ──────────────────────────────────────────────────────────
  Future<void> _sendSticker(String path) async {
    setState(() => _showStickerPicker = false); // Close panel automatically
    
    try {
      await ApiService.sendMessage(widget.friendUid, stickerPath: path);
    } catch (e) {
      debugPrint("Failed to send sticker: $e");
    }
  }

  // ── Format Time ───────────────────────────────────────────────────────────
  String _formatTime(DateTime t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  // ── Build Single Message Bubble ───────────────────────────────────────────
  Widget _buildBubble(ChatMessage msg) {
    final isMe = msg.isMe;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Friend Avatar (Only show on their messages)
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

          // Message Content
          Column(
            crossAxisAlignment:
                isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (msg.isSticker)
                // Sticker: Direct image display, no background bubble
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
                // Text Bubble
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
              // Timestamp
              Text(
                _formatTime(msg.time),
                style: const TextStyle(
                    fontSize: 10, color: Color(0xFF9E9E9E)),
              ),
            ],
          ),

          // Spacer for my messages to keep symmetry
          if (isMe) const SizedBox(width: 44),
        ],
      ),
    );
  }

  // ── Sticker Selection Panel ───────────────────────────────────────────────
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
          crossAxisCount: 5,   // 5 stickers per row
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
          // Message List
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              itemCount: _messages.length,
              itemBuilder: (_, i) => _buildBubble(_messages[i]),
            ),
          ),

          // Sticker Panel (Shows when button is tapped)
          if (_showStickerPicker) _buildStickerPicker(),

          // ── Input Bar ────────────────────────────────────────────────────
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
                // Sticker Button
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

                // Text Input Field
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
                      onSubmitted: (_) => _sendText(), // Send on keyboard enter
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

                // Send Button
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