import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/api_service.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/floating_pet.dart';
import 'profile_page.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'chat_page.dart';

// ---------------------------------------------------------------------------
// Data models
// ---------------------------------------------------------------------------

class FriendEntry {
  final String uid;
  final String username;
  final String petName;
  final String species;
  final int level;
  final String weather;
  final List<FriendPocket> pockets;

  const FriendEntry({
    required this.uid,
    required this.username,
    required this.petName,
    required this.species,
    required this.level,
    required this.weather,
    this.pockets = const [],  
  });

  factory FriendEntry.fromJson(Map<String, dynamic> j) => FriendEntry(
        uid: j['user_id'] ?? j['uid'] ?? '',
        username: j['username'] ?? 'user',
        petName: j['pet_name'] ?? 'Unknown',
        species: j['species'] ?? 'tabby',
        level: j['level'] ?? 1,
        weather: j['weather'] ?? 'sunny',
        pockets: j['pockets'] != null
            ? (j['pockets'] as List)
                .map((e) => FriendPocket.fromJson(e))
                .toList()
            : [],
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
        uid: j['user_id'] ?? j['uid'] ?? '',
        username: j['username'] ?? 'user',
        petName: j['pet_name'] ?? 'Unknown',
        species: j['species'] ?? 'tabby',
        level: j['level'] ?? 1,
      );
}


class FriendPocket {
  final String name;
  final double currentBalance;
  final double targetAmount;
  final int growthStage;

  const FriendPocket({
    required this.name,
    required this.currentBalance,
    required this.targetAmount,
    required this.growthStage,
  });

  double get progress =>
      targetAmount > 0 ? (currentBalance / targetAmount).clamp(0.0, 1.0) : 0.0;

  factory FriendPocket.fromJson(Map<String, dynamic> j) => FriendPocket(
        name: j['name'] ?? '',
        currentBalance: (j['current_balance'] ?? 0).toDouble(),
        targetAmount: (j['target_amount'] ?? 1).toDouble(),
        growthStage: j['growth_stage'] ?? 1,
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
  int _tab = 0; // 0 = Friends List, 1 = Add New Friend

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

  String _filterStatus = 'all';
  String _filterTime = 'newest';
  String _filterLevel = 'none';
  final TextEditingController _listSearchCtrl = TextEditingController();

  // ── animation ─────────────────────────────────────────────────────────────
  late AnimationController _stagger;

  // ── Colors from HTML Tailwind Config ──────────────────────────────────────
  static const Color _primary = Color(0xFF0F5238);
  static const Color _surface = Color(0xFFF8FAF6);
  static const Color _onSurface = Color(0xFF191C1A);
  static const Color _onSurfaceVariant = Color(0xFF404943);
  static const Color _outlineVariant = Color(0xFFBFC9C1);
  static const Color _error = Color(0xFFBA1A1A);
  static const Color _gold = Color(0xFFD4AF37);
  static const Color _secondaryContainer = Color(0xFF92F7C3);

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
      
      // 🔥 1. We only need ONE API call now! The backend returns everything in a Map.
      final friendsData = await ApiService.getFriends(); 

      if (!mounted) return;

      setState(() {
        _uid = profile['id'] ?? profile['uid'] ?? 'u000-default';
        _username = profile['username'] ?? 'user';
        _species = (pet['species'] ?? 'tabby').toString().toLowerCase();
        _petLevel = pet['level'] ?? 1;
        _petName = pet['name'] ?? 'Companion';
        _petGifPath = _buildGif(_species, _petLevel);

        // 🔥 2. Extract the specific lists from the backend's JSON dictionary
        final List rawFriendsList = friendsData['friend_list'] ?? [];
        final List rawRequestsIn = friendsData['requests_in'] ?? [];

        _friends = rawFriendsList
            .map((e) => FriendEntry.fromJson(e as Map<String, dynamic>))
            .toList();
            
        _requests = rawRequestsIn
            .map((e) => FriendRequest.fromJson(e as Map<String, dynamic>))
            .toList();

        _isLoading = false;
      });

      _stagger.forward(from: 0);
    } catch (e) {
      debugPrint('API Error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _petGifPath = _buildGif('tabby', 1); 
        });
      }
    }
  }

  String _buildGif(String species, int level) {
    final safeSpecies = species.toLowerCase();
    final folder1 = safeSpecies; 
    final folder2 = level <= 3 ? 'kitten' : 'cat';
    
    final prefix = safeSpecies == 'tabby' 
        ? (level <= 3 ? 'kit_' : 'cat_') 
        : (level <= 3 ? 'orkt_' : 'org_');
        
    return 'widgets/$folder1/$folder2/${prefix}idle.gif';
  }

  // ── API Actions ───────────────────────────────────────────────────────────
  Future<void> _doSearch() async {
    final q = _searchCtrl.text.trim();
    if (q.isEmpty) return;
    setState(() {
      _isSearching = true;
      _searchResult = null;
      _searchError = null;
    });
    try {
      final result = await ApiService.searchUser(q);
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
      await _loadAll();
    } catch (_) {}
  }

  Future<void> _ignoreRequest(String senderUid) async {
    try {
      await ApiService.ignoreFriendRequest(senderUid);
      await _loadAll();
    } catch (_) {}
  }

  // ── HTML Style Glass Panel ────────────────────────────────────────────────
  Widget _glassPanel({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(16),
    double borderRadius = 24,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.7), // Lighter glass to match HTML
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: Colors.white.withOpacity(0.5)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
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

  // ── UI Components ─────────────────────────────────────────────────────────

 Widget _buildTopAppBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: _surface.withOpacity(0.6),
        border: Border(
            bottom: BorderSide(color: _outlineVariant.withOpacity(0.3))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: _onSurfaceVariant),
                onPressed: () => Navigator.pop(context),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(), 
              ),
              const SizedBox(width: 16),
              const Text(
                'Friends',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: _primary,
                  fontFamily: 'Plus Jakarta Sans',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  
Widget _buildHeaderCard() {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    child: SizedBox(
      width: double.infinity,
      child: _glassPanel(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFB1F0CE),
              ),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: _petGifPath.isEmpty
                    ? const SizedBox()
                    : Image.asset(_petGifPath,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.none),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _username.isEmpty ? 'Loading...' : _username,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: _onSurface,
              ),
            ),
            const SizedBox(height: 4),
            GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: _uid));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('UID copied!')),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFE7E9E5),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _uid.length > 4
                        ? '#ECO-${_uid.substring(0, 4).toUpperCase()}'
                        : '#ECO-0000',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.0,
                      color: Color(0xFF707973),
                    ),
                  ),
            const SizedBox(width: 6),
            const Icon(Icons.copy, size: 12, color: Color(0xFF707973)),
      ],
    ),
  ),
),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildSegmentedNav() {
    return Container(
      decoration: BoxDecoration(
        border: Border(
            bottom: BorderSide(color: _outlineVariant.withOpacity(0.5))),
      ),
      child: Row(
        children: [
          _buildTabButton(0, 'Friend List'),
          _buildTabButton(1, 'Add New Friend'),
        ],
      ),
    );
  }

  Widget _buildTabButton(int index, String title) {
    final isActive = _tab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          color: Colors.transparent,
          child: Column(
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: isActive ? _primary : _onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                height: 4,
                width: 24,
                decoration: BoxDecoration(
                  color: isActive ? _primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

    Widget _buildFriendsListTab() {
      if (_friends.isEmpty && _requests.isEmpty) {
        return const Center(
            child: Text('No friends yet. Add some!',
                style: TextStyle(color: _onSurfaceVariant, fontSize: 16)));
      }

      // 过滤 + 排序
      List<FriendEntry> filteredFriends = _friends.where((f) {
        if (_filterStatus != 'all' && f.weather != _filterStatus) return false;
        final q = _listSearchCtrl.text.trim().toLowerCase();
        if (q.isNotEmpty &&
            !f.username.toLowerCase().contains(q) &&
            !f.petName.toLowerCase().contains(q)) return false;
        return true;
      }).toList();

      if (_filterTime == 'oldest') {
        filteredFriends = filteredFriends.reversed.toList();
      }
      if (_filterLevel == 'high_low') {
        filteredFriends.sort((a, b) => b.level.compareTo(a.level));
      } else if (_filterLevel == 'low_high') {
        filteredFriends.sort((a, b) => a.level.compareTo(b.level));
      }

      List<Widget> items = [];

      // --- Friend Requests Section ---
      if (_requests.isNotEmpty) {
        items.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 16),
            child: Row(
              children: [
                const Text('Friend Requests',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: _onSurface)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                      color: _error, borderRadius: BorderRadius.circular(12)),
                  child: Text('${_requests.length}',
                      style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                ),
              ],
            ),
          ),
        );

        for (int i = 0; i < _requests.length; i++) {
          items.add(_animated(i, _buildRequestCard(_requests[i])));
          items.add(const SizedBox(height: 12));
        }
      }

      // --- Filters & Search Section ---
      items.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              Container(
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _outlineVariant.withOpacity(0.5)),
                ),
                child: TextField(
                  controller: _listSearchCtrl,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    hintText: 'Search ecosystem...',
                    hintStyle: TextStyle(fontSize: 14, color: _outlineVariant),
                    prefixIcon: Icon(Icons.search, color: _outlineVariant),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.only(top: 12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildDropdown<String>(
                      value: _filterStatus,
                      items: const [
                        DropdownMenuItem(value: 'all',      child: Text('Status: All')),
                        DropdownMenuItem(value: 'sunny',    child: Text('Status: ☀️ Sunny')),
                        DropdownMenuItem(value: 'overcast', child: Text('Status: ⛅ Overcast')),
                        DropdownMenuItem(value: 'storm',    child: Text('Status: ⛈ Storm')),
                      ],
                      onChanged: (v) => setState(() => _filterStatus = v!),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildDropdown<String>(
                      value: _filterTime,
                      items: const [
                        DropdownMenuItem(value: 'newest', child: Text('Time: Newest')),
                        DropdownMenuItem(value: 'oldest', child: Text('Time: Oldest')),
                      ],
                      onChanged: (v) => setState(() => _filterTime = v!),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildDropdown<String>(
                      value: _filterLevel,
                      items: const [
                        DropdownMenuItem(value: 'none',     child: Text('Level: None')),
                        DropdownMenuItem(value: 'high_low', child: Text('Level: High to Low')),
                        DropdownMenuItem(value: 'low_high', child: Text('Level: Low to High')),
                      ],
                      onChanged: (v) => setState(() => _filterLevel = v!),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );

  // --- My Pals Section ---
  items.add(
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 16),
      child: Row(
        children: [
          const Text('My Pals',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: _onSurface)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
                color: const Color(0xFFE7E9E5),
                borderRadius: BorderRadius.circular(8)),
            child: Text('${filteredFriends.length}',
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.bold, color: _primary)),
          ),
        ],
      ),
    ),
  );

  for (int i = 0; i < filteredFriends.length; i++) {
    items.add(
        _animated(_requests.length + i, _buildFriendCard(filteredFriends[i])));
    items.add(const SizedBox(height: 12));
  }

  return ListView(
    padding: const EdgeInsets.fromLTRB(24, 0, 24, 120),
    children: items,
  );
}

Widget _buildDropdown<T>({
  required T value,
  required List<DropdownMenuItem<T>> items,
  required ValueChanged<T?> onChanged,
}) {
  return Container(
    height: 40,
    padding: const EdgeInsets.symmetric(horizontal: 10),
    decoration: BoxDecoration(
      color: const Color(0xFFE7E9E5),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFBFC9C1).withOpacity(0.5)),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<T>(
        value: value,
        items: items,
        onChanged: onChanged,
        isDense: true,
        icon: const Icon(Icons.expand_more, size: 14, color: Color(0xFF404943)),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Color(0xFF404943),
        ),
        dropdownColor: const Color(0xFFF8FAF6),
        borderRadius: BorderRadius.circular(12),
      ),
    ),
  );
}

  Widget _buildFilterChip(String label, bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFFB1F0CE) : const Color(0xFFE7E9E5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: isActive
                ? const Color(0xFF2D6A4F).withOpacity(0.2)
                : _outlineVariant.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
                  color: isActive ? const Color(0xFF002114) : _onSurfaceVariant)),
          const SizedBox(width: 4),
          Icon(Icons.expand_more,
              size: 14,
              color: isActive ? const Color(0xFF002114) : _onSurfaceVariant),
        ],
      ),
    );
  }

  Widget _buildRequestCard(FriendRequest req) {
    return _glassPanel(
      padding: const EdgeInsets.all(16),
      borderRadius: 16,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFECEEEA),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _outlineVariant.withOpacity(0.3)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(4.0),
              child: Image.asset(_buildGif(req.species, req.level),
                  fit: BoxFit.contain, filterQuality: FilterQuality.none),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(req.username,
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _onSurface)),
                const SizedBox(height: 2),
                Text('Lv.${req.level} • ${req.petName}',
                    style: const TextStyle(
                        fontSize: 12, color: _onSurfaceVariant)),
              ],
            ),
          ),
          Row(
            children: [
              GestureDetector(
                onTap: () => _acceptRequest(req.uid),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                      color: _primary, borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.check, color: Colors.white, size: 20),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _ignoreRequest(req.uid),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                      color: const Color(0xFFBFC9C1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: _outlineVariant.withOpacity(0.3))),
                  child: const Icon(Icons.close,
                      color: _onSurfaceVariant, size: 20),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

 Widget _weatherBadge(String weather) {
  String emoji;
  String label;
  Color color;
  Color bg;

  switch (weather) {
    case 'overcast':
      emoji = '⛅';
      label = 'Overcast';
      color = const Color(0xFF7B6A00);
      bg = const Color(0xFFFFF9C4);
      break;
    case 'storm':
      emoji = '⛈️';
      label = 'Storm';
      color = const Color(0xFFBA1A1A);
      bg = const Color(0xFFFFDAD6);
      break;
    default:
      emoji = '☀️';
      label = 'Sunny';
      color = const Color(0xFF1B6E3A);
      bg = const Color(0xFFB1F0CE);
  }

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(100),
    ),
    child: Text(
      '$emoji $label',
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: color,
      ),
    ),
  );
}


String _treeImage(int index, int growthStage) {
  const names = ['first', 'second', 'third', 'fourth', 'fifth'];
  final name = names[index.clamp(0, 4)];
  if (growthStage >= 3) return 'widgets/dashboard/${name}_tree_big.png';
  if (growthStage == 2) return 'widgets/dashboard/${name}_tree_medium.png';
  return 'widgets/dashboard/${name}_tree_small.png';
}


Color _progressBarColor(double progress) {
  if (progress >= 0.9) return const Color(0xFF4CAF50); 
  if (progress >= 0.5) return const Color(0xFFE5B94A); 
  if (progress >= 0.2) return const Color(0xFFFF8C42); 
  return const Color(0xFFEF4444);                       
}

void _showFriendProfileDialog(FriendEntry friend) {
 
  final List<FriendPocket> displayPockets = friend.pockets.isNotEmpty
      ? friend.pockets
      : [
          const FriendPocket(name: 'Emergency Fund', currentBalance: 2000, targetAmount: 5000, growthStage: 2),
          const FriendPocket(name: 'Graduation Trip', currentBalance: 3000, targetAmount: 3000, growthStage: 3),
          const FriendPocket(name: 'Habit Tax', currentBalance: 80, targetAmount: 500, growthStage: 1),
          const FriendPocket(name: 'Entertainment', currentBalance: 400, targetAmount: 500, growthStage: 2),
          const FriendPocket(name: 'Eat', currentBalance: 460, targetAmount: 500, growthStage: 3),
        ];

  showDialog(
    context: context,
    barrierColor: Colors.black.withOpacity(0.45),
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 60),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,                          // 白色卡片
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 16, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    friend.username,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF191C1A),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFFECEEEA),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close, size: 16, color: Color(0xFF404943)),
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                children: [
                  Container(
                    width: 140,
                    height: 120,
                    decoration: BoxDecoration(
                      color: const Color(0xFFECEEEA),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Image.asset(
                        _buildGif(friend.species, friend.level),
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    friend.petName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF191C1A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Level badge
                  Text(
                    'Lv. ${friend.level}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF404943),
                    ),
                  ),
                ],
              ),
            ),

            
            Divider(color: Colors.grey.shade200, height: 1),

            // ── Plant Goals 区域 ──────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  
                  const Row(
                    children: [
                      Text('🌿', style: TextStyle(fontSize: 16)),
                      SizedBox(width: 6),
                      Text(
                        'Plant Goals',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF191C1A),
                        ),
                      ),
                    ],
                  ),
                  
                  _weatherBadge(friend.weather),
                ],
              ),
            ),

            const SizedBox(height: 12),

            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: displayPockets.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final pocket = displayPockets[i];
                  final progress = pocket.progress;
                  final barColor = _progressBarColor(progress);

                  return Row(
                    children: [
                      // 树的图片
                      SizedBox(
                        width: 28,
                        height: 28,
                        child: Image.asset(
                          _treeImage(i, pocket.growthStage),
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              pocket.name,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF191C1A),
                              ),
                            ),
                            const SizedBox(height: 4),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 7,
                                backgroundColor: const Color(0xFFECEEEA),
                                valueColor: AlwaysStoppedAnimation<Color>(barColor),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      // 百分比
                      Text(
                        '${(progress * 100).toInt()}%',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: barColor,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

            const SizedBox(height: 20),

           
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () {
                  Navigator.pop(ctx); 
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatPage(
                        friendUid: friend.uid,
                        friendUsername: friend.username,
                        friendSpecies: friend.species,
                        friendLevel: friend.level,
                      ),
                    ),
                  );
                },
                  icon: const Icon(Icons.chat_bubble_outline, size: 18, color: Color(0xFF0F5238)),
                  label: Text(
                    'Chat with ${friend.username}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F5238),
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFB1F0CE), // 浅绿色按钮
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildFriendCard(FriendEntry f) {
    return GestureDetector(
      onTap: () => _showFriendProfileDialog(f), 
      child: _glassPanel(
      padding: const EdgeInsets.all(16),
      borderRadius: 16,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFECEEEA),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _outlineVariant.withOpacity(0.3)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(4.0),
              child: Image.asset(_buildGif(f.species, f.level),
                  fit: BoxFit.contain, filterQuality: FilterQuality.none),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(f.username,
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _onSurface)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _weatherBadge(f.weather),
                    Text(' • Lv.${f.level}',  
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _onSurfaceVariant)),
                  ],
                ),
              ],
            ),
          ),
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _secondaryContainer.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.chevron_right,
                color: Color(0xFF00734D), size: 20),
          ),
        ],
      ),
      ),
    );
  }

  // ── ADD NEW FRIEND TAB (Tab 1) ────────────────────────────────────────────
  Widget _buildAddNewFriendTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
      children: [
        // Search Input
        const Text("ENTER FRIEND'S UID",
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _outlineVariant,
                letterSpacing: 1.2)),
        const SizedBox(height: 8),
        Container(
          height: 60,
          decoration: BoxDecoration(
            color: const Color(0xFFF2F4F0),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _outlineVariant.withOpacity(0.5), width: 2),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField( 
                  controller: _searchCtrl,
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: _primary),
                  decoration: const InputDecoration(
                    hintText: '#ECO-0000',
                    hintStyle: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Colors.black26),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 20),
                  ),
                  onSubmitted: (_) => _doSearch(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: GestureDetector(
                  onTap: _doSearch,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: _isSearching
                        ? const Padding(
                            padding: EdgeInsets.all(12.0),
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.person_add, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),

        if (_searchError != null) ...[
          const SizedBox(height: 12),
          Text(_searchError!, style: const TextStyle(color: Colors.red)),
        ],

        if (_searchResult != null) ...[
          const SizedBox(height: 16),
          _buildSearchResultHTMLStyle(_searchResult!),
        ],

        const SizedBox(height: 32),

        // QR Code Section
        _glassPanel(
          padding: const EdgeInsets.all(32),
          borderRadius: 40,
          child: Column(
            children: [
              const Text('Your Pal Code',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _onSurface)),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: _outlineVariant.withOpacity(0.3)),
                  boxShadow: const [
                    BoxShadow(color: Colors.black12, blurRadius: 8)
                  ],
                ),

                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    QrImageView(
                      data: _uid.isEmpty ? 'ECO-0000' : _uid,
                      version: QrVersions.auto,
                      size: 180,
                      backgroundColor: Colors.white,
                      eyeStyle: const QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: Color(0xFF0F5238),
                      ),
                      dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: Color(0xFF0F5238),
                      ),
                    ),
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: _petGifPath.isEmpty
                          ? const SizedBox()
                          : Image.asset(
                              _petGifPath,
                              fit: BoxFit.contain,
                              filterQuality: FilterQuality.none,
                            ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                  'Let friends scan this to instantly connect to your garden.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: _onSurfaceVariant)),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Scan Button
        GestureDetector(
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const QRScannerPage()),
            );
          },
          child: Container(
            width: double.infinity,
            height: 64,
            decoration: BoxDecoration(
              color: _primary,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                    color: _primary.withOpacity(0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 4))
              ],
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.qr_code_scanner, color: Colors.white, size: 28),
                SizedBox(width: 12),
                Text('Scan QR Code',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchResultHTMLStyle(Map<String, dynamic> result) {
    return _glassPanel(
      padding: const EdgeInsets.all(16),
      borderRadius: 16,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFECEEEA),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _outlineVariant.withOpacity(0.3)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(4.0),
              child: Image.asset(
                  _buildGif(result['species'] ?? 'tabby', result['level'] ?? 1),
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.none),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(result['username'] ?? 'User',
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _onSurface)),
                Text(result['pet_name'] ?? 'Pet',
                    style: const TextStyle(
                        fontSize: 12, color: _onSurfaceVariant)),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => _sendRequest(result['uid']),
            icon: const Icon(Icons.add, size: 16, color: Colors.white),
            label: const Text('Add', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }

  // ── Main Build ────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          // Background Image (As requested, keeping the GIF)
          Positioned.fill(
            child: Image.asset(
              'widgets/friend_background.gif',
              fit: BoxFit.cover,
            ),
          ),
          // We don't use the dark overlay anymore to match the Light HTML style
          // Positioned.fill(child: Container(color: Colors.white.withOpacity(0.1))),

          SafeArea(
            child: Column(
              children: [
                _buildTopAppBar(),
                Expanded(
                  child: Column(
                    children: [
                      _buildHeaderCard(),
                      _buildSegmentedNav(),
                      Expanded(
                        child: _isLoading
                            ? const Center(
                                child: CircularProgressIndicator(color: _primary))
                            : IndexedStack(
                                index: _tab,
                                children: [
                                  _buildFriendsListTab(),
                                  _buildAddNewFriendTab(),
                                ],
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: const EcoPalBottomBar(currentIndex: 4),
    );
  }
}
      class QRScannerPage extends StatefulWidget {
    const QRScannerPage({super.key});

    @override
    State<QRScannerPage> createState() => _QRScannerPageState();
  }

  class _QRScannerPageState extends State<QRScannerPage> {
    MobileScannerController cameraController = MobileScannerController();
    bool _scanned = false;

    @override
    void dispose() {
      cameraController.dispose();
      super.dispose();
    }

    @override
    Widget build(BuildContext context) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Scan QR Code'),
          backgroundColor: const Color(0xFF0F5238),
          foregroundColor: Colors.white,
        ),
        body: MobileScanner(
          controller: cameraController,
          onDetect: (capture) async {
            if (_scanned) return;
            final barcode = capture.barcodes.first;
            final value = barcode.rawValue;
            print('Scanned QR Code: $value');
            if (value != null) {
              _scanned = true;
              try {
                await ApiService.sendFriendRequest(value);
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Friend request sent!')),
                  );
                }
              } catch (_) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Failed to send request.')),
                  );
                }
              }
            }
          },
        ),
      );
    }
  }
