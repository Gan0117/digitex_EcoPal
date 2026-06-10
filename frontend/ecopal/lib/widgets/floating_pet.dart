import 'package:flutter/material.dart';
import 'dart:async';
import '../services/api_service.dart';

// Global controllers to manage the pet's visibility and data state from ANY page
final ValueNotifier<bool> showFloatingPet = ValueNotifier<bool>(false);
final ValueNotifier<int> reloadPetTrigger = ValueNotifier<int>(0);
// 🔥 Goal 1: Added reward points global notifier
final ValueNotifier<int> rewardPointsEarnedNotifier = ValueNotifier<int>(0); 

class FloatingPet extends StatefulWidget {
  const FloatingPet({super.key});

  @override
  State<FloatingPet> createState() => FloatingPetState();
}

class FloatingPetState extends State<FloatingPet> with SingleTickerProviderStateMixin {
  Offset _position = const Offset(20, 100);

  String _species = '';
  int _level = 1;
  bool _isLoading = true;
  String? _message;
  
  late AnimationController _snapController;
  late Animation<Offset> _snapAnimation;

  Timer? _cheerTimer;
  bool _isNextCheerPocket = true;
  bool _hasGreeted = false;

  final double _petSize = 65.0;
  final double _bubbleMaxWidth = 220.0;
  final double _edgeMargin = 10.0;

  @override
  void initState() {
    super.initState();
    _loadPetData();
    
    reloadPetTrigger.addListener(_loadPetData);
    showFloatingPet.addListener(_handleVisibilityChange); 
    rewardPointsEarnedNotifier.addListener(_handleRewardPoints); // 🔥 Listen to new point events

    _snapController = AnimationController(
      vsync: this, 
      duration: const Duration(milliseconds: 350)
    );
    _snapController.addListener(() {
      setState(() {
        _position = _snapAnimation.value;
      });
    });

    _cheerTimer = Timer.periodic(const Duration(minutes: 3), (timer) {
      _triggerPeriodicCheer();
    });
  }

  @override
  void dispose() {
    reloadPetTrigger.removeListener(_loadPetData);
    showFloatingPet.removeListener(_handleVisibilityChange);
    rewardPointsEarnedNotifier.removeListener(_handleRewardPoints);
    _snapController.dispose();
    _cheerTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadPetData() async {
    try {
      final petData = await ApiService.getPetStatus();
      if (mounted) {
        setState(() {
          _species = petData['species'] ?? 'Tabby';
          _level = petData['level'] ?? 1;
          _isLoading = false;
        });
        _handleVisibilityChange(); 
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _species = 'Tabby';
          _isLoading = false;
        });
      }
    }
  }

  void _handleVisibilityChange() {
    if (showFloatingPet.value && !_isLoading && _species.isNotEmpty && !_hasGreeted) {
      _hasGreeted = true;
      final hour = DateTime.now().hour;
      String greeting;
      if (hour < 12) {
        greeting = "Good morning!";
      } else if (hour < 18) {
        greeting = "Good afternoon!";
      } else {
        greeting = "Good evening!";
      }
      speak(greeting);
    }
  }

  // 🔥 Goal 1: Handle reward points feedback visually with the pet!
  void _handleRewardPoints() {
    final points = rewardPointsEarnedNotifier.value;
    if (points > 0) {
      speak("Awesome! We earned $points reward points! 🌟");
    }
  }

  Future<void> _triggerPeriodicCheer() async {
    if (!showFloatingPet.value || _isLoading || _message != null) return;

    try {
      if (_isNextCheerPocket) {
        final pockets = await ApiService.getPockets();
        double bestRatio = -1.0;
        String? bestPocketName;

        for (var p in pockets) {
          double current = (p['current_balance'] ?? 0).toDouble();
          double target = (p['target_amount'] ?? 0).toDouble();
          bool isLocked = p['is_locked'] ?? false;

          if (target > 0 && !isLocked) {
            double ratio = current / target;
            if (ratio > bestRatio && ratio < 1.0) {
              bestRatio = ratio;
              bestPocketName = p['name'];
            }
          }
        }

        if (bestRatio > 0 && bestPocketName != null) {
          speak("You are ${(bestRatio * 100).toInt()}% of the way to your '$bestPocketName' goal! Keep going!");
          _isNextCheerPocket = false; 
        } else {
          _isNextCheerPocket = false;
          _triggerPeriodicCheer(); 
        }

      } else {
        final taxData = await ApiService.getHabitTax();
        bool isAvailable = taxData['available'] ?? false;
        double amount = (taxData['amount'] ?? 0).toDouble();

        if (isAvailable && amount > 0) {
          speak("You've secretly saved RM ${amount.toStringAsFixed(2)} in your Habit Tabung just by having fun!");
        }
        
        _isNextCheerPocket = true; 
      }
    } catch (e) {
      debugPrint("Cheer error: $e"); 
    }
  }

  String get _gifPath {
    String f1 = _species.toLowerCase();
    String f2 = _level <= 3 ? 'kitten' : 'cat';
    String px = f1 == 'tabby' ? (_level <= 3 ? 'kit_' : 'cat_') : (_level <= 3 ? 'orkt_' : 'org_');
    
    return 'widgets/$f1/$f2/${px}idle.gif';
  }
  
  void speak(String text) {
    setState(() => _message = text);
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted && _message == text) {
        setState(() => _message = null);
      }
    });
  }

  void _triggerSavingsTip() async {
    setState(() => _message = "Thinking...");
    try {
      String tip = await ApiService.getSavingsTip();
      speak("💡 Tip: $tip");
    } catch (e) {
      speak("Meow! Systems offline.");
    }
  }

  double _bubbleLeftOffset(double screenWidth) {
    final double idealLeft = (_petSize - _bubbleMaxWidth) / 2;
    final double minLeft = -_position.dx;
    final double maxLeft = screenWidth - _position.dx - _bubbleMaxWidth;
    return idealLeft.clamp(minLeft, maxLeft);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _species.isEmpty) return const SizedBox.shrink();

    final Size screenSize = MediaQuery.of(context).size;
    final EdgeInsets safePadding = MediaQuery.of(context).padding;
    final double bottomBarHeight = 85.0 + safePadding.bottom;

    final Widget petAvatar = Container(
      width: _petSize,
      height: _petSize,
      decoration: BoxDecoration(
        color: const Color(0xFFECEEEA),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF0F5238), width: 2),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 4))
        ],
      ),
      child: Center(
        child: Image.asset(
          _gifPath,
          width: 45,
          height: 45,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.none,
        ),
      ),
    );

   if (!showFloatingPet.value) return const SizedBox.shrink();

      return SizedBox(
        width: screenSize.width,
        height: screenSize.height,
        child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: _position.dx,
            top: _position.dy,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque, 
              onPanUpdate: (details) {
                if (_snapController.isAnimating) {
                  _snapController.stop();
                }

                setState(() {
                  double newX = _position.dx + details.delta.dx;
                  double newY = _position.dy + details.delta.dy;
                  
                  newY = newY.clamp(safePadding.top, screenSize.height - bottomBarHeight - _petSize);
                  newX = newX.clamp(0.0, screenSize.width - _petSize);
                  
                  _position = Offset(newX, newY);
                });
              },
              
              onPanEnd: (details) {
                final double leftEdgeDist = _position.dx;
                final double rightEdgeDist = screenSize.width - _petSize - _position.dx;
                
                final double targetX = leftEdgeDist < rightEdgeDist 
                    ? _edgeMargin 
                    : (screenSize.width - _petSize - _edgeMargin);
                
                _snapAnimation = Tween<Offset>(
                  begin: _position,
                  end: Offset(targetX, _position.dy),
                ).animate(CurvedAnimation(
                  parent: _snapController, 
                  curve: Curves.easeOutCubic,
                ));
                
                _snapController.forward(from: 0.0);
              },
              onTap: _triggerSavingsTip, 
              child: SizedBox(
                width: _petSize,
                height: _petSize,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    petAvatar,
                    if (_message != null)
                      Positioned(
                        bottom: _petSize + 8, 
                        left: _bubbleLeftOffset(screenSize.width),
                        width: _bubbleMaxWidth,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.95),
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(16),
                              topRight: Radius.circular(16),
                              bottomLeft: Radius.circular(16),
                              bottomRight: Radius.circular(4),
                            ),
                            border: Border.all(color: const Color(0xFF0F5238).withOpacity(0.2)),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 4))],
                          ),
                          child: Text(
                            _message!,
                            style: const TextStyle(color: Color(0xFF0F5238), fontWeight: FontWeight.bold, fontSize: 13),
                            textAlign: TextAlign.center,
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
    );
  }
}