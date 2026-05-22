import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/login_page.dart';
import 'screens/garden_page.dart';
import 'screens/pet_selection_page.dart'; // 🔥 Import PetSelectionPage
import 'services/api_service.dart';       // 🔥 Import ApiService
import 'widgets/floating_pet.dart'; 


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Supabase.initialize(
    url: 'https://pccyxrqilbmhmuagyxxe.supabase.co', 
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBjY3l4cnFpbGJtaG11YWd5eHhlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc5MDg1MzIsImV4cCI6MjA5MzQ4NDUzMn0.e-wPHS7iuo7ngto5u9h8UwaoEaU_jRIg2U7bo-3qbqM',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Living Ledger - EcoPal',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0F5238)),
        fontFamily: 'Plus Jakarta Sans',
      ),
      // Global floating pet
      builder: (context, child) {
        return Stack(
          children: [
            if (child != null) child,
            ValueListenableBuilder<bool>(
              valueListenable: showFloatingPet,
              builder: (context, show, childWidget) {
                // Offstage keeps it mounted (saving its position & state) but hides it!
                return Offstage(
                  offstage: !show,
                  child: childWidget!,
                );
              },
              child: const Material(
                type: MaterialType.transparency,
                child: FloatingPet(),
              ),
            ),
          ],
        );
      },
      home: const AuthGate(),
      //home: const GardenPage(),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _isChecking = true;
  Widget _initialPage = const LoginPage();

  @override
  void initState() {
    super.initState();
    _checkInitialSession();
    _listenToAuthChanges();
  }

  // --- 🔥 Goal 1: Check Pet Status for initial load ---
  Future<void> _checkInitialSession() async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) {
      try {
        final petData = await ApiService.getPetStatus();
        final species = petData['species'];
        
        // If first time sign-in or species is uninitialized/default, route to Pet Selection
        if (species == null || species == 'default' || species.toString().trim().isEmpty) {
          _initialPage = const PetSelectionPage();
        } else {
          _initialPage = const GardenPage();
        }
      } catch (e) {
        // If API fails (e.g. backend returns 404 because pet isn't created yet)
        _initialPage = const PetSelectionPage();
      }
    } else {
      _initialPage = const LoginPage();
    }

    if (mounted) {
      setState(() {
        _isChecking = false;
      });
    }
  }

  void _listenToAuthChanges() {
    Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
      final event = data.event;
      if (!mounted) return;

      // Skip the initialSession event as it's already handled by _checkInitialSession()
      if (event == AuthChangeEvent.initialSession) return;

      if (event == AuthChangeEvent.signedIn) {
        // --- 🔥 Goal 1: Check Pet Status on active sign-in ---
        try {
          final petData = await ApiService.getPetStatus();
          final species = petData['species'];
          if (!mounted) return;
          
          if (species == null || species == 'default' || species.toString().trim().isEmpty) {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const PetSelectionPage()));
          } else {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const GardenPage()));
          }
        } catch (e) {
          if (mounted) {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const PetSelectionPage()));
          }
        }
      } else if (event == AuthChangeEvent.signedOut) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginPage()));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Show a loading spinner while we verify the user's Pet status with the API
    if (_isChecking) {
      return const Scaffold(
        backgroundColor: Color(0xFFFDFCF8), 
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF0F5238)),
        ),
      );
    }
    
    return _initialPage;
  }
}