import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';

import '../services/api_service.dart';
import 'login_page.dart';
import 'pet_selection_page.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/floating_pet.dart';
import 'friend.dart';


class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _isLoading = true;

  String _userName = '';
  String _petName = '';
  String _petSpecies = 'Tabby';
  int _petLevel = 1;
  int _streak = 0; 
  double _totalHarvest = 0.00;

  final Color primaryColor = const Color(0xFF0F5238);
  final Color surfaceSoil = const Color(0xFFFDFCF8);
  final Color surfaceContainer = const Color(0xFFECEEEA);
  final Color outlineVariant = const Color(0xFFBFC9C1);
  final Color secondaryContainer = const Color(0xFF92F7C3);

  // GlobalKey used to identify the widget we want to screenshot
  final GlobalKey _shareCardKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showFloatingPet.value = true;
    });
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final profileData = await ApiService.getProfile();
      final petData = await ApiService.getPetStatus();
      final pocketsData = await ApiService.getPockets(); 

      if (mounted) {
        setState(() {
          _userName = profileData['username'] ?? 'User';
          _petName = petData['name'] ?? 'Companion';
          _petSpecies = petData['species'] ?? 'Tabby';
          _petLevel = petData['level'] ?? 1;
          
          _streak = profileData['streak'] ?? 0;

          double calculatedHarvest = (profileData['safe_to_spend_balance'] ?? 0.0).toDouble();
          for (var pocket in pocketsData) {
            calculatedHarvest += (pocket['current_balance'] ?? 0.0).toDouble();
          }
          
          _totalHarvest = calculatedHarvest;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String get _currentGifPath {
    if (_petSpecies.isEmpty) return ''; 
    
    // 1. Force lowercase so we never fail the check!
    String safeSpecies = _petSpecies.toLowerCase(); 
    
    String folder1 = safeSpecies;
    String folder2 = _petLevel <= 3 ? 'kitten' : 'cat';
    
    // 2. Use the safe, lowercase version to check for 'tabby'
    String prefix = safeSpecies == 'tabby' 
        ? (_petLevel <= 3 ? 'kit_' : 'cat_') 
        : (_petLevel <= 3 ? 'orkt_' : 'org_');
        
    return 'widgets/$folder1/$folder2/${prefix}idle.gif';
  }

  String _getBadgeAsset(int streak) {
    if (streak >= 30) {
      return 'widgets/badges/gold_badge.png';
    } else if (streak >= 7) {
      return 'widgets/badges/silver_badge.png';
    } else {
      return 'widgets/badges/bronze_badge.png';
    }
  }

  // --- Image Capture & Share Logic ---
  Future<void> _captureAndShare() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Generating image...')),
      );

      // 1. Find the Render object
      RenderRepaintBoundary boundary = _shareCardKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      
      // 2. Convert to Image (pixelRatio > 1 for high res)
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final buffer = byteData!.buffer.asUint8List();

      // 3. Create XFile directly from memory
      final xFile = XFile.fromData(
        buffer,
        mimeType: 'image/png',
        name: 'ecopal_progress.png',
      );

      // 4. Trigger native Share sheet
      await Share.shareXFiles(
        [xFile],
        text: 'Check out my financial garden on EcoPal! 🌿 I am on a $_streak day streak with $_petName!',
      );

    } catch (e) {
      debugPrint('Error sharing image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to generate image for sharing.')),
        );
      }
    }
  }

  void _showSharePreviewDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // --- THE WIDGET THAT WILL BE CAPTURED ---
              RepaintBoundary(
                key: _shareCardKey, 
                child: Container(
                  width: 300,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: surfaceSoil,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: primaryColor, width: 4),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('EcoPal', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: primaryColor)),
                      const SizedBox(height: 16),
                      
                      // Pet Avatar on the share card
                      Container(
                        width: 100, height: 100, 
                        decoration: BoxDecoration(color: surfaceContainer, shape: BoxShape.circle, border: Border.all(color: primaryColor, width: 2)), 
                        child: Image.asset(_currentGifPath, filterQuality: FilterQuality.none, fit: BoxFit.contain)
                      ),
                      const SizedBox(height: 12),
                      
                      // 🔥 Goal 1: Added Pet Name explicitly to the Share Card
                      Text(_petName, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: primaryColor)),
                      const SizedBox(height: 8),

                      _buildBadge('Level $_petLevel $_petSpecies', primaryColor),
                      const SizedBox(height: 16),
                      
                      Text('Owner: $_userName', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey)),
                      const SizedBox(height: 12),
                      
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset(
                            _getBadgeAsset(_streak),
                            width: 32,
                            height: 32,
                            fit: BoxFit.contain,
                          ),
                          const SizedBox(width: 8),
                          Text('$_streak Day Savings Streak!', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: secondaryContainer,
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text('Total Harvest: \$${_totalHarvest.toStringAsFixed(0)}', style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ),
              // --- END OF CAPTURED WIDGET ---
              
              const SizedBox(height: 24),
              
              // Action Button (This won't appear in the screenshot)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: primaryColor,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100))
                ),
                icon: const Icon(Icons.send),
                label: const Text('Share to Socials', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  _captureAndShare();     // Trigger screenshot & share
                },
              )
            ],
          ),
        );
      }
    );
  }

  // --- Edit Username Logic ---
  void _showEditNameDialog() {
    final TextEditingController nameController = TextEditingController(text: _userName);
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
              title: Text('Edit Username', style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'New Username',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: primaryColor, width: 2)),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor, 
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: isSaving ? null : () async {
                    final newName = nameController.text.trim();
                    if (newName.isEmpty || newName == _userName) {
                      Navigator.pop(context);
                      return;
                    }

                    setDialogState(() => isSaving = true);

                    try {
                      await ApiService.updateProfile({'username': newName});
                      
                      if (mounted) {
                        setState(() {
                          _userName = newName; 
                        });
                        Navigator.pop(context); 
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Username updated successfully!')));
                      }
                    } catch (e) {
                      if (mounted) {
                        setDialogState(() => isSaving = false);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to update username.')));
                      }
                    }
                  },
                  child: isSaving 
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Save'),
                ),
              ],
            );
          }
        );
      },
    );
  }

  Future<void> _launchSupport() async {
    final Uri url = Uri.parse('https://maps.app.goo.gl/nxLVEbwaJXjzT8HDA');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open Support URL')));
    }
  }

  Future<void> _signOut() async {
    await Supabase.instance.client.auth.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const LoginPage()), (route) => false);
    }
  }

 @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: const Color(0xFFF8FAF6),
      bottomNavigationBar: const EcoPalBottomBar(currentIndex: 4),

      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(left: 24, right: 24, top: 24, bottom: 40), 
                child: Column(
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
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 3))]),
                      child: Row(
                        children: [
                          Container(width: 70, height: 70, decoration: BoxDecoration(color: surfaceContainer, shape: BoxShape.circle, border: Border.all(color: primaryColor, width: 2)), child: Image.asset(_currentGifPath, filterQuality: FilterQuality.none, fit: BoxFit.contain)),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(_userName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                                    const SizedBox(width: 8),
                                    GestureDetector(
                                      onTap: _showEditNameDialog,
                                      child: Icon(Icons.edit, size: 16, color: Colors.grey.shade600),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    _buildBadge('Level $_petLevel', primaryColor),
                                    const SizedBox(width: 8),
                                    _buildBadge('$_streak Day Streak', const Color(0xFFF59E0B)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Image.asset(
                            _getBadgeAsset(_streak),
                            width: 50,
                            height: 50,
                            fit: BoxFit.contain,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 3))]),
                      child: Row(
                        children: [
                          Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: secondaryContainer.withOpacity(0.5), shape: BoxShape.circle), child: Icon(Icons.savings_outlined, color: primaryColor, size: 28)),
                          const SizedBox(width: 16),
                          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('TOTAL HARVEST', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2)), Text('\$${_totalHarvest.toStringAsFixed(2)}', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: primaryColor))])
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    FutureFriendsCard(primaryColor: primaryColor),
                    const SizedBox(height: 16),

                    Container(
                      decoration: BoxDecoration(color: const Color(0xFFF1F3E9).withOpacity(0.95), borderRadius: BorderRadius.circular(16), border: Border.all(color: primaryColor.withOpacity(0.2))),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => const PetSelectionPage())).then((_) {
                            showFloatingPet.value = true;
                            setState(() => _isLoading = true);
                            _loadData();
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Manage Companion', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), Icon(Icons.arrow_forward_ios, size: 18, color: Colors.grey.shade700)]),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: primaryColor, 
                        foregroundColor: Colors.white, 
                        minimumSize: const Size(double.infinity, 56), 
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100))
                      ),
                      icon: const Icon(Icons.ios_share), 
                      label: const Text('Share Progress', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)), 
                      onPressed: _showSharePreviewDialog,
                    ),
                    const SizedBox(height: 12),

                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(backgroundColor: Colors.white.withOpacity(0.9), foregroundColor: Colors.grey.shade800, side: BorderSide(color: Colors.grey.shade300), minimumSize: const Size(double.infinity, 56), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100))),
                      icon: const Icon(Icons.help_outline), label: const Text('Support & Feedback', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)), onPressed: _launchSupport,
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(backgroundColor: Colors.red.shade50.withOpacity(0.8), foregroundColor: Colors.red.shade600, side: BorderSide(color: Colors.red.shade100), minimumSize: const Size(double.infinity, 56), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100))),
                      icon: const Icon(Icons.logout), label: const Text('Log Out', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)), onPressed: _signOut,
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(100), border: Border.all(color: color.withOpacity(0.3))),
      child: Text(text, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }
}
  class FutureFriendsCard extends StatefulWidget {
  final Color primaryColor;
  const FutureFriendsCard({super.key, required this.primaryColor});

  @override
  State<FutureFriendsCard> createState() => _FutureFriendsCardState();
}

class _FutureFriendsCardState extends State<FutureFriendsCard> {
  List<dynamic> _friends = [];
  List<dynamic> _requests = [];
  bool _loaded = false;


  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final friends = await ApiService.getFriends();
      final requests = await ApiService.getFriendRequests();
      if (mounted) {
        setState(() {
          _friends = friends;
          _requests = requests;
          _loaded = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final int palCount = _friends.length;
    final int requestCount = _requests.length;

    const List<String> defaultGifs = [
      'widgets/orange/cat/org_happy.gif',
      'widgets/tabby/cat/cat_happy.gif',
      'widgets/tabby/kitten/kit_idle.gif',
    ];

    List<String> previewGifs = [];
    for (int i = 0; i < 3; i++) {
      if (i < _friends.length) {
        final f = _friends[i];
        final species = (f['species'] ?? 'tabby').toString().toLowerCase();
        final level = f['level'] ?? 1;
        final folder2 = level <= 3 ? 'kitten' : 'cat';
        final prefix = species == 'tabby'
            ? (level <= 3 ? 'kit_' : 'cat_')
            : (level <= 3 ? 'orkt_' : 'org_');
        previewGifs.add('widgets/$species/$folder2/${prefix}happy.gif');
      } else {
        previewGifs.add(defaultGifs[i]);
      }
    }

    final String statusLabel = requestCount > 0
        ? '$requestCount Request${requestCount > 1 ? 's' : ''}'
        : '$palCount Pal${palCount != 1 ? 's' : ''}';

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF1F3E9).withOpacity(0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: widget.primaryColor.withOpacity(0.2)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const FriendsPage()),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              // 3 GIF avatars overlapping
              SizedBox(
                width: 104,
                height: 52,
                child: Stack(
                  children: List.generate(
                    previewGifs.length,
                    (i) => Positioned(
                      left: i * 32.0,
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFECEEEA),
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            previewGifs[i],
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.none,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Friends',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: requestCount > 0
                            ? const Color(0xFFFFDAD6)
                            : const Color(0xFFB1F0CE),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(
                        _loaded ? statusLabel : '...',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: requestCount > 0
                              ? const Color(0xFFBA1A1A)
                              : widget.primaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Icon(Icons.chevron_right,
                  size: 20, color: Colors.grey.shade600),
            ],
          ),
        ),
      ),
    );
  }
}
