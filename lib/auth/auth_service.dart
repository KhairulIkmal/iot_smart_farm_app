import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/theme.dart';
import '../services/data_migration_service.dart';
import '../services/user_counter_service.dart';
import '../services/selected_crop_service.dart';
import 'login_screen.dart';
import '../features/navigation/main_navigation.dart';
import '../features/crop_management/crop_list_screen.dart';

/// ------------------------------------------------------------
/// AUTH SERVICE
/// Handles all authentication operations
/// ------------------------------------------------------------
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Sign in with email and password
  Future<Map<String, dynamic>> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      return {'success': true};
    } on FirebaseAuthException catch (e) {
      return {'success': false, 'error': _getAuthErrorMessage(e.code)};
    } catch (e) {
      return {
        'success': false,
        'error': 'An unexpected error occurred. Please try again.',
      };
    }
  }

  /// Register with email and password, then send verification email
  Future<Map<String, dynamic>> registerWithEmail({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Update display name and reload so currentUser reflects it immediately
      await userCredential.user?.updateDisplayName(name);
      await userCredential.user?.reload();

      // Generate custom user ID
      final userCounterService = UserCounterService();
      final customUserId = await userCounterService.getNextUserId();

      // Create user document with custom ID
      await _firestore.collection('users').doc(customUserId).set({
        'uid': userCredential.user!.uid,
        'name': name,
        'email': email,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });

      return {'success': true};
    } on FirebaseAuthException catch (e) {
      return {'success': false, 'error': _getAuthErrorMessage(e.code)};
    } catch (e) {
      return {
        'success': false,
        'error': 'An unexpected error occurred. Please try again.',
      };
    }
  }

  /// Send password reset email
  Future<Map<String, dynamic>> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return {'success': true};
    } on FirebaseAuthException catch (e) {
      return {'success': false, 'error': _getAuthErrorMessage(e.code)};
    } catch (e) {
      return {
        'success': false,
        'error': 'Failed to send password reset email. Please try again.',
      };
    }
  }

  /// Sign out
  Future<void> signOut() async {
    SelectedCropService().clearSelectedCrop();
    await _auth.signOut();
  }

  /// Get current user
  User? get currentUser => _auth.currentUser;

  /// Get auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Convert Firebase Auth error codes to user-friendly messages
  String _getAuthErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'invalid-email':
        return 'Invalid email address.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Please check your connection.';
      default:
        return 'An error occurred. Please try again.';
    }
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp();

  // Lock orientation to portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Status bar style
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
      title: 'AgroEzuran',
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
/// Handles Firebase authentication state only
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
/// Decides: Crop Management OR Main App
/// Also handles data migration to custom user IDs
/// ------------------------------------------------------------
class PostLoginRouter extends StatefulWidget {
  const PostLoginRouter({super.key});

  @override
  State<PostLoginRouter> createState() => _PostLoginRouterState();
}

class _PostLoginRouterState extends State<PostLoginRouter> {
  final DataMigrationService _migrationService = DataMigrationService();
  final UserCounterService _userCounterService = UserCounterService();
  bool _isMigrating = false;
  String? _customUserId;

  @override
  void initState() {
    super.initState();
    _checkAndMigrate();
  }

  Future<void> _checkAndMigrate() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isMigrating = true);

    // Check if user needs migration
    final needsMigration = await _migrationService.needsMigration(user);

    if (needsMigration) {
      // Show migration dialog
      if (mounted) {
        _showMigrationDialog();
      }

      // Run migration
      final customUserId = await _migrationService.migrateUserData(user);

      setState(() {
        _customUserId = customUserId;
        _isMigrating = false;
      });

      // Hide dialog
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    } else {
      // User already migrated, just get custom ID
      final userDoc = await _userCounterService.getUserByAuthUid(user.uid);
      setState(() {
        _customUserId = userDoc?.id;
        _isMigrating = false;
      });
    }
  }

  void _showMigrationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WillPopScope(
        onWillPop: () async => false,
        child: AlertDialog(
          backgroundColor: AppColors.surfaceDark,
          title: const Row(
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
              SizedBox(width: 16),
              Text(
                'Updating Account...',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
          content: const Text(
            'Please wait while we update your account data.',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isMigrating || _customUserId == null) {
      return const SplashScreen();
    }

    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('crops')
          .where('farmer_id', isEqualTo: _customUserId)
          .where('status', isEqualTo: 'active')
          .limit(1)
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SplashScreen();
        }

        // No crop claimed
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const CropListScreen(showBackButton: false);
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
              'AgroEzuran',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Smart Farming Solutions',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white.withOpacity(0.8),
              ),
            ),
            const SizedBox(height: 48),
            const SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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
