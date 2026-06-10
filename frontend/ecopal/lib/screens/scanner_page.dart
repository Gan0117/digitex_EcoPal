import 'package:flutter/material.dart';
import 'dart:ui'; 
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart'; 
import '../services/api_service.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/floating_pet.dart';


class ScannerPage extends StatefulWidget {
  const ScannerPage({super.key});

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  List<dynamic> _transactions = [];

  String _latestGrade = 'N/A'; 
  String _latestComment = 'In developing...';

  // Manual Entry State
  bool _isManualExpanded = false;
  String _selectedCategory = 'Food';
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _timeController = TextEditingController();
  
  // Custom category and description
  final TextEditingController _customCategoryController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  // Theme Colors
  final Color primaryColor = const Color(0xFF0F5238);
  final Color secondaryColor = const Color(0xFF006C48);
  final Color surfaceSoil = const Color(0xFFFDFCF8);
  final Color outlineVariant = const Color(0xFFBFC9C1);
  final Color habitTaxGold = const Color(0xFFD4AF37);
  final Color alertDanger = const Color(0xFFEF4444);

  final List<String> _categories = ['Food', 'Groceries', 'Utilities', 'Entertainment', 'Transport', 'Add Money', 'Other'];

  @override
  void initState() {
    super.initState();
    _loadData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showFloatingPet.value = true;
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _timeController.dispose();
    _customCategoryController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final txData = await ApiService.getTransactions();
      if (mounted) {
        setState(() {
          _transactions = txData.reversed.toList(); 
        });
        
        await _fetchAIAnalysis();
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchAIAnalysis() async {
    try {
      final insight = await ApiService.getRealityCheck();
      if (mounted) {
        setState(() {
          if (insight.isNotEmpty) {
            _latestComment = insight;
            _latestGrade = insight.toLowerCase().contains('unhealthy') ? 'Unhealthy' 
                         : insight.toLowerCase().contains('moderate') ? 'Moderate' 
                         : 'Healthy';
          } else {
            _latestComment = 'In developing...';
            _latestGrade = 'N/A';
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _latestComment = 'In developing...';
          _latestGrade = 'N/A';
          _isLoading = false;
        });
      }
    }
  }

  void _showConfirmationDialog(Map<String, dynamic> txData) {
    final isIncome = txData['type'] == 'income';
    bool isSaving = false; 
    
    showDialog(
      context: context,
      barrierDismissible: false, 
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white.withOpacity(0.95),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text('Confirm Details', style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Record Type: ${isIncome ? 'Income (Add Money)' : 'Expense'}', style: const TextStyle(fontSize: 16)),
                  const SizedBox(height: 8),
                  Text('Category: ${txData['category']}', style: const TextStyle(fontSize: 16)),
                  const SizedBox(height: 8),
                  Text('Amount: \$${txData['amount'].toStringAsFixed(2)}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isIncome ? secondaryColor : Colors.black87)),
                  const SizedBox(height: 8),
                  Text('Note: ${txData['description']}', style: const TextStyle(fontSize: 14, color: Colors.grey)),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(context),
                  child: const Text('Cancel / Edit', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white),
                  onPressed: isSaving 
                      ? null 
                      : () async {
                          setDialogState(() => isSaving = true);
                          Navigator.pop(context);
                          await _submitToBackend(txData);
                        },
                  child: isSaving 
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Save Record'),
                ),
              ],
            );
          }
        );
      },
    );
  }

  // 🔥 Goal 1: Compute points locally and update Profile via API
  Future<void> _submitToBackend(Map<String, dynamic> txData) async {
    setState(() => _isLoading = true);
    
    // 1. Calculate Reward Points locally
    int pointsEarned = 0;
    final category = txData['category']?.toString().toLowerCase() ?? '';
    if (category  == 'food' || category == 'groceries' || category == 'utilities' || category == 'bills' || category == 'transport') {
      pointsEarned = 15;
    } else if (category == 'other'){
      pointsEarned = 5;
    } else if (category == 'add money') {
      pointsEarned = 20;
    } else {
      pointsEarned = 0;
    }
    
    try {
      // 2. Post the Transaction 
      await ApiService.postTransaction(txData);
      
      // 3. Update Profile Reward Points if points were earned
      if (pointsEarned > 0) {
        final profile = await ApiService.getProfile();
        final currentPoints = (profile['reward_points'] as num?)?.toInt() ?? 0;
        await ApiService.updateProfile({'reward_points': currentPoints + pointsEarned});
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to save transaction.')));
      return;
    }

    // 4. Update the UI
    setState(() {
      _transactions.insert(0, {
        "id": "tx-${DateTime.now().millisecondsSinceEpoch}",
        ...txData,
      });
      
      _amountController.clear();
      _timeController.clear();
      _customCategoryController.clear();
      _descriptionController.clear();
      _isManualExpanded = false;
    });
    
    await _fetchAIAnalysis();
    
    if (mounted) {
      _showRewardSnackBar(pointsEarned);
      if (pointsEarned > 0) {
        // Trigger pet celebration
        rewardPointsEarnedNotifier.value = 0; 
        rewardPointsEarnedNotifier.value = pointsEarned;
      }
    }
  }

  void _showRewardSnackBar(int points) {
    final bool hasPoints = points > 0;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              hasPoints ? Icons.stars_rounded : Icons.check_circle_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                hasPoints
                    ? 'Record saved!  +$points reward points earned ✨'
                    : 'Record saved. No points for this category.',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: hasPoints ? const Color(0xFF006C48) : Colors.grey.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _verifyManualRecord() {
    final double? amount = double.tryParse(_amountController.text);
    if (amount != null && amount > 0) {
      
      String finalCategory = _selectedCategory;
      String txType = 'expense';
      
      if (_selectedCategory == 'Add Money') {
        txType = 'income';
      } else if (_selectedCategory == 'Other') {
        finalCategory = _customCategoryController.text.trim();
        if (finalCategory.isEmpty) {
          finalCategory = 'Other';
        }
      }

      String finalDescription = _descriptionController.text.trim();

      _showConfirmationDialog({
        "category": finalCategory,
        "amount": amount,
        "description": finalDescription,
        "type": txType,
        "created_at": DateTime.now().toIso8601String()
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a valid amount.')));
    }
  }

 Future<void> _handleScanReceipt() async {
  try {
    FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
      withData: true,
    );

    if (result != null) {
      String fileName = result.files.single.name;
      final bytes = result.files.single.bytes;

      if (bytes != null) {
        _showScanningProgressWeb(fileName, bytes);
      } else if (result.files.single.path != null) {
        _showScanningProgress(fileName, result.files.single.path!);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to read file. Please try again.')),
        );
      }
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Failed to pick file: $e')),
    );
  }
}

  Future<void> _showScanningProgress(String fileName, String filePath) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white.withOpacity(0.9),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: primaryColor),
              const SizedBox(height: 16),
              const Text('Scanning Receipt...', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Analyzing $fileName...', style: TextStyle(color: Colors.grey.shade600, fontSize: 12), textAlign: TextAlign.center,),
            ],
          ),
        );
      },
    );

    try {
      final result = await ApiService.scanReceipt(filePath); 
      final extractedData = result["scanned_data"];

      if (mounted) {
        Navigator.pop(context); 
        
        _showConfirmationDialog({
          "category": extractedData["category"] ?? "Unknown", 
          "amount": (extractedData["amount"] as num?)?.toDouble() ?? 0.0,
          "description": extractedData["title"] ?? "Extracted from: $fileName",
          "type": "expense", 
          "created_at": DateTime.now().toIso8601String()
        });
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); 
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _showScanningProgressWeb(String fileName, Uint8List bytes) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white.withOpacity(0.9),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: primaryColor),
              const SizedBox(height: 16),
              const Text('Scanning Receipt...', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Analyzing $fileName...', style: TextStyle(color: Colors.grey.shade600, fontSize: 12), textAlign: TextAlign.center),
            ],
          ),
        );
      },
    );

    try {
      final result = await ApiService.scanReceiptWeb(fileName, bytes);
      final extractedData = result["scanned_data"];

      if (mounted) {
        Navigator.pop(context);
        _showConfirmationDialog({
          "category": extractedData["category"] ?? "Unknown",
          "amount": (extractedData["amount"] as num?)?.toDouble() ?? 0.0,
          "description": extractedData["title"] ?? "Extracted from: $fileName",
          "type": "expense",
          "created_at": DateTime.now().toIso8601String()
        });
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to analyze receipt: $e')),
        );
      }
    }
  }

  void _showAllRecordsTab() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        String filterTime = 'All Time'; 
        String filterCategory = 'All'; 

        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) {
            
            List<dynamic> filteredList = _transactions.where((tx) {
              bool isIncome = (tx['type'] ?? '') == 'income';
              
              bool matchCat = false;
              if (filterCategory == 'All') {
                matchCat = true;
              } else if (filterCategory == 'Add Money') {
                matchCat = isIncome || tx['category'] == 'Add Money';
              } else {
                matchCat = tx['category'] == filterCategory;
              }

              bool matchTime = true;
              DateTime txDate = DateTime.parse(tx['created_at']);
              DateTime now = DateTime.now();
              if (filterTime == 'This Week') {
                matchTime = now.difference(txDate).inDays <= 7;
              } else if (filterTime == 'This Month') {
                matchTime = now.difference(txDate).inDays <= 30;
              }
              return matchCat && matchTime;
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Color(0xFFFDFCF8), 
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('All Records', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: primaryColor)),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: filterTime,
                          decoration: _inputDecoration(),
                          items: ['All Time', 'This Week', 'This Month'].map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 13)))).toList(),
                          onChanged: (val) => setSheetState(() => filterTime = val!),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: filterCategory,
                          decoration: _inputDecoration(),
                          items: ['All', ..._categories].map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 13)))).toList(),
                          onChanged: (val) => setSheetState(() => filterCategory = val!),
                        ),
                      ),
                    ],
                  ),
                  const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider()),
                  
                  Expanded(
                    child: filteredList.isEmpty
                      ? Center(child: Text("No records match your filters.", style: TextStyle(color: Colors.grey.shade600)))
                      : ListView.separated(
                          itemCount: filteredList.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final tx = filteredList[index];
                            final amount = (tx['amount'] ?? 0.0).toDouble();
                            final bool isIncome = (tx['type'] ?? '') == 'income';

                            String txGrade = amount > 100 ? 'Unhealthy' : (amount > 50 ? 'Moderate' : 'Healthy');
                            final style = isIncome
                                ? {'icon': Icons.add_circle, 'color': const Color(0xFF006C48), 'bg': const Color(0xFF92F7C3).withOpacity(0.3)}
                                : _getGradeStyle(txGrade);

                            return GestureDetector(
                              onTap: () => _showTransactionDetails(tx),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: outlineVariant.withOpacity(0.5))),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 40, height: 40,
                                      decoration: BoxDecoration(color: style['bg'], borderRadius: BorderRadius.circular(8)),
                                      child: Center(child: Icon(style['icon'], color: style['color'], size: 20)),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(tx['category'] ?? 'Record', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                          Text(tx['created_at'].toString().split('T').first, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      isIncome ? '+\$${amount.toStringAsFixed(2)}' : '\$${amount.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: isIncome ? const Color(0xFF006C48) : Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showTransactionDetails(Map<String, dynamic> tx) {
    final double amount = (tx['amount'] ?? 0.0).toDouble();
    final bool isIncome = (tx['type'] ?? '') == 'income';
    
    String grade = 'Healthy';
    if (!isIncome) {
      if (amount > 100) grade = 'Unhealthy';
      else if (amount > 50) grade = 'Moderate';
    }
    
    final style = isIncome
        ? {'icon': Icons.add_circle, 'color': const Color(0xFF006C48), 'bg': const Color(0xFF92F7C3).withOpacity(0.3)}
        : _getGradeStyle(grade);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(tx['category'] ?? 'Unknown', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  Text(
                    isIncome ? '+\$${amount.toStringAsFixed(2)}' : '\$${amount.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: isIncome ? const Color(0xFF006C48) : primaryColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(tx['description']?.toString().isNotEmpty == true ? tx['description'] : 'No description', style: TextStyle(color: Colors.grey.shade600)),
              const SizedBox(height: 4),
              Text('Date: ${tx['created_at'].toString().split('T').first}', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
              const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider()),
              
              const Row(
                children: [
                  Icon(Icons.auto_awesome, color: Colors.amber),
                  SizedBox(width: 8),
                  Text('AI Analysis', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xFFF1F3E9), borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(color: style['bg'], borderRadius: BorderRadius.circular(100)),
                      child: Text(
                        isIncome ? 'INCOME' : grade.toUpperCase(),
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: style['color']),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(
                      isIncome
                          ? 'This is an income entry added to your Main Account.'
                          : 'This transaction was logged as $grade for your current spending cycle.',
                      style: const TextStyle(fontSize: 12),
                    )),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)), padding: const EdgeInsets.symmetric(vertical: 16)),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close Details', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              )
            ],
          ),
        );
      },
    );
  }

  Map<String, dynamic> _getGradeStyle(String grade) {
    if (grade == 'Healthy') return {'icon': Icons.eco, 'color': secondaryColor, 'bg': const Color(0xFF92F7C3).withOpacity(0.3)};
    if (grade == 'Moderate') return {'icon': Icons.balance, 'color': habitTaxGold, 'bg': habitTaxGold.withOpacity(0.2)};
    if (grade == 'Unhealthy') return {'icon': Icons.warning_amber_rounded, 'color': alertDanger, 'bg': alertDanger.withOpacity(0.2)};
    return {'icon': Icons.help_outline, 'color': Colors.grey.shade600, 'bg': Colors.grey.shade300}; 
  }

  @override
  Widget build(BuildContext context) {
    final gradeStyle = _getGradeStyle(_latestGrade);

    return Scaffold(
      extendBody: true,
      backgroundColor: const Color(0xFFF8FAF6),
      bottomNavigationBar: const EcoPalBottomBar(currentIndex: 1), 
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


                        // 1. SCAN RECEIPT SECTION 
                        _buildGlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.document_scanner, color: primaryColor),
                                  const SizedBox(width: 8),
                                  const Text('Scan Receipt', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                                ],
                              ),
                              const SizedBox(height: 16),
                              GestureDetector(
                                onTap: _handleScanReceipt, 
                                child: Container(
                                  width: double.infinity,
                                  height: 120,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.5),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: primaryColor.withOpacity(0.3), width: 2), 
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.upload_file, size: 36, color: primaryColor),
                                      const SizedBox(height: 8),
                                      Text('Click to upload Image or PDF', style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600, fontSize: 13)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                      
                        // 3. AI ANALYSIS SECTION
                        _buildGlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.psychology, color: primaryColor),
                                      const SizedBox(width: 8),
                                      const Text('AI Analysis', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                                    ],
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(color: secondaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(100), border: Border.all(color: secondaryColor.withOpacity(0.2))),
                                    child: Row(
                                      children: [
                                        Container(width: 6, height: 6, decoration: BoxDecoration(color: secondaryColor, shape: BoxShape.circle)),
                                        const SizedBox(width: 6),
                                        Text('LATEST SCAN', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: secondaryColor)),
                                      ],
                                    ),
                                  )
                                ],
                              ),
                              const SizedBox(height: 20),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 90, height: 90,
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
                                        Text(_latestGrade.toUpperCase(), style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: gradeStyle['color'], letterSpacing: 0.5)),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: primaryColor.withOpacity(0.05),
                                        borderRadius: const BorderRadius.only(topRight: Radius.circular(16), bottomRight: Radius.circular(16), bottomLeft: Radius.circular(16)),
                                        border: Border(left: BorderSide(color: primaryColor, width: 4)),
                                      ),
                                      child: Text('"$_latestComment"', style: const TextStyle(fontSize: 13, color: Colors.black87, fontStyle: FontStyle.italic, height: 1.4)),
                                    ),
                                  )
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // 4. RECENT RECORDS (Trimmed to top 3)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Recent Records', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                            TextButton(
                              onPressed: _showAllRecordsTab, 
                              child: Text('View All', style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold))
                            ),
                          ],
                        ),
                        
                        if (_transactions.isEmpty)
                          const Center(child: Padding(padding: EdgeInsets.all(24.0), child: Text("No records yet.")))
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _transactions.length > 3 ? 3 : _transactions.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final tx = _transactions[index];
                              final amount = (tx['amount'] ?? 0.0).toDouble();
                              final bool isIncome = (tx['type'] ?? '') == 'income';

                              String txGrade = amount > 100 ? 'Unhealthy' : (amount > 50 ? 'Moderate' : 'Healthy');
                              final style = isIncome
                                  ? {'icon': Icons.add_circle, 'color': const Color(0xFF006C48), 'bg': const Color(0xFF92F7C3).withOpacity(0.3)}
                                  : _getGradeStyle(txGrade);

                              return GestureDetector(
                                onTap: () => _showTransactionDetails(tx), 
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.8), borderRadius: BorderRadius.circular(16), border: Border.all(color: outlineVariant.withOpacity(0.5))),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 40, height: 40,
                                        decoration: BoxDecoration(color: style['bg'], borderRadius: BorderRadius.circular(8)),
                                        child: Center(child: Icon(style['icon'], color: style['color'], size: 20)),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(tx['category'] ?? 'Record', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                            Text(tx['created_at'].toString().split('T').first, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            isIncome ? '+\$${amount.toStringAsFixed(2)}' : '\$${amount.toStringAsFixed(2)}',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                              color: isIncome ? const Color(0xFF006C48) : Colors.black87,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          if (!isIncome)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(color: style['bg'], borderRadius: BorderRadius.circular(100)),
                                              child: Text(txGrade.toUpperCase(), style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: style['color'])),
                                            )
                                          else
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(color: const Color(0xFF92F7C3).withOpacity(0.3), borderRadius: BorderRadius.circular(100)),
                                              child: Text('INCOME', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: secondaryColor)),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  // --- UI Helpers ---
  Widget _buildGlassCard({required Widget child, EdgeInsetsGeometry padding = const EdgeInsets.all(20)}) {
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

  Widget _buildInputLabel(String label, Widget input) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        input,
      ],
    );
  }

  InputDecoration _inputDecoration({String? hint}) {
    return InputDecoration(
      hintText: hint,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      filled: true,
      fillColor: Colors.white.withOpacity(0.9),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: primaryColor)),
    );
  }
}