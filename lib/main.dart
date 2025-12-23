import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'core/theme.dart';
import 'auth/login_screen.dart';
import 'features/navigation/main_navigation.dart';
import 'features/crop_management/crop_list_screen.dart';

void main() async {
  // Ensure Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp();

  // Lock orientation to portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Status bar styling
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
  );

  runApp(const IoTSmartFarmApp());
}

class IoTSmartFarmApp extends StatelessWidget {
  const IoTSmartFarmApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IoT Smart Farm',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      home: const AuthWrapper(),
    );
  }
}

/// ------------------------------------------------------------
/// AUTH WRAPPER
/// Only listens to Firebase authentication state
/// ------------------------------------------------------------
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Loading
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SplashScreen();
        }

        // Error
        if (snapshot.hasError) {
          return const AuthErrorScreen();
        }

        // Logged in
        if (snapshot.hasData && snapshot.data != null) {
          return const PostLoginRouter();
        }

        // Not logged in
        return const LoginScreen();
      },
    );
  }
}

/// ------------------------------------------------------------
/// POST LOGIN ROUTER
/// Decides whether user goes to:
/// - Crop Management (no crop)
/// - Main Navigation (has crop)
/// ------------------------------------------------------------
class PostLoginRouter extends StatelessWidget {
  const PostLoginRouter({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;

    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('crops')
          .where('farmer_id', isEqualTo: user.uid)
          .where('status', isEqualTo: 'active')
          .limit(1)
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SplashScreen();
        }

        // No crop claimed yet
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const CropListScreen();
        }

        // Crop exists
        return const MainNavigation();
      },
    );
  }
}

/// ------------------------------------------------------------
/// SPLASH SCREEN
/// ------------------------------------------------------------
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1B5E20),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Icon(Icons.eco, size: 64, color: Color(0xFF2E7D32)),
            ),
            const SizedBox(height: 32),
            const Text(
              'IoT Smart Farm',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Smart Farming Solutions',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white.withOpacity(0.8),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 48),
            const SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                strokeWidth: 3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ------------------------------------------------------------
/// AUTH ERROR SCREEN
/// ------------------------------------------------------------
class AuthErrorScreen extends StatelessWidget {
  const AuthErrorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Authentication Error',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text('Please restart the application'),
          ],
        ),
      ),
    );
  }
}
