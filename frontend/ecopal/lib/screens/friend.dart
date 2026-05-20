import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/api_service.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/floating_pet.dart';
import 'profile_page.dart';


// ---------------------------------------------------------------------------
// Data models
// ---------------------------------------------------------------------------

class FriendEntry {
  final String uid;
  final String username;
  final String petName;
  final String species;
  final int level;
  final int streak;

  const FriendEntry({
    required this.uid,
    required this.username,
    required this.petName,
    required this.species,
    required this.level,
    required this.streak,
  });

  factory FriendEntry.fromJson(Map<String, dynamic> j) => FriendEntry(
        uid: j['uid'] ?? '',
        username: j['username'] ?? 'user',
        petName: j['pet_name'] ?? 'Unknown',
        species: j['species'] ?? 'tabby',
        level: j['level'] ?? 1,
        streak: j['streak'] ?? 0,
      );
}

class FriendRequest {
  final String uid;
  final String username;
  final String petName;
  final String species;
  final int level;

  const FriendRequest({
    required this.uid,
    required this.username,
    required this.petName,
    required this.species,
    required this.level,
  });

  factory FriendRequest.fromJson(Map<String, dynamic> j) => FriendRequest(
        uid: j['uid'] ?? '',
        username: j['username'] ?? 'user',
        petName: j['pet_name'] ?? 'Unknown',
        species: j['species'] ?? 'tabby',
        level: j['level'] ?? 1,
      );
}

// ---------------------------------------------------------------------------
// Page
// ---------------------------------------------------------------------------

class FriendsPage extends StatefulWidget {
  const FriendsPage({super.key});

  @override
  State<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage>
    with SingleTickerProviderStateMixin {
  // ── tab state ──────────────────────────────────────────────────────────────
  int _tab = 0; // 0 = Friends, 1 = Add, 2 = QR

  // ── current user ──────────────────────────────────────────────────────────
  bool _isLoading = true;
  String _uid = '';
  String _username = '';
  String _petGifPath = '';
  String _petName = '';
  String _species = 'tabby';
  int _petLevel = 1;

  // ── friends data ──────────────────────────────────────────────────────────
  List<FriendEntry> _friends = [];
  List<FriendRequest> _requests = [];

  // ── add-friend search ─────────────────────────────────────────────────────
  final TextEditingController _searchCtrl = TextEditingController();
  bool _isSearching = false;
  Map<String, dynamic>? _searchResult;
  String? _searchError;

  // ── animation ─────────────────────────────────────────────────────────────
  late AnimationController _stagger;

  // ── colors (matches leaderboard palette) ──────────────────────────────────
  static const Color _primary = Color(0xFF0F5238);
  static const Color _secondary = Color(0xFF006C48);
  static const Color _accent = Color(0xFF92F7C3);
  static const Color _gold = Color(0xFFFFD700);
  static const Color _silver = Color(0xFFC0C0C0);
  static const Color _bronze = Color(0xFFCD7F32);

  // ── lifecycle ──────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _stagger = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showFloatingPet.value = false;
    });
    _loadAll();
  }

  @override
  void dispose() {
    _stagger.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── data loading ──────────────────────────────────────────────────────────
  Future<void> _loadAll() async {
    try {
      final profile = await ApiService.getProfile();
      final pet = await ApiService.getPetStatus();
      final friendsRaw = await ApiService.getFriends();        // returns List
      final requestsRaw = await ApiService.getFriendRequests(); // returns List

      if (!mounted) return;
      setState(() {
        _uid = profile['uid'] ?? Supabase.instance.client.auth.currentUser?.id ?? '';
        _username = profile['username'] ?? 'user';
        _species = (pet['species'] ?? 'tabby').toString().toLowerCase();
        _petLevel = pet['level'] ?? 1;
        _petName = pet['name'] ?? 'Companion';
        _petGifPath = _buildGif(_species, _petLevel);

        _friends = (friendsRaw as List)
            .map((e) => FriendEntry.fromJson(e as Map<String, dynamic>))
            .toList();
        _requests = (requestsRaw as List)
            .map((e) => FriendRequest.fromJson(e as Map<String, dynamic>))
            .toList();

        _isLoading = false;
      });
      _stagger.forward(from: 0);
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── helpers ───────────────────────────────────────────────────────────────
  String _buildGif(String species, int level) {
    final s = species.toLowerCase();
    final folder2 = level <= 3 ? 'kitten' : 'cat';
    final prefix =
        s == 'tabby' ? (level <= 3 ? 'kit_' : 'cat_') : (level <= 3 ? 'orkt_' : 'org_');
    return 'widgets/$s/$folder2/${prefix}idle.gif';
  }

  Color _medalColor(int rank) {
    if (rank == 1) return _gold;
    if (rank == 2) return _silver;
    if (rank == 3) return _bronze;
    return Colors.white.withOpacity(0.55);
  }

  // ── search ────────────────────────────────────────────────────────────────
  Future<void> _doSearch() async {
    final q = _searchCtrl.text.trim();
    if (q.isEmpty) return;
    setState(() {
      _isSearching = true;
      _searchResult = null;
      _searchError = null;
    });
    try {
      final result = await ApiService.searchUser(q); // returns Map or null
      setState(() {
        _searchResult = result;
        _searchError = result == null ? 'No user found.' : null;
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _searchError = 'Search failed. Try again.';
        _isSearching = false;
      });
    }
  }

  Future<void> _sendRequest(String targetUid) async {
    try {
      await ApiService.sendFriendRequest(targetUid);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Friend request sent!')));
        setState(() => _searchResult = null);
        _searchCtrl.clear();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Failed to send request.')));
      }
    }
  }

  Future<void> _acceptRequest(String senderUid) async {
    try {
      await ApiService.acceptFriendRequest(senderUid);
      setState(() => _requests.removeWhere((r) => r.uid == senderUid));
      await _loadAll();
    } catch (_) {}
  }

  Future<void> _ignoreRequest(String senderUid) async {
    try {
      await ApiService.ignoreFriendRequest(senderUid);
      setState(() => _requests.removeWhere((r) => r.uid == senderUid));
    } catch (_) {}
  }

  // ── glass card (same as leaderboard) ──────────────────────────────────────
  Widget _glass({
    required Widget child,
    Color? borderColor,
    EdgeInsetsGeometry padding =
        const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    double borderWidth = 1.5,
    double radius = 20,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.13),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: borderColor ?? Colors.white.withOpacity(0.30),
              width: borderWidth,
            ),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.18),
                  blurRadius: 12,
                  offset: const Offset(0, 4)),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _animated(int index, Widget child) {
    final start = (index * 0.07).clamp(0.0, 0.7);
    final end = (start + 0.35).clamp(0.0, 1.0);
    final anim = CurvedAnimation(
        parent: _stagger,
        curve: Interval(start, end, curve: Curves.easeOutCubic));
    return AnimatedBuilder(
      animation: anim,
      builder: (_, __) => Opacity(
        opacity: anim.value,
        child: Transform.translate(
            offset: Offset(0, 24 * (1 - anim.value)), child: child),
      ),
    );
  }

  // ── pet avatar at top (tappable → ProfilePage) ────────────────────────────
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: _glass(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // UID display
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('UID',
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.white60,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.1)),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          _uid.isEmpty ? 'Loading...' : _uid,
                          style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white,
                              fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: _uid));
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('UID copied!')));
                        },
                        child: const Icon(Icons.copy,
                            size: 14, color: Colors.white54),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Animated cat gif → taps to ProfilePage
            GestureDetector(
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ProfilePage())),
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: _accent.withOpacity(0.7), width: 2),
                  color: const Color(0xFF1A2A22),
                ),
                child: ClipOval(
                  child: _petGifPath.isEmpty
                      ? const SizedBox()
                      : Image.asset(
                          _petGifPath,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.none,
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── tab bar ───────────────────────────────────────────────────────────────
  Widget _buildTabBar() {
    const labels = ['Friends', 'Add', 'QR'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: _glass(
        padding: const EdgeInsets.all(4),
        child: Row(
          children: List.generate(3, (i) {
            final selected = _tab == i;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _tab = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: selected
                        ? _accent.withOpacity(0.25)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                    border: selected
                        ? Border.all(color: _accent.withOpacity(0.5))
                        : null,
                  ),
                  child: Text(
                    labels[i],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: selected ? _accent : Colors.white60,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  // ── FRIENDS TAB ───────────────────────────────────────────────────────────
  Widget _buildFriendsTab() {
    if (_friends.isEmpty && _requests.isEmpty) {
      return Center(
          child: Text('No friends yet. Add some!',
              style:
                  TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 16)));
    }

    final items = <Widget>[];

    // ── Pending requests section ──
    if (_requests.isNotEmpty) {
      items.add(Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text('Requests (${_requests.length})',
            style: const TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w700,
                fontSize: 13,
                letterSpacing: 0.8)),
      ));
      for (int i = 0; i < _requests.length; i++) {
        items.add(_animated(i, _buildRequestCard(_requests[i])));
        items.add(const SizedBox(height: 10));
      }
      items.add(const SizedBox(height: 8));
    }

    // ── Friend list section ──
    if (_friends.isNotEmpty) {
      items.add(Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text('Friends (${_friends.length})',
            style: const TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w700,
                fontSize: 13,
                letterSpacing: 0.8)),
      ));
      for (int i = 0; i < _friends.length; i++) {
        final f = _friends[i];
        final rank = i + 1;
        items.add(_animated(
            _requests.length + i, _buildFriendCard(f, rank)));
        items.add(const SizedBox(height: 10));
      }
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      children: items,
    );
  }

  // friend request card with accept / ignore image buttons
  Widget _buildRequestCard(FriendRequest req) {
    return _glass(
      borderColor: _accent.withOpacity(0.35),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          // pet avatar
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                  color: Colors.white.withOpacity(0.25), width: 1.5),
              color: const Color(0xFF1A2A22),
            ),
            child: ClipOval(
              child: Image.asset(
                _buildGif(req.species, req.level),
                fit: BoxFit.contain,
                filterQuality: FilterQuality.none,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(req.petName,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14)),
                Text('@${req.username}',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.55),
                        fontSize: 12)),
              ],
            ),
          ),
          // ignore button (image)
          GestureDetector(
            onTap: () => _ignoreRequest(req.uid),
            child: SizedBox(
              width: 40,
              height: 40,
              child: Image.asset(
                'widgets/ignore_button.jpeg',
                fit: BoxFit.contain,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // accept button (image)
          GestureDetector(
            onTap: () => _acceptRequest(req.uid),
            child: SizedBox(
              width: 40,
              height: 40,
              child: Image.asset(
                'widgets/accept_button.jpeg',
                fit: BoxFit.contain,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // friend card – same leaderboard glass style
  Widget _buildFriendCard(FriendEntry f, int rank) {
    final mc = _medalColor(rank);
    final isTop3 = rank <= 3;

    return _glass(
      borderColor: isTop3 ? mc.withOpacity(0.5) : null,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          // rank badge
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: mc.withOpacity(0.18),
              border: Border.all(color: mc, width: 1.5),
            ),
            child: Center(
              child: Text('#$rank',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: mc)),
            ),
          ),
          const SizedBox(width: 12),
          // pet avatar
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                  color: isTop3
                      ? mc.withOpacity(0.7)
                      : Colors.white.withOpacity(0.20),
                  width: 1.5),
              color: const Color(0xFF1A2A22),
            ),
            child: ClipOval(
              child: Image.asset(
                _buildGif(f.species, f.level),
                fit: BoxFit.contain,
                filterQuality: FilterQuality.none,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // name + username
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(f.petName,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text('@${f.username}',
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.50))),
              ],
            ),
          ),
          // streak pill
          Container(
            margin: const EdgeInsets.only(right: 6),
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withOpacity(0.18),
              borderRadius: BorderRadius.circular(100),
              border: Border.all(
                  color: const Color(0xFFF59E0B).withOpacity(0.5)),
            ),
            child: Text('🔥 ${f.streak}',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFF59E0B))),
          ),
          // level pill
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _secondary.withOpacity(0.25),
              borderRadius: BorderRadius.circular(100),
              border: Border.all(color: _secondary.withOpacity(0.5)),
            ),
            child: Text('Lv. ${f.level}',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _accent)),
          ),
        ],
      ),
    );
  }

  // ── ADD TAB ───────────────────────────────────────────────────────────────
  Widget _buildAddTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      children: [
        _glass(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Find by username',
                  style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      letterSpacing: 0.8)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                        child: TextField(
                          controller: _searchCtrl,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Enter username...',
                            hintStyle: TextStyle(
                                color: Colors.white.withOpacity(0.4)),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                  color: Colors.white.withOpacity(0.2)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                  color: Colors.white.withOpacity(0.2)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                  color: _accent.withOpacity(0.6),
                                  width: 1.5),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                          ),
                          onSubmitted: (_) => _doSearch(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: _doSearch,
                    child: Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: _accent.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: _accent.withOpacity(0.5), width: 1.5),
                      ),
                      child: _isSearching
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(
                                  color: _accent, strokeWidth: 2),
                            )
                          : const Icon(Icons.search,
                              color: _accent, size: 22),
                    ),
                  ),
                ],
              ),
              if (_searchError != null) ...[
                const SizedBox(height: 12),
                Text(_searchError!,
                    style: const TextStyle(color: Colors.redAccent)),
              ],
              if (_searchResult != null) ...[
                const SizedBox(height: 16),
                _buildSearchResultCard(_searchResult!),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSearchResultCard(Map<String, dynamic> result) {
    final species =
        (result['species'] ?? 'tabby').toString().toLowerCase();
    final level = result['level'] ?? 1;
    final uid = result['uid'] ?? '';

    return _glass(
      borderColor: _accent.withOpacity(0.4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                  color: _accent.withOpacity(0.5), width: 1.5),
              color: const Color(0xFF1A2A22),
            ),
            child: ClipOval(
              child: Image.asset(
                _buildGif(species, level),
                fit: BoxFit.contain,
                filterQuality: FilterQuality.none,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(result['pet_name'] ?? 'Unknown',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15)),
                Text('@${result['username'] ?? ''}',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.55),
                        fontSize: 12)),
              ],
            ),
          ),
          // Add Friend button – same fish-drag style pill
          GestureDetector(
            onTap: () => _sendRequest(uid),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFF1DB46A), _accent]),
                borderRadius: BorderRadius.circular(100),
                boxShadow: [
                  BoxShadow(
                      color: _accent.withOpacity(0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 2)),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset('widgets/add_friend.png',
                      width: 18,
                      height: 18,
                      fit: BoxFit.contain,
                      color: Colors.white),
                  const SizedBox(width: 6),
                  const Text('Add',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 13)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── QR TAB ────────────────────────────────────────────────────────────────
  Widget _buildQrTab() {
    return Center(
      child: _glass(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.qr_code_2_rounded,
                color: _accent, size: 120),
            const SizedBox(height: 16),
            Text(_username,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 18)),
            const SizedBox(height: 8),
            SelectableText(_uid,
                style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 11)),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: _uid));
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('UID copied!')));
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  border: Border.all(color: _accent.withOpacity(0.5)),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: const Text('Copy UID',
                    style: TextStyle(
                        color: _accent,
                        fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          // Background
          Positioned.fill(
            child: Image.asset(
              'widgets/friend_background.gif',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: Container(color: Colors.black.withOpacity(0.35)),
          ),

          SafeArea(
            child: Column(
              children: [
                // Top bar (UID + pet avatar)
                _buildTopBar(),

                const SizedBox(height: 4),

                // Page title
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: _glass(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Friends',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.3),
                        ),
                        SizedBox(width: 8),
                        Text('🐾', style: TextStyle(fontSize: 18)),
                      ],
                    ),
                  ),
                ),

                // Tab bar
                _buildTabBar(),

                const SizedBox(height: 8),

                // Tab content
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                              color: _accent))
                      : IndexedStack(
                          index: _tab,
                          children: [
                            _buildFriendsTab(),
                            _buildAddTab(),
                            _buildQrTab(),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: const EcoPalBottomBar(currentIndex: 3),
    );
  }
}