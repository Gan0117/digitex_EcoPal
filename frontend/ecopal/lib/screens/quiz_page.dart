import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';
// 用 alias 引入真正的 ApiService，只用来拿 pet 的 species/level
import '../services/api_service.dart' as real_api;
import 'pet_room_page.dart';

// ── 1. ApiService placed at the very top ───────────────────────────
class ApiService {
  static Future<void> feedPet() async {
    try {
      // TODO: Replace with actual FastAPI / Supabase logic for EcoPal later
      print("Pet feeding request sent successfully.");
    } catch (e) {
      print("Failed to feed pet: $e");
    }
  }
}

// ── 2. Your QuizPage starts here ───────────────────────────────────
class QuizPage extends StatefulWidget {
  const QuizPage({super.key});

  @override
  State<QuizPage> createState() => _QuizPageState();
}

enum _QuizStage { start, loading, question, feedback, result }

class _QuizPageState extends State<QuizPage> {
  _QuizStage _stage = _QuizStage.start;
  List<dynamic> _questions = [];
  int _currentIndex = 0;
  int _score = 0;
  int? _selectedIndex;
  bool _isCorrect = false;
  Timer? _timer;
  int _timeLeft = 15;
  static const int _questionTime = 15;
  static const int _numberOfQuestions = 5;

  final List<Color> _optionColors = [
    const Color(0xFFE21B3C),
    const Color(0xFF1368CE),
    const Color(0xFFD89E00),
    const Color(0xFF26890C),
  ];

  // ── Pet info for the result screen ──────────────────────────
  String _petSpecies = 'Tabby';
  int _petLevel = 1;

  Future<void> _loadPetInfo() async {
    try {
      final petData = await real_api.ApiService.getPetStatus();
      if (mounted) {
        setState(() {
          _petSpecies = petData['species'] ?? 'Tabby';
          _petLevel = petData['level'] ?? 1;
        });
      }
    } catch (e) {
      debugPrint('Failed to load pet info: $e');
    }
  }

  String get _petSleepGif {
    final species = _petSpecies.toLowerCase();
    final folder2 = _petLevel <= 3 ? 'kitten' : 'cat';
    final prefix = species == 'tabby'
        ? (_petLevel <= 3 ? 'kit_' : 'cat_')
        : (_petLevel <= 3 ? 'orkt_' : 'org_');
    return 'widgets/$species/$folder2/${prefix}sleep.gif';
  }

  // ── Daily limit state ────────────────────────────────────────
  bool _canPlayToday = true;
  Duration _timeUntilNextQuiz = Duration.zero;
  Timer? _countdownTimer;

  Future<void> _checkDailyStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final lastPlayedStr = prefs.getString('quiz_last_played');
    if (lastPlayedStr != null) {
      final lastPlayed = DateTime.parse(lastPlayedStr);
      final now = DateTime.now();
      final isSameDay = lastPlayed.year == now.year &&
          lastPlayed.month == now.month &&
          lastPlayed.day == now.day;
      if (isSameDay) {
        setState(() => _canPlayToday = false);
        _startCountdown();
      }
    }
  }

  void _startCountdown() {
    _updateCountdown();
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateCountdown();
    });
  }

  void _updateCountdown() {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final diff = tomorrow.difference(now);
    if (!mounted) return;
    if (diff.isNegative) {
      setState(() {
        _canPlayToday = true;
        _timeUntilNextQuiz = Duration.zero;
      });
      _countdownTimer?.cancel();
    } else {
      setState(() => _timeUntilNextQuiz = diff);
    }
  }

  Future<void> _markPlayedToday() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('quiz_last_played', DateTime.now().toIso8601String());
  }

  String _formatDuration(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  void initState() {
    super.initState();
    _checkDailyStatus();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadQuestions() async {
    if (!_canPlayToday) return; // 防止重复点击
    setState(() => _stage = _QuizStage.loading);
    _loadPetInfo(); // 提前拉取 pet 信息，给结果页用
    await _markPlayedToday();
    if (mounted) setState(() => _canPlayToday = false);

    final data = await rootBundle.loadString('assets/backend/data/quiz.json');
    final List<dynamic> all = json.decode(data);
    all.shuffle();
    setState(() {
      _questions = all.take(_numberOfQuestions).toList();
      _currentIndex = 0;
      _score = 0;
      _selectedIndex = null;
      _stage = _QuizStage.question;
    });
    _startTimer();
  }

  void _startTimer() {
    _timeLeft = _questionTime;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        _timeLeft--;
        if (_timeLeft <= 0) {
          timer.cancel();
          if (_selectedIndex == null) _selectAnswer(-1);
        }
      });
    });
  }

  void _selectAnswer(int index) {
    if (_selectedIndex != null) return;
    _timer?.cancel();
    final correctIndex = _questions[_currentIndex]['correct_index'] as int;
    final correct = index == correctIndex;
    setState(() {
      _selectedIndex = index;
      _isCorrect = correct;
      if (correct) _score++;
      _stage = _QuizStage.feedback;
    });

    Future.delayed(const Duration(seconds: 2), _nextQuestion);
  }

  void _nextQuestion() {
    if (!mounted) return;
    if (_currentIndex < _questions.length - 1) {
      setState(() {
        _currentIndex++;
        _selectedIndex = null;
        _stage = _QuizStage.question;
      });
      _startTimer();
    } else {
      setState(() => _stage = _QuizStage.result);
    }
  }

  Future<void> _feedPet() async {
    try {
      // This will now successfully call the ApiService class at the top of this file
      await ApiService.feedPet();
    } catch (e) {
      debugPrint('Failed to feed pet: $e');
    }
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const PetRoomPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: SafeArea(
        child: switch (_stage) {
          _QuizStage.start => _buildStart(),
          _QuizStage.loading =>
              const Center(child: CircularProgressIndicator(color: Color(0xFF4CAF50))),
          _QuizStage.question => _buildQuestion(),
          _QuizStage.feedback => _buildFeedback(),
          _QuizStage.result => _buildResult(),
        },
      ),
    );
  }

  // ── Start screen ──────────────────────────────────────────────
  Widget _buildStart() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('widgets/dashboard/quiz.png', width: 120, height: 120),
            const SizedBox(height: 24),
            const Text('Eco Finance Quiz',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Colors.black87)),
            const SizedBox(height: 12),
            const Text('Ready to test your money-saving knowledge?',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.black54)),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _canPlayToday ? _loadQuestions : null,
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    _canPlayToday ? const Color(0xFF4CAF50) : Colors.grey.shade400,
                disabledBackgroundColor: Colors.grey.shade400,
                padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              child: const Text('Start Quiz',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            if (!_canPlayToday) ...[
              const SizedBox(height: 12),
              Text(
                'Come back in ${_formatDuration(_timeUntilNextQuiz)}',
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black54),
              ),
            ],
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Back', style: TextStyle(color: Colors.black54)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Question screen ───────────────────────────────────────────
  Widget _buildQuestion() {
    final q = _questions[_currentIndex];
    final options = List<String>.from(q['options']);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Question ${_currentIndex + 1}/${_questions.length}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.black87)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _timeLeft <= 5
                      ? Colors.redAccent
                      : const Color(0xFF4CAF50),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('$_timeLeft',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF0F5238),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(q['question'],
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(height: 24),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 2.2,
              ),
              itemCount: options.length,
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap: () => _selectAnswer(index),
                  child: Container(
                    decoration: BoxDecoration(
                      color: _optionColors[index % 4],
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.all(12),
                    alignment: Alignment.center,
                    child: Text(options[index],
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14)),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  // ── Feedback (correct / wrong) screen ───────────────────────────
  Widget _buildFeedback() {
    final q = _questions[_currentIndex];
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _isCorrect ? Icons.check_circle : Icons.cancel,
              color: _isCorrect ? const Color(0xFF4CAF50) : Colors.redAccent,
              size: 80,
            ),
            const SizedBox(height: 16),
            Text(_isCorrect ? 'Correct!' : 'Oops!',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: _isCorrect ? const Color(0xFF4CAF50) : Colors.redAccent)),
            const SizedBox(height: 12),
            Text(q['explanation'],
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: Colors.black54)),
          ],
        ),
      ),
    );
  }

  // ── Result screen ────────────────────────────────────────────
  Widget _buildResult() {
  final int pointsEarned = _score * 10;
  final bool hasPoints = _score > 0;

  return Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Quiz Complete!',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Colors.black87)),
          const SizedBox(height: 12),
          Text('You scored $_score / ${_questions.length}',
              style: const TextStyle(fontSize: 18, color: Colors.black54)),
          const SizedBox(height: 24),
          ClipRect(
            child: SizedBox(
              width: 140,
              height: 140,
              child: Transform.scale(
                scale: 2.0,
                child: Image.asset(
                  _petSleepGif,
                  filterQuality: FilterQuality.none,
                  gaplessPlayback: true,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Points / encouragement message
          if (hasPoints)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF4CAF50).withOpacity(0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.stars_rounded, color: Colors.amber, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'You earned $pointsEarned reward points!',
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2E7D32)),
                  ),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.orange.withOpacity(0.4)),
              ),
              child: const Text(
                "Don't give up! Every quiz makes you smarter. Try again tomorrow! 💪",
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFE65100)),
              ),
            ),
          const SizedBox(height: 16),
          if (hasPoints) ...[
            const Text('Feed your pet as a reward!',
                style: TextStyle(fontSize: 14, color: Colors.black54)),
            const SizedBox(height: 16),
          ],
          // Buttons
          if (hasPoints)
            // Only show Back button, styled green like the old Yes button
            SizedBox(
              width: 160,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30)),
                ),
                child: const Text('Back',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            )
          else
          SizedBox(
            width: 160,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30)),
              ),
              child: const Text('Back',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    ),
  );
}
}