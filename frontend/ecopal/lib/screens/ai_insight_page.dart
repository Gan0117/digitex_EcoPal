import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:fl_chart/fl_chart.dart'; 
import '../services/api_service.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/floating_pet.dart';

class AiInsightPage extends StatefulWidget {
  const AiInsightPage({super.key});

  @override
  State<AiInsightPage> createState() => _AiInsightPageState();
}

class _AiInsightPageState extends State<AiInsightPage> {
  bool _isLoading = true;

  // Data States
  double _safeToSpend = 0.0;
  List<dynamic> _transactions = [];
  
  // AI Insights States
  String _realityCheckMsg = 'Loading prediction...';
  String _behaviorMsg = 'Analyzing recent spending...';
  String _grade = 'Healthy'; 
  
  // Habit Tax States
  String _habitTaxId = '';
  double _habitTaxAmount = 0.0;
  bool _isHabitTaxEnabled = false;

  // UI Filters
  String _timeFilter = 'M'; // 'D' (Daily), 'M' (Monthly), 'Y' (Yearly)

  // Theme Colors
  final Color primaryColor = const Color(0xFF0F5238);
  final Color secondaryColor = const Color(0xFF006C48);
  final Color outlineVariant = const Color(0xFFBFC9C1);
  final Color habitTaxGold = const Color(0xFFD4AF37);
  final Color alertDanger = const Color(0xFFEF4444);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showFloatingPet.value = true;
    });
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    try {
      final results = await Future.wait([
        ApiService.getSafeToSpendBalance(),
        ApiService.getTransactions(),
        ApiService.getRealityCheck(),
        ApiService.getBehaviorAnalysis(),
        ApiService.getHabitTax(), 
      ]);

      if (mounted) {
        setState(() {
          _safeToSpend = results[0] as double;
          _transactions = results[1] as List<dynamic>;
          _realityCheckMsg = results[2] as String;
          _behaviorMsg = results[3] as String;
          
          final habitTaxData = results[4] as Map<String, dynamic>;
          _habitTaxId = habitTaxData['id'] ?? '';
          _habitTaxAmount = (habitTaxData['amount'] ?? 0.0).toDouble();
          _isHabitTaxEnabled = habitTaxData['available'] ?? false;

          String lowerMsg = _realityCheckMsg.toLowerCase();
          if (lowerMsg.contains('unhealthy') || lowerMsg.contains('debt') || lowerMsg.contains('warning')) {
            _grade = 'Unhealthy';
          } else if (lowerMsg.contains('moderate') || lowerMsg.contains('careful')) {
            _grade = 'Moderate';
          } else {
            _grade = 'Healthy';
          }

          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to load AI insights.')));
      }
    }
  }

  Future<void> _toggleHabitTax(bool newValue) async {
    setState(() => _isHabitTaxEnabled = newValue);
    try {
      await ApiService.updateHabitTax(newValue);
    } catch (e) {
      setState(() => _isHabitTaxEnabled = !newValue);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to update Habit Tax settings.')));
    }
  }

  Map<String, dynamic> _getGradeStyle() {
    if (_grade == 'Healthy') return {'icon': Icons.eco, 'color': secondaryColor, 'bg': const Color(0xFF92F7C3).withOpacity(0.3), 'text': 'HEALTHY'};
    if (_grade == 'Moderate') return {'icon': Icons.balance, 'color': habitTaxGold, 'bg': habitTaxGold.withOpacity(0.2), 'text': 'MODERATE'};
    return {'icon': Icons.warning_amber_rounded, 'color': alertDanger, 'bg': alertDanger.withOpacity(0.2), 'text': 'UNHEALTHY'};
  }

  // --- 🔥 Goal 1: Dynamic Chart Data Generator based on Time Filter ---
  List<FlSpot> _generateChartData() {
    if (_transactions.isEmpty) return [const FlSpot(0, 0), const FlSpot(1, 0)];

    // Filter to expenses only for spending trends
    final expenses = _transactions.where((tx) {
      final type = tx['type']?.toString().toLowerCase();
      return type == 'expense' || type == null;
    }).toList();

    Map<int, double> groupedData = {};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (_timeFilter == 'D') {
      // Last 7 days
      for (int i = 0; i < 7; i++) groupedData[i] = 0.0;
      
      for (var tx in expenses) {
        String? dateStr = tx['created_at'] ?? tx['date'];
        if (dateStr != null) {
          DateTime date = DateTime.parse(dateStr).toLocal();
          DateTime txDay = DateTime(date.year, date.month, date.day);
          int diff = today.difference(txDay).inDays;
          
          if (diff >= 0 && diff < 7) {
            int index = 6 - diff; // 6 is today, 0 is 6 days ago
            groupedData[index] = (groupedData[index] ?? 0) + (tx['amount'] as num).toDouble();
          }
        }
      }
    } else if (_timeFilter == 'M') {
      // Last 6 months
      for (int i = 0; i < 6; i++) groupedData[i] = 0.0;

      for (var tx in expenses) {
        String? dateStr = tx['created_at'] ?? tx['date'];
        if (dateStr != null) {
          DateTime date = DateTime.parse(dateStr).toLocal();
          int monthDiff = (now.year - date.year) * 12 + now.month - date.month;
          
          if (monthDiff >= 0 && monthDiff < 6) {
            int index = 5 - monthDiff; // 5 is current month, 0 is 5 months ago
            groupedData[index] = (groupedData[index] ?? 0) + (tx['amount'] as num).toDouble();
          }
        }
      }
    } else if (_timeFilter == 'Y') {
      // Last 4 years
      for (int i = 0; i < 4; i++) groupedData[i] = 0.0;

      for (var tx in expenses) {
        String? dateStr = tx['created_at'] ?? tx['date'];
        if (dateStr != null) {
          DateTime date = DateTime.parse(dateStr).toLocal();
          int yearDiff = now.year - date.year;
          
          if (yearDiff >= 0 && yearDiff < 4) {
            int index = 3 - yearDiff; // 3 is current year, 0 is 3 years ago
            groupedData[index] = (groupedData[index] ?? 0) + (tx['amount'] as num).toDouble();
          }
        }
      }
    }

    List<FlSpot> spots = [];
    groupedData.forEach((key, value) {
      spots.add(FlSpot(key.toDouble(), value));
    });
    
    spots.sort((a, b) => a.x.compareTo(b.x));
    return spots;
  }

  @override
  Widget build(BuildContext context) {
    final gradeStyle = _getGradeStyle();
    final bool isHabitUnlocked = _grade == 'Healthy';

    return Scaffold(
      extendBody: true,
      backgroundColor: const Color(0xFFF8FAF6),
      bottomNavigationBar: const EcoPalBottomBar(currentIndex: 3), 
      body: _isLoading
        ? Center(child: CircularProgressIndicator(color: primaryColor))
        : Stack(
            children: [
              SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(left: 24, right: 24, top: 24, bottom: 100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Image.asset(
                            'widgets/badges/gold_badge.png',
                            width: 32,
                            height: 32,
                            fit: BoxFit.contain,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Ecopal',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: Colors.black87,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const Text('AI Insights', style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.black87)),
                      const SizedBox(height: 4),
                      Text('Your personal financial ecosystem analysis.', style: TextStyle(fontSize: 16, color: Colors.grey.shade800)),
                      const SizedBox(height: 32),

                      // ==========================================
                      // 1. BEHAVIOR ANALYSIS (Chart Section)
                      // ==========================================
                      _buildGlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Behavior Analysis', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: primaryColor)),
                                    Text('Evaluating historical patterns.', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                                  ],
                                ),
                                // D / M / Y Toggle
                                Container(
                                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.5), borderRadius: BorderRadius.circular(8)),
                                  child: Row(
                                    children: ['D', 'M', 'Y'].map((filter) {
                                      bool isActive = _timeFilter == filter;
                                      return GestureDetector(
                                        onTap: () => setState(() => _timeFilter = filter),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: isActive ? primaryColor : Colors.transparent,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(filter, style: TextStyle(color: isActive ? Colors.white : Colors.grey.shade800, fontWeight: FontWeight.bold)),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                )
                              ],
                            ),
                            const SizedBox(height: 24),

                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 80, height: 80,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: gradeStyle['color'], width: 4),
                                    boxShadow: [BoxShadow(color: gradeStyle['color'].withOpacity(0.2), blurRadius: 10)],
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(gradeStyle['icon'], size: 32, color: gradeStyle['color']),
                                      const SizedBox(height: 4),
                                      Text(gradeStyle['text'], style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: gradeStyle['color'], letterSpacing: 0.5)),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.7),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border(left: BorderSide(color: primaryColor, width: 4)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(Icons.auto_awesome, size: 16, color: primaryColor),
                                            const SizedBox(width: 4),
                                            Text('AI Suggestion', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: primaryColor)),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(_behaviorMsg, style: TextStyle(fontSize: 13, color: Colors.grey.shade800, height: 1.4)),
                                      ],
                                    ),
                                  ),
                                )
                              ],
                            ),
                            const SizedBox(height: 32),

                            Text('Total Spending vs Time', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
                            const SizedBox(height: 16),
                            SizedBox(
                              height: 180,
                              child: LineChart(
                                LineChartData(
                                  minY: 0,
                                  minX: 0,
                                  maxX: _timeFilter == 'D' ? 6 : (_timeFilter == 'M' ? 5 : 3),
                                  gridData: FlGridData(show: false),
                                  titlesData: FlTitlesData(
                                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                    bottomTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        interval: 1,
                                        getTitlesWidget: (value, meta) {
                                          int index = value.toInt();
                                          String text = '';
                                          final now = DateTime.now();

                                          if (_timeFilter == 'D') {
                                            if (index >= 0 && index <= 6) {
                                              int daysAgo = 6 - index;
                                              DateTime d = now.subtract(Duration(days: daysAgo));
                                              text = '${d.day}/${d.month}';
                                            }
                                          } else if (_timeFilter == 'M') {
                                            if (index >= 0 && index <= 5) {
                                              int monthsAgo = 5 - index;
                                              int targetMonth = now.month - monthsAgo;
                                              while (targetMonth <= 0) targetMonth += 12; // Handle year wrap
                                              
                                              List<String> months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
                                              text = months[targetMonth - 1];
                                            }
                                          } else if (_timeFilter == 'Y') {
                                            if (index >= 0 && index <= 3) {
                                              int yearsAgo = 3 - index;
                                              text = '${now.year - yearsAgo}';
                                            }
                                          }

                                          return Padding(
                                            padding: const EdgeInsets.only(top: 8.0),
                                            child: Text(text, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                  borderData: FlBorderData(show: true, border: Border(bottom: BorderSide(color: outlineVariant), left: BorderSide(color: outlineVariant))),
                                  lineBarsData: [
                                    LineChartBarData(
                                      spots: _generateChartData(),
                                      isCurved: false, 
                                      color: secondaryColor,
                                      barWidth: 3,
                                      isStrokeCapRound: true,
                                      dotData: FlDotData(show: true), 
                                      belowBarData: BarAreaData(
                                        show: true,
                                        color: secondaryColor.withOpacity(0.2),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ==========================================
                      // 2. REALITY-CHECK PREDICTOR
                      // ==========================================
                      _buildGlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Reality-Check Predictor', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                                    Text('Forecasts based on trajectory.', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(color: gradeStyle['bg'], borderRadius: BorderRadius.circular(100)),
                                  child: Row(
                                    children: [
                                      Icon(gradeStyle['icon'], size: 14, color: gradeStyle['color']),
                                      const SizedBox(width: 4),
                                      Text('Risk: ${_grade == 'Healthy' ? 'Low' : (_grade == 'Moderate' ? 'Medium' : 'High')}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: gradeStyle['color'])),
                                    ],
                                  ),
                                )
                              ],
                            ),
                            const SizedBox(height: 24),

                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.7), borderRadius: BorderRadius.circular(16)),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Safe to Spend Balance', style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 4),
                                        Text('RM ${_safeToSpend.toStringAsFixed(2)}', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: primaryColor)),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.7), borderRadius: BorderRadius.circular(16)),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('3-Month Forecast', style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 4),
                                        Text(_realityCheckMsg, style: const TextStyle(fontSize: 12, color: Colors.black87, height: 1.3)),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ==========================================
                      // 3. HABIT TAX (Habit Tabung)
                      // ==========================================
                      _buildGlassCard(
                        padding: const EdgeInsets.all(0), 
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: habitTaxGold.withOpacity(0.5), width: 2),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(color: habitTaxGold.withOpacity(0.2), shape: BoxShape.circle),
                                        child: Icon(Icons.savings, color: habitTaxGold, size: 24),
                                      ),
                                      const SizedBox(width: 12),
                                      const Text('Habit Tax', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
                                    ],
                                  ),
                                  Switch(
                                    value: _isHabitTaxEnabled,
                                    activeColor: habitTaxGold,
                                    onChanged: _toggleHabitTax,
                                  ),
                                ],
                              ),
                              
                              AnimatedSize(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                                child: _isHabitTaxEnabled 
                                  ? Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const SizedBox(height: 12),
                                        Text('Auto-saves RM1 per entertainment spend into a locked "Habit Tabung".', style: TextStyle(fontSize: 13, color: Colors.grey.shade800)),
                                        const SizedBox(height: 24),
                                        
                                        Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.symmetric(vertical: 20),
                                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.8), borderRadius: BorderRadius.circular(16), border: Border.all(color: outlineVariant.withOpacity(0.3))),
                                          child: Column(
                                            children: [
                                              const Text('ACCUMULATED SAVINGS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.5)),
                                              const SizedBox(height: 4),
                                              Text('RM ${_habitTaxAmount.toStringAsFixed(2)}', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: habitTaxGold)),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 16),

                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.5), borderRadius: BorderRadius.circular(12)),
                                          child: Row(
                                            children: [
                                              Icon(isHabitUnlocked ? Icons.lock_open : Icons.lock, color: isHabitUnlocked ? secondaryColor : Colors.grey.shade600, size: 20),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Text(
                                                  isHabitUnlocked 
                                                    ? 'Your habits are Healthy! You can now withdraw these funds.' 
                                                    : 'Maintain a "Healthy" grade to unlock these funds.', 
                                                  style: TextStyle(fontSize: 12, color: isHabitUnlocked ? secondaryColor : Colors.grey.shade800, fontWeight: FontWeight.w600)
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),

                                        if (isHabitUnlocked) ...[
                                          const SizedBox(height: 16),
                                          SizedBox(
                                            width: double.infinity,
                                            height: 48,
                                            child: ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: habitTaxGold,
                                                foregroundColor: Colors.white,
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                              ),
                                              onPressed: () {
                                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Withdrawal request initiated!')));
                                              },
                                              child: const Text('Withdraw Funds', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                            ),
                                          ),
                                        ]
                                      ],
                                    )
                                  : const SizedBox.shrink(),
                              )
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
    );
  }

 Widget _buildGlassCard({required Widget child, EdgeInsetsGeometry padding = const EdgeInsets.all(24)}) {
  return Container(
    padding: padding,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 10,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: child,
  );
}
}