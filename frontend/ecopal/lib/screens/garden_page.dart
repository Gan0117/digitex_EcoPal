import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:math' as math;
import '../widgets/bottom_nav_bar.dart';
import '../services/api_service.dart';
import '../widgets/floating_pet.dart';

class MoneyPocket {
  String id;
  String name;
  double targetAmount;
  double currentBalance;
  int growthStage;
  bool isLocked;
  bool isAutoDeduct;
  double autoDeductAmount;

  MoneyPocket({
    required this.id,
    required this.name,
    required this.targetAmount,
    required this.currentBalance,
    required this.growthStage,
    required this.isLocked,
    this.isAutoDeduct = false,
    this.autoDeductAmount = 0.0,
  });

  factory MoneyPocket.fromJson(Map<String, dynamic> json) {
    return MoneyPocket(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      targetAmount: (json['target_amount'] ?? 0).toDouble(),
      currentBalance: (json['current_balance'] ?? 0).toDouble(),
      growthStage: json['growth_stage'] ?? 1,
      isLocked: json['is_locked'] ?? false,
      isAutoDeduct: json['is_auto_deduct'] ?? false,
      autoDeductAmount: (json['auto_deduct_amount'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'target_amount': targetAmount,
        'current_balance': currentBalance,
        'growth_stage': growthStage,
        'is_locked': isLocked,
        'is_auto_deduct': isAutoDeduct,
        'auto_deduct_amount': autoDeductAmount,
      };
}

class GardenPage extends StatefulWidget {
  const GardenPage({super.key});

  @override
  State<GardenPage> createState() => _GardenPageState();
}

class _GardenPageState extends State<GardenPage>
    with SingleTickerProviderStateMixin {
  List<MoneyPocket> _pockets = [];
  bool _isLoading = true;
  bool _deleteMode = false;
  String? _error;
  double _safeToSpend = 0.0;

  String? _petSpecies;
  int _petLevel = 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showFloatingPet.value = true;
    });
    _loadData();
  }

  @override
  void dispose() {
    super.dispose();
  }

  String _weatherState(double safeToSpend, double totalTarget) {
    if (safeToSpend <= 0) return 'storm';
    final ratio = totalTarget > 0 ? safeToSpend / totalTarget : 1.0;
    if (ratio <= 0.10) return 'overcast';
    return 'sunny';
  }

  String _treeImage(int pocketIndex, int growthStage) {
    final names = ['first', 'second', 'third', 'fourth', 'fifth'];
    final name = names[pocketIndex.clamp(0, 4)];
    if (growthStage >= 3) return 'widgets/dashboard/${name}_tree_big.png';
    if (growthStage == 2) return 'widgets/dashboard/${name}_tree_medium.png';
    return 'widgets/dashboard/${name}_tree_small.png';
  }

  String _weatherGif(String weather) {
    if (weather == 'storm') return 'widgets/dashboard/storm.gif';
    if (weather == 'overcast') return 'widgets/dashboard/overcast.gif';
    return 'widgets/dashboard/sunny.gif';
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final results = await Future.wait<dynamic>([
        ApiService.getPockets(),
        ApiService.getSafeToSpendBalance(),
        ApiService.getPetStatus(),
      ]);
      setState(() {
        _pockets =
            (results[0] as List<dynamic>).map((e) => MoneyPocket.fromJson(e)).toList();
        _safeToSpend = results[1] as double;
        final petData = results[2] as Map<String, dynamic>;
        _petSpecies = petData['species'] ?? 'Tabby';
        _petLevel = petData['level'] ?? 1;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load data: $e';
        _isLoading = false;
      });
    }
  }

  double get _totalTarget => _pockets.fold(0, (sum, p) => sum + p.targetAmount);
  String get _currentWeather => _weatherState(_safeToSpend, _totalTarget);

  int _computeGrowthStage(double currentBalance, double targetAmount) {
    if (targetAmount <= 0) return 1;
    if (currentBalance >= targetAmount) return 3;
    if (currentBalance > targetAmount * 0.5) return 2;
    return 1;
  }

  String _formatAmount(double amount) {
    if (amount >= 1000) {
      return 'RM${(amount / 1000).toStringAsFixed(amount % 1000 == 0 ? 0 : 1)}K';
    }
    return 'RM${amount.toStringAsFixed(0)}';
  }

  // ─── Dialogs (unchanged) ────────────────────────────────────────────────────

  void _showAddMoneyDialog() {
    final amountController = TextEditingController();
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            backgroundColor: const Color(0xFFEDEDEF),
            title: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDDDDE0),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.add_circle_outline, color: Color(0xFF4CAF50), size: 20),
                ),
                const SizedBox(width: 12),
                const Text('Add Money',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.black87)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Current balance: RM${_safeToSpend.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 13, color: Colors.black54),
                ),
                const SizedBox(height: 14),
                const Text('Amount to Add',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.black54,
                        letterSpacing: 0.5)),
                const SizedBox(height: 6),
                TextField(
                  controller: amountController,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    hintText: 'e.g. 500.00',
                    prefixText: 'RM ',
                    filled: true,
                    fillColor: const Color(0xFFE2E2E5),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: Color(0xFF4CAF50), width: 1.5)),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
              ],
            ),
            actions: [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: isSaving ? null : () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        side: const BorderSide(color: Color(0xFFB0B0B3)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Cancel',
                          style: TextStyle(color: Color(0xFF888888))),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: isSaving
                          ? null
                          : () async {
                              final addedAmount =
                                  double.tryParse(amountController.text);
                              if (addedAmount == null || addedAmount <= 0) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'Enter a valid amount greater than 0.')),
                                );
                                return;
                              }
                              setDialogState(() => isSaving = true);
                              try {
                                final profile = await ApiService.getProfile();
                                final latestBalance =
                                    (profile['safe_to_spend_balance'] as num?)
                                            ?.toDouble() ??
                                        0.0;
                                final currentPoints =
                                    (profile['reward_points'] as num?)?.toInt() ?? 0;
                                final newBalance = latestBalance + addedAmount;
                                const int pointsEarned = 20;
                                await ApiService.updateProfile({
                                  'safe_to_spend_balance': newBalance,
                                  'reward_points': currentPoints + pointsEarned
                                });
                                await ApiService.postTransaction({
                                  'category': 'Add Money',
                                  'amount': addedAmount,
                                  'description': 'Added to Main Account',
                                  'type': 'income',
                                  'created_at': DateTime.now().toIso8601String(),
                                });
                                if (ctx.mounted) {
                                  setState(() => _safeToSpend = newBalance);
                                  Navigator.pop(ctx);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Row(
                                        children: [
                                          const Icon(Icons.stars_rounded,
                                              color: Colors.white, size: 20),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              'RM${addedAmount.toStringAsFixed(2)} added! +$pointsEarned reward points ✨',
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.w600),
                                            ),
                                          ),
                                        ],
                                      ),
                                      backgroundColor: const Color(0xFF2E7D32),
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12)),
                                      margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                                      duration: const Duration(seconds: 4),
                                    ),
                                  );
                                  rewardPointsEarnedNotifier.value = 0;
                                  rewardPointsEarnedNotifier.value = pointsEarned;
                                }
                              } catch (e) {
                                if (ctx.mounted) {
                                  setDialogState(() => isSaving = false);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text(
                                            'Failed to add money. Please try again.')),
                                  );
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4CAF50),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                      ),
                      child: isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : const Text('Add',
                              style: TextStyle(
                                  color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  void _showEditSafeToSpendDialog() {
    final amountController =
        TextEditingController(text: _safeToSpend.toStringAsFixed(2));
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            backgroundColor: const Color(0xFFEDEDEF),
            title: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDDDDE0),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.edit, color: Color(0xFF4CAF50), size: 20),
                ),
                const SizedBox(width: 12),
                const Text('Edit Safe to Spend',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Amount',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.black54,
                        letterSpacing: 0.5)),
                const SizedBox(height: 6),
                TextField(
                  controller: amountController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    hintText: 'e.g. 1500.00',
                    prefixText: 'RM ',
                    filled: true,
                    fillColor: const Color(0xFFE2E2E5),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: Color(0xFF4CAF50), width: 1.5)),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
              ],
            ),
            actions: [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: isSaving ? null : () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        side: const BorderSide(color: Color(0xFFB0B0B3)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Cancel',
                          style: TextStyle(color: Color(0xFF888888))),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: isSaving
                          ? null
                          : () async {
                              final val = double.tryParse(amountController.text);
                              if (val == null || val < 0) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text('Enter a valid amount.')));
                                return;
                              }
                              setDialogState(() => isSaving = true);
                              try {
                                await ApiService.updateProfile(
                                    {'safe_to_spend_balance': val});
                                if (ctx.mounted) {
                                  setState(() => _safeToSpend = val);
                                  Navigator.pop(ctx);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text(
                                              'Main Account amount updated successfully!')));
                                }
                              } catch (e) {
                                if (ctx.mounted) {
                                  setDialogState(() => isSaving = false);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content:
                                              Text('Failed to update balance.')));
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4CAF50),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                      ),
                      child: isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : const Text('Save',
                              style: TextStyle(
                                  color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  void _showReleaseConfirm(int index, {required bool isFromReleaseButton}) {
    final pocket = _pockets[index];
    final String msg = isFromReleaseButton
        ? 'Confirm to release ${pocket.name} money to main acc. This money pocket will be delete at the same time.'
        : 'After remove the money pocket, your money will move to your main account.';
    bool isProcessing = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            backgroundColor: const Color(0xFFEDEDEF),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                            color: const Color(0xFFFFE0E0),
                            borderRadius: BorderRadius.circular(10)),
                        child: Icon(
                            isFromReleaseButton
                                ? Icons.payments_outlined
                                : Icons.delete_outline,
                            color: Colors.redAccent,
                            size: 20),
                      ),
                      const SizedBox(width: 12),
                      Text(
                          isFromReleaseButton ? 'Release Funds' : 'Delete Plant',
                          style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(msg,
                      style: const TextStyle(fontSize: 14, color: Colors.black54)),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: isProcessing
                              ? null
                              : () {
                                  Navigator.pop(ctx);
                                },
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            side: const BorderSide(color: Color(0xFFB0B0B3)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text('Cancel',
                              style: TextStyle(color: Color(0xFF888888))),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: isProcessing
                              ? null
                              : () async {
                                  setDialogState(() => isProcessing = true);
                                  try {
                                    await ApiService.releasePocket(
                                        pocket.id, pocket.currentBalance);
                                    if (ctx.mounted) {
                                      Navigator.pop(ctx);
                                      _loadData();
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Row(
                                            children: [
                                              const Icon(Icons.check_circle,
                                                  color: Colors.white, size: 20),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Text(
                                                  isFromReleaseButton
                                                      ? 'Funds successfully released to main account!'
                                                      : '🌱 Plant removed. Funds returned to main account!',
                                                  style: const TextStyle(
                                                      fontWeight: FontWeight.w600),
                                                ),
                                              ),
                                            ],
                                          ),
                                          backgroundColor: const Color(0xFF2E7D32),
                                          behavior: SnackBarBehavior.floating,
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12)),
                                          margin: const EdgeInsets.fromLTRB(
                                              16, 0, 16, 24),
                                          duration: const Duration(seconds: 3),
                                        ),
                                      );
                                    }
                                  } catch (_) {
                                    if (ctx.mounted) {
                                      setDialogState(() => isProcessing = false);
                                      ScaffoldMessenger.of(ctx).showSnackBar(
                                          const SnackBar(
                                              content: Text(
                                                  "Failed to process request.")));
                                    }
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: 0,
                          ),
                          child: isProcessing
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2))
                              : const Text('Confirm',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showPartialReleaseDialog(MoneyPocket pocket, int index) {
    final amountController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isReleasing = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            backgroundColor: const Color(0xFFEDEDEF),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.payments_outlined,
                              color: Color(0xFF4CAF50), size: 20),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Release Amount',
                            style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFD0D0D3)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Available in pocket',
                              style: TextStyle(
                                  fontSize: 13, color: Colors.grey.shade600)),
                          Text(
                            'RM${pocket.currentBalance.toStringAsFixed(2)}',
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2E7D32)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildFieldLabel('Amount to Release'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: amountController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'e.g. 200.00',
                        hintStyle: TextStyle(
                            color: Colors.grey.shade400, fontSize: 14),
                        prefixText: 'RM ',
                        prefixStyle: const TextStyle(
                            color: Colors.black87, fontWeight: FontWeight.w500),
                        filled: true,
                        fillColor: const Color(0xFFE2E2E5),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: Color(0xFFD0D0D3))),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: Color(0xFF4CAF50), width: 1.5)),
                        errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: Colors.redAccent, width: 1.5)),
                        focusedErrorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: Colors.redAccent, width: 1.5)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty)
                          return 'Please enter an amount';
                        final val = double.tryParse(v);
                        if (val == null || val <= 0)
                          return 'Enter a valid amount greater than 0';
                        if (val > pocket.currentBalance)
                          return 'Cannot exceed pocket balance (RM${pocket.currentBalance.toStringAsFixed(2)})';
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'The amount will be moved to your Main Account.',
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                          height: 1.4),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed:
                                isReleasing ? null : () => Navigator.pop(ctx),
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              side: const BorderSide(color: Color(0xFFB0B0B3)),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text('Cancel',
                                style: TextStyle(color: Color(0xFF888888))),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: isReleasing
                                ? null
                                : () async {
                                    if (!formKey.currentState!.validate())
                                      return;
                                    final amount =
                                        double.parse(amountController.text);
                                    setDialogState(() => isReleasing = true);
                                    try {
                                      await ApiService.releasePartialPocket(
                                          pocket.id, amount);
                                      final newBalance =
                                          pocket.currentBalance - amount;
                                      final newStage = _computeGrowthStage(
                                          newBalance, pocket.targetAmount);
                                      setState(() {
                                        _pockets[index] = MoneyPocket(
                                          id: pocket.id,
                                          name: pocket.name,
                                          targetAmount: pocket.targetAmount,
                                          currentBalance: newBalance,
                                          growthStage: newStage,
                                          isLocked: newBalance >=
                                              pocket.targetAmount,
                                          isAutoDeduct: pocket.isAutoDeduct,
                                          autoDeductAmount:
                                              pocket.autoDeductAmount,
                                        );
                                        _safeToSpend += amount;
                                      });
                                      if (ctx.mounted) {
                                        Navigator.pop(ctx);
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Row(
                                              children: [
                                                const Icon(Icons.check_circle,
                                                    color: Colors.white,
                                                    size: 20),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: Text(
                                                    'RM${amount.toStringAsFixed(2)} released to Main Account!',
                                                    style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.w600),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            backgroundColor:
                                                const Color(0xFF2E7D32),
                                            behavior:
                                                SnackBarBehavior.floating,
                                            shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12)),
                                            margin: const EdgeInsets.fromLTRB(
                                                16, 0, 16, 24),
                                            duration:
                                                const Duration(seconds: 3),
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      setDialogState(
                                          () => isReleasing = false);
                                      if (ctx.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                              content: Text(
                                                  'Failed to release funds. Please try again.')),
                                        );
                                      }
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4CAF50),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              elevation: 0,
                            ),
                            child: isReleasing
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2))
                                : const Text('Confirm',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showMaxPocketsMessage() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: const Color(0xFFEDEDEF),
        title: const Text('Maximum Reached',
            style:
                TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
        content: const Text('You can only add 5 money pockets.',
            style: TextStyle(color: Colors.black54)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK', style: TextStyle(color: Color(0xFF4CAF50))),
          ),
        ],
      ),
    );
  }

  void _showCreatePocketDialog() {
    final nameController = TextEditingController();
    final targetController = TextEditingController();
    final balanceController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: const Color(0xFFEDEDEF),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFFDDDDE0),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.eco,
                          color: Color(0xFF4CAF50), size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Text('Create Money Pocket',
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87)),
                  ],
                ),
                const SizedBox(height: 20),
                _buildFieldLabel('Name'),
                const SizedBox(height: 6),
                _buildTextField(
                  controller: nameController,
                  hint: 'e.g. Emergency Fund',
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Please enter a name'
                      : null,
                ),
                const SizedBox(height: 14),
                _buildFieldLabel('Target Amount'),
                const SizedBox(height: 6),
                _buildTextField(
                  controller: targetController,
                  hint: 'e.g. 5000.00',
                  keyboardType: TextInputType.number,
                  prefix: 'RM',
                  validator: (v) {
                    if (v == null || v.trim().isEmpty)
                      return 'Please enter target amount';
                    if (double.tryParse(v) == null) return 'Enter a valid number';
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                _buildFieldLabel('Current Balance'),
                const SizedBox(height: 6),
                _buildTextField(
                  controller: balanceController,
                  hint: 'e.g. 1200.00',
                  keyboardType: TextInputType.number,
                  prefix: 'RM',
                  validator: (v) {
                    if (v == null || v.trim().isEmpty)
                      return 'Please enter current balance';
                    if (double.tryParse(v) == null) return 'Enter a valid number';
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          side: const BorderSide(color: Color(0xFFB0B0B3)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Cancel',
                            style: TextStyle(color: Color(0xFF888888))),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          if (formKey.currentState!.validate()) {
                            final currentBal =
                                double.parse(balanceController.text);
                            final targetAmt =
                                double.parse(targetController.text);
                            final isLocked = currentBal >= targetAmt;
                            final newPocket = MoneyPocket(
                              id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
                              name: nameController.text.trim(),
                              targetAmount: targetAmt,
                              currentBalance: currentBal,
                              growthStage:
                                  _computeGrowthStage(currentBal, targetAmt),
                              isLocked: isLocked,
                              isAutoDeduct: false,
                              autoDeductAmount: 0.0,
                            );
                            try {
                              final realId = await ApiService.createPocket(
                                  newPocket.toJson());
                              newPocket.id = realId;
                              setState(() => _pockets.add(newPocket));
                              if (ctx.mounted) Navigator.pop(ctx);
                            } catch (e) {
                              if (ctx.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content:
                                            Text('Failed to create pocket.')));
                              }
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4CAF50),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                        ),
                        child: const Text('Create',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showEditPocketDialog(int index) {
    final pocket = _pockets[index];
    final nameController = TextEditingController(text: pocket.name);
    final targetController =
        TextEditingController(text: pocket.targetAmount.toStringAsFixed(2));
    final balanceController =
        TextEditingController(text: pocket.currentBalance.toStringAsFixed(2));
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: const Color(0xFFEDEDEF),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFFDDDDE0),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.edit,
                          color: Color(0xFF4CAF50), size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Text('Edit Money Pocket',
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87)),
                  ],
                ),
                const SizedBox(height: 20),
                _buildFieldLabel('Name'),
                const SizedBox(height: 6),
                _buildTextField(
                  controller: nameController,
                  hint: 'e.g. Emergency Fund',
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Please enter a name'
                      : null,
                ),
                const SizedBox(height: 14),
                _buildFieldLabel('Target Amount'),
                const SizedBox(height: 6),
                _buildTextField(
                  controller: targetController,
                  hint: 'e.g. 5000.00',
                  keyboardType: TextInputType.number,
                  prefix: 'RM',
                  validator: (v) {
                    if (v == null || v.trim().isEmpty)
                      return 'Please enter target amount';
                    if (double.tryParse(v) == null) return 'Enter a valid number';
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                _buildFieldLabel('Current Balance'),
                const SizedBox(height: 6),
                _buildTextField(
                  controller: balanceController,
                  hint: 'e.g. 1200.00',
                  keyboardType: TextInputType.number,
                  prefix: 'RM',
                  validator: (v) {
                    if (v == null || v.trim().isEmpty)
                      return 'Please enter current balance';
                    if (double.tryParse(v) == null) return 'Enter a valid number';
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          side: const BorderSide(color: Color(0xFFB0B0B3)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Cancel',
                            style: TextStyle(color: Color(0xFF888888))),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          if (formKey.currentState!.validate()) {
                            final currentBal =
                                double.parse(balanceController.text);
                            final targetAmt =
                                double.parse(targetController.text);
                            final isLocked = currentBal >= targetAmt;
                            final updated = MoneyPocket(
                              id: pocket.id,
                              name: nameController.text.trim(),
                              targetAmount: targetAmt,
                              currentBalance: currentBal,
                              growthStage:
                                  _computeGrowthStage(currentBal, targetAmt),
                              isLocked: isLocked,
                              isAutoDeduct:
                                  isLocked ? false : pocket.isAutoDeduct,
                              autoDeductAmount: pocket.autoDeductAmount,
                            );
                            try {
                              await ApiService.updatePocket(
                                  pocket.id, updated.toJson());
                            } catch (_) {}
                            setState(() => _pockets[index] = updated);
                            if (ctx.mounted) Navigator.pop(ctx);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4CAF50),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                        ),
                        child: const Text('Save',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Text(label,
        style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.black54,
            letterSpacing: 0.5));
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    String? prefix,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
        prefixText: prefix,
        prefixStyle: const TextStyle(
            color: Colors.black87, fontWeight: FontWeight.w500),
        filled: true,
        fillColor: const Color(0xFFE2E2E5),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFD0D0D3))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: Color(0xFF4CAF50), width: 1.5)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.redAccent, width: 1.5)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.redAccent, width: 1.5)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }

  void _showPocketDetails(MoneyPocket pocket, int index) {
    final deductAmountController = TextEditingController(
        text: pocket.autoDeductAmount > 0
            ? pocket.autoDeductAmount.toStringAsFixed(2)
            : '');
    bool isSaveClicked = false;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: const Color(0xFFEDEDEF),
        child: StatefulBuilder(
          builder: (BuildContext context, StateSetter setStateDialog) {
            final progress = pocket.targetAmount > 0
                ? (pocket.currentBalance / pocket.targetAmount).clamp(0.0, 1.0)
                : 0.0;

            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 40,
                        height: 40,
                        child: Image.asset(
                            _treeImage(index, pocket.growthStage),
                            width: 40,
                            height: 40,
                            fit: BoxFit.contain),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(pocket.name,
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87)),
                      ),
                      if (pocket.isLocked)
                        const Icon(Icons.lock, color: Colors.grey, size: 20)
                      else
                        GestureDetector(
                          onTap: () {
                            Navigator.pop(ctx);
                            _showReleaseConfirm(index,
                                isFromReleaseButton: false);
                          },
                          child: const Icon(Icons.delete_outline,
                              color: Colors.redAccent, size: 24),
                        ),
                    ],
                  ),
                  if (pocket.isLocked) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green.shade200)),
                      child: const Row(
                        children: [
                          Icon(Icons.check_circle,
                              color: Colors.green, size: 20),
                          SizedBox(width: 8),
                          Expanded(
                              child: Text(
                                  'Goal Met! This pocket has reached its target.',
                                  style: TextStyle(
                                      color: Colors.green,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13))),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Target',
                          style: TextStyle(
                              color: Colors.grey.shade500, fontSize: 14)),
                      Text('RM${pocket.targetAmount.toStringAsFixed(2)}',
                          style: const TextStyle(
                              color: Colors.black87,
                              fontWeight: FontWeight.w600,
                              fontSize: 14)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Current',
                          style: TextStyle(
                              color: Colors.grey.shade500, fontSize: 14)),
                      Text('RM${pocket.currentBalance.toStringAsFixed(2)}',
                          style: const TextStyle(
                              color: Colors.black87,
                              fontWeight: FontWeight.w600,
                              fontSize: 14)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 10,
                      backgroundColor: Colors.grey.shade300,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF4CAF50)),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text('${(progress * 100).toStringAsFixed(1)}% of goal',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade500)),
                  const SizedBox(height: 20),
                  const Divider(color: Color(0xFFD0D0D3), thickness: 1),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text('Auto Deduct',
                                    style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87)),
                                const SizedBox(width: 10),
                                if (pocket.isAutoDeduct && !pocket.isLocked)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                        color: const Color(0xFFFDF5E6),
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                    child: const Text('ACTIVE',
                                        style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFFD4A373))),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            const Text(
                                'Automatically channels a set amount from your Safe to Spend to grow this plant\'s Current balance.',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.black54,
                                    height: 1.3)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      if (pocket.isLocked)
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _showReleaseConfirm(index,
                                isFromReleaseButton: true);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                          ),
                          child: const Text('Release',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold)),
                        )
                      else
                        Switch(
                          value: pocket.isAutoDeduct,
                          activeColor: const Color(0xFFE5B94A),
                          onChanged: (val) async {
                            setStateDialog(() => pocket.isAutoDeduct = val);
                            try {
                              await ApiService.updatePocket(
                                  pocket.id, pocket.toJson());
                            } catch (e) {
                              debugPrint('Failed to update auto deduct: $e');
                            }
                          },
                        ),
                    ],
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    child: pocket.isAutoDeduct && !pocket.isLocked
                        ? Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: deductAmountController,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                            decimal: true),
                                    decoration: InputDecoration(
                                      labelText: 'Deduction Amount (RM)',
                                      filled: true,
                                      fillColor: Colors.white,
                                      border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          borderSide: BorderSide.none),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 8),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  onPressed: () async {
                                    setStateDialog(
                                        () => isSaveClicked = true);
                                    pocket.autoDeductAmount =
                                        double.tryParse(
                                                deductAmountController.text) ??
                                            0.0;
                                    try {
                                      await ApiService.updatePocket(
                                          pocket.id, pocket.toJson());
                                      if (ctx.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(const SnackBar(
                                                content: Text(
                                                    'Deduction amount saved!')));
                                        Navigator.pop(ctx);
                                      }
                                    } catch (e) {
                                      debugPrint(
                                          'Failed to save deduction amount: $e');
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isSaveClicked
                                        ? Colors.redAccent
                                        : const Color(0xFFE5B94A),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(8)),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14),
                                  ),
                                  child: const Text('Save',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            side: const BorderSide(color: Color(0xFFB0B0B3)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text('Close',
                              style: TextStyle(color: Color(0xFF888888))),
                        ),
                      ),
                      if (pocket.currentBalance > 0) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              _showPartialReleaseDialog(pocket, index);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4CAF50),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              elevation: 0,
                            ),
                            child: const Text('Release Amount',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13)),
                          ),
                        ),
                      ],
                      if (!pocket.isLocked) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              _showEditPocketDialog(index);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE2E2E5),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              elevation: 0,
                            ),
                            child: const Text('Add Money',
                                style: TextStyle(
                                    color: Colors.black87,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ─── UI Builders ────────────────────────────────────────────────────────────

  /// Hero card replicating the yellow "Child Picture Book" card but with
  /// Main Account content and weather-aware plant illustration.
  Widget _buildHeroCard() {
    final weather = _currentWeather;

    // Weather label / emoji
    final (weatherEmoji, weatherLabel, weatherColor) = switch (weather) {
  'storm' => ('🌧️', 'Storm', const Color(0xFFE53935)),
  'overcast' => ('🌤️', 'Overcast', const Color(0xFFFB8C00)),
  _ => ('🌞', 'Sunny', const Color(0xFFE65100)),
  };

    // Hero background colour follows weather
   const heroColor = Color(0xFF0F5238);

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      height: 160,
      decoration: BoxDecoration(
        color: heroColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Left content
          Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'MAIN ACCOUNT',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Colors.white70,
                    letterSpacing: 1.6,
                  ),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'RM${_safeToSpend.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1.1,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // Weather badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.55),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(weatherEmoji,
                          style: const TextStyle(fontSize: 12)),
                      const SizedBox(width: 4),
                      Text(weatherLabel,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: weatherColor)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

          // Right: plant illustration + weather gif overlay
          
          // Edit pencil (top-right)
          Positioned(
            top: 12,
            right: 12,
            child: GestureDetector(
              onTap: _showEditSafeToSpendDialog,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.20),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.edit, size: 15, color: Colors.white),
              ),
            ),
          ),

          // Add money (top-left)
          Positioned(
            top: 12,
            left: 12,
            child: GestureDetector(
              onTap: _showAddMoneyDialog,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.20),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.add, size: 18, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  
  /// Section header identical in style to "RECOMMEND" / "see all"
  Widget _buildSectionHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      child: Row(
        children: [
          // Yellow left-border accent like the reference app
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: const Color(0xFFFFCA28),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'MONEY POCKET',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: Colors.black87,
              letterSpacing: 0.3,
            ),
          ),
          const Spacer(),
          Row(
            children: [
              _SectionButton(
                icon: Icons.add,
                color: const Color(0xFF0F5238),
                description: 'Add Plant',
                onTap: _pockets.length >= 5
                    ? _showMaxPocketsMessage
                    : _showCreatePocketDialog,
              ),
              const SizedBox(width: 8),
              _SectionButton(
                icon: Icons.delete_outline,
                color: const Color(0xFF0F5238),
                description: 'Delete Plant',
                onTap: () => setState(() => _deleteMode = !_deleteMode),
                isActive: _deleteMode,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Individual money-pocket card styled like the book recommendation cards.
 Widget _buildPocketCard(int index) {
  final pocket = _pockets[index];
  final weather = _currentWeather;
  final progress = pocket.targetAmount > 0
      ? (pocket.currentBalance / pocket.targetAmount).clamp(0.0, 1.0)
      : 0.0;
  final isComplete = progress >= 1.0;

  return GestureDetector(
    onTap: () {
      if (_deleteMode) {
        _showReleaseConfirm(index, isFromReleaseButton: false);
      } else {
        _showPocketDetails(pocket, index);
      }
    },
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 3))
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 72,
                height: 72,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset(
                        _treeImage(index, pocket.growthStage),
                        width: 72,
                        height: 72,
                        fit: BoxFit.contain,
                      ),
                    ),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Opacity(
                        opacity: 0.40,
                        child: Image.asset(
                          _weatherGif(weather),
                          width: 72,
                          height: 72,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pocket.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Colors.black87),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'RM${pocket.currentBalance.toStringAsFixed(2)}',
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF444444)),
                        ),
                        Text(
                          'RM${pocket.targetAmount.toStringAsFixed(2)}',
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF444444)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 8,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isComplete
                              ? const Color(0xFF0F5238)
                              : const Color(0xFF4CAF50),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isComplete
                          ? 'Done!'
                          : '${(progress * 100).toStringAsFixed(0)}%',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isComplete
                              ? const Color(0xFF0F5238)
                              : const Color(0xFF4CAF50)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              if (!_deleteMode)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: isComplete
                        ? const Color(0xFF0F5238)
                        : const Color(0xFF4DB6AC),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isComplete ? 'Release' : 'Edit',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Colors.white),
                  ),
                ),
            ],
          ),
        ),
        if (_deleteMode)
          Positioned(
            top: -4,
            left: 16,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: Colors.redAccent,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 14),
            ),
          ),
      ],
    ),
  );
}

  /// Empty state when there are no pockets yet
  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 32),
      child: Column(
        children: [
          Image.asset(
            'widgets/dashboard/first_tree_small.png',
            width: 80,
            height: 80,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: 16),
          const Text(
            'No money pockets yet',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black54),
          ),
          const SizedBox(height: 6),
          const Text(
            'Tap "see all" to create your first savings goal.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.black38),
          ),
        ],
      ),
    );
  }

  // ─── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      extendBody: true,
      bottomNavigationBar: const EcoPalBottomBar(currentIndex: 0),
      body: SafeArea(
        bottom: false,
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF4CAF50)))
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!,
                            style: const TextStyle(color: Colors.black54)),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: _loadData,
                          style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4CAF50)),
                          child: const Text('Retry',
                              style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadData,
                    color: const Color(0xFF4CAF50),
                    child: CustomScrollView(
                      physics: const BouncingScrollPhysics(),
                      slivers: [
                        // ── App bar with logo ─────────────────────────────
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                            child: Row(
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
                          ),
                        ),

                        // ── Hero card ─────────────────────────────────────
                        SliverToBoxAdapter(child: _buildHeroCard()),

                        const SliverToBoxAdapter(child: SizedBox(height: 28)),

                       
                        // ── Section header ────────────────────────────────
                        SliverToBoxAdapter(child: _buildSectionHeader()),

                        const SliverToBoxAdapter(child: SizedBox(height: 14)),

                        // ── Pocket cards ──────────────────────────────────
                        if (_pockets.isEmpty)
                          SliverToBoxAdapter(child: _buildEmptyState())
                        else
                          SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) =>
                                  _buildPocketCard(index),
                              childCount: _pockets.length,
                            ),
                          ),

                        // Bottom padding for nav bar
                        const SliverToBoxAdapter(
                            child: SizedBox(height: 100)),
                      ],
                    ),
                  ),
      ),
    );
  }
}

class _SectionButton extends StatefulWidget {
  final IconData icon;
  final Color color;
  final String description;
  final VoidCallback onTap;
  final bool isActive;

  const _SectionButton({
    required this.icon,
    required this.color,
    required this.description,
    required this.onTap,
    this.isActive = false,
  });

  @override
  State<_SectionButton> createState() => _SectionButtonState();
}

class _SectionButtonState extends State<_SectionButton> {
  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.description,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: widget.isActive
                ? widget.color
                : widget.color.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(
            widget.icon,
            size: 18,
            color: widget.isActive ? Colors.white : widget.color,
          ),
        ),
      ),
    );
  }
}