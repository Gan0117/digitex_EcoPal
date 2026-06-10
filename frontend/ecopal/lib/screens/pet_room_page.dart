import 'package:flutter/material.dart';
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/api_service.dart';
import 'login_page.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/floating_pet.dart';
import 'leaderboard_page.dart';
import 'dart:ui';

class PetRoomPage extends StatefulWidget {
  const PetRoomPage({super.key});

  @override
  State<PetRoomPage> createState() => _PetRoomPageState();
}

class _PetRoomPageState extends State<PetRoomPage> {
  bool _isLoading = true;

  // Pet Data State
  String _name = '';
  String _species = 'Tabby'; 
  int _level = 1;
  int _hunger = 0;
  
  // User Data State
  int _rewardPoints = 0; 
  
  // Animation & Chat State
  String _currentState = 'idle'; 
  bool _isInteracting = false;
  String? _message;
  int _tapCount = 0;
  
  final int _oneTurnDurationMs = 1000;
  @override
  void initState() {
    super.initState();
    _loadPetData();

    // Enable global floating pet
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showFloatingPet.value = false;
    });
  }

  // Reloads all states dynamically from the backend
  Future<void> _loadPetData() async {
    try {
      final petData = await ApiService.getPetStatus();
      final profileData = await ApiService.getProfile(); 
      
      if (mounted) {
        setState(() {
          _name = petData['name'] ?? 'Unknown';
          _species = petData['species'] ?? 'Tabby';
          _level = petData['level'] ?? 1;
          _hunger = petData['hunger_level'] ?? 0;
          
          _rewardPoints = profileData['reward_points'] ?? 0; 
          _isLoading = false;
          
          _checkSleepCondition();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to load pet data.')));
      }
    }
  }

  void _checkSleepCondition() {
    if (_hunger <= 0 && !_isInteracting) {
      _currentState = 'sleep';
    } else if (_currentState == 'sleep' && _hunger > 0) {
      _currentState = 'idle';
    }
  }

  String get _currentGifPath {
    // 1. Force the species to lowercase so we never fail a check!
    String safeSpecies = _species.toLowerCase(); 
    
    String folder1 = safeSpecies; 
    String folder2 = _level <= 3 ? 'kitten' : 'cat'; 
    
    // 2. Use the safe, lowercase version to check the prefix
    String prefix = safeSpecies == 'tabby' 
        ? (_level <= 3 ? 'kit_' : 'cat_') 
        : (_level <= 3 ? 'orkt_' : 'org_');
        
    return 'widgets/$folder1/$folder2/$prefix$_currentState.gif';
  }

  void _speak(String text) {
    setState(() => _message = text);
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted && _message == text) {
        setState(() => _message = null);
      }
    });
  }

  void _handleTap() async {
    if (_isInteracting || _isLoading) return;

    setState(() {
      _isInteracting = true;
      _currentState = 'happy';
      _tapCount++;
    });

    try {
      await ApiService.interactWithPet('tap');
      await _loadPetData();
    } catch (e) {}

    try {
      if (_tapCount % 2 == 1) {
        final insight = await ApiService.getBehaviorAnalysis();
        final cleanInsight = insight
            .replaceAll(RegExp(r'✨.*?:'), '')
            .trim();
        _speak(cleanInsight); 
      } else {
        final scanInsight = await ApiService.getRealityCheck();
        _speak(scanInsight);
      }
    } catch (e) {
      _speak("You're doing great! Keep saving! 🌱");
    }

    await Future.delayed(Duration(milliseconds: _oneTurnDurationMs * 2));

    if (mounted) {
      setState(() {
        _isInteracting = false;
        _currentState = 'idle';
        _checkSleepCondition();
      });
    }
  }

  void _showInsufficientPointsMessage() {
    _speak('Meow! Insufficient points to redeem fish. Stay healthy spending to earn points!');
  }

  void _handleFeed() async {
    if (_isInteracting || _isLoading) return;
    
    // Quick frontend validation to prevent spamming empty requests, but NO local calculation
    if (_rewardPoints < 50) {
      _showInsufficientPointsMessage();
      return; 
    }

    // Save previous level to check if the backend decided to level us up
    int previousLevel = _level;

    setState(() {
      _isInteracting = true;
      _currentState = 'eat';
    });

    try {
      // 1. Tell backend to process the feeding (deducts points, adds hunger/level)
      await ApiService.interactWithPet('feed');
      // 2. Immediately pull the fresh data from the backend
      await _loadPetData();
    } catch (e) {
      // Handle error implicitly
    }

    await Future.delayed(Duration(milliseconds: _oneTurnDurationMs * 2)); 
    
    if (!mounted) return;

    // Check if the freshly loaded API data resulted in a level up!
    if (_level > previousLevel) {
      setState(() => _currentState = 'happy');
      _speak("Yay! I leveled up!"); 
      await Future.delayed(Duration(milliseconds: _oneTurnDurationMs * 2)); 
    }

    if (mounted) {
      setState(() {
        _isInteracting = false;
        _currentState = 'idle';
        _checkSleepCondition();
      });
    }
  }

  Future<void> _signOut() async {
    await Supabase.instance.client.auth.signOut();
    if (mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginPage()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      bottomNavigationBar: const EcoPalBottomBar(currentIndex: 2),
      body: Container(
        decoration: const BoxDecoration(
          color: Color(0xFFD6EEF5),
          image: DecorationImage(
            image: AssetImage('widgets/cat_pet_room.jpg'),
            fit: BoxFit.fitWidth,
            alignment: Alignment.bottomCenter,
          ),
        ),
        child: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : SafeArea(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // ==============================
                  // 🌟 上半部分：宠物状态、排行榜、喂食面板
                  // ==============================
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // ✨ 1. 顶部宠物名片：白底 + 深绿边框
                      Container(
                        margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.65),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white.withOpacity(0.6), width: 1.5),
                                boxShadow: [
                                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
                                ],
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    '$_name (Lvl $_level $_species)',
                                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F5238)),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      const Icon(Icons.restaurant, color: Colors.orange, size: 20),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: LinearProgressIndicator(
                                          value: _hunger / 100,
                                          backgroundColor: Colors.grey.shade200,
                                          color: Colors.orange,
                                          minHeight: 10,
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      Padding(
                        padding: const EdgeInsets.only(right: 24, top: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const LeaderboardPage()),
                                );
                              },
                              child: Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xFFFFD700),
                                  boxShadow: [
                                    BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 8, offset: const Offset(0, 3)),
                                  ],
                                ),
                                child: const Icon(Icons.emoji_events, color: Colors.white, size: 24),
                              ),
                            ),
                            
                            const SizedBox(height: 130), 
                            
                            ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.65),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: Colors.white.withOpacity(0.6), width: 1.5),
                                    boxShadow: [
                                      BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
                                    ],
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.stars, color: Colors.amber, size: 14),
                                          const SizedBox(width: 4),
                                          Text('$_rewardPoints pts',
                                              style: const TextStyle(
                                                  color: Colors.amber,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12)),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      const Text('Drag to Feed (50)',
                                          style: TextStyle(
                                              color: Color(0xFF0F5238), 
                                              fontWeight: FontWeight.bold,
                                              fontSize: 10)),
                                      const SizedBox(height: 4),
                                      Opacity(
                                        opacity: _rewardPoints >= 50 ? 1.0 : 0.5,
                                        child: _rewardPoints >= 50 
                                          ? Draggable<String>(
                                              data: 'fish_food', 
                                              feedback: Material(
                                                color: Colors.transparent, 
                                                child: Image.asset(
                                                  'widgets/fish.png',
                                                  width: 55, 
                                                  height: 55,
                                                  filterQuality: FilterQuality.none,
                                                ),
                                              ),
                                              childWhenDragging: Opacity(
                                                opacity: 0.2, 
                                                child: Image.asset(
                                                  'widgets/fish.png',
                                                  width: 42, 
                                                  height: 42,
                                                  filterQuality: FilterQuality.none,
                                                ),
                                              ),
                                              child: Image.asset(
                                                'widgets/fish.png',
                                                width: 42, 
                                                height: 42,
                                                filterQuality: FilterQuality.none,
                                              ),
                                            )
                                          : GestureDetector(
                                              onTap: _showInsufficientPointsMessage,
                                              child: Image.asset(
                                                'widgets/fish.png',
                                                width: 42, 
                                                height: 42,
                                                filterQuality: FilterQuality.none,
                                              ),
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ], 
                  ),

                  // ==============================
                  // 🌟 下半部分：猫咪和对话气泡
                  // ==============================
                  Expanded( 
                    child: DragTarget<String>(
                      onAcceptWithDetails: (details) {
                        if (details.data == 'fish_food') _handleFeed();
                      },
                      builder: (context, candidateData, rejectedData) {
                        return SizedBox(
                          width: double.infinity, 
                          child: Stack(
                            clipBehavior: Clip.none, 
                            alignment: Alignment.bottomCenter, 
                            children: [
                              GestureDetector(
                                onTap: _handleTap,
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 30), 
                                  child: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 300),
                                    child: Image.asset(
                                      _currentGifPath,
                                      key: ValueKey<String>(_currentGifPath),
                                      width: 190, 
                                      height: 190, 
                                      fit: BoxFit.contain,
                                      filterQuality: FilterQuality.none,
                                    ),
                                  ),
                                ),
                              ),
                              
                              if (_message != null)
                                Positioned(
                                  left: 20,     
                                  bottom: 220,  
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    constraints: const BoxConstraints(maxWidth: 150), 
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.95),
                                      borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(16),
                                        topRight: Radius.circular(16),
                                        bottomLeft: Radius.circular(16), 
                                        bottomRight: Radius.circular(0), 
                                      ),
                                      border: Border.all(color: const Color(0xFF0F5238).withOpacity(0.2)),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.1), 
                                          blurRadius: 8, 
                                          offset: const Offset(0, 4)
                                        )
                                      ],
                                    ),
                                    child: Text(
                                      _message!,
                                      style: const TextStyle(
                                        color: Colors.black, 
                                        fontWeight: FontWeight.bold, 
                                        fontSize: 13
                                      ),
                                      textAlign: TextAlign.left,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ], 
              ),
            ),
      ),
    );
  }
}