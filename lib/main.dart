import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/theme.dart';
import 'core/app_localizations.dart';
import 'core/language_notifier.dart';
import 'core/theme_notifier.dart';
import 'auth/login_screen.dart';
import 'features/navigation/main_navigation.dart';
import 'features/crop_management/crop_list_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'services/notifications/monitoring_manager.dart';
import 'services/notifications/fcm_service.dart';

// Background message handler - must be top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  await firebaseMessagingBackgroundHandler(message);
}

void main() async {
  // Ensure Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp();

  // Load saved language and theme before showing UI
  await LanguageNotifier.instance.init();
  await ThemeNotifier.instance.init();

  // Initialize FCM background handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

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
    return ListenableBuilder(
      listenable: Listenable.merge([LanguageNotifier.instance, ThemeNotifier.instance]),
      builder: (context, _) {
        return AppLocalizationsProvider(
          languageCode: LanguageNotifier.instance.languageCode,
          child: MaterialApp(
            title: 'AgroEzuran',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: ThemeNotifier.instance.mode,
            themeAnimationDuration: Duration.zero,
            home: const AuthWrapper(),
          ),
        );
      },
    );
  }
}

/// ------------------------------------------------------------
/// AUTH WRAPPER
/// Listens to Firebase authentication state and manages monitoring
/// ------------------------------------------------------------
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final MonitoringManager _monitoringManager = MonitoringManager();
  final FCMService _fcmService = FCMService();
  bool _fcmInitialized = false;

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
          _monitoringManager.stopMonitoring();
          return const AuthErrorScreen();
        }

        // Logged in
        if (snapshot.hasData && snapshot.data != null) {
          // Initialize FCM once when user is authenticated
          if (!_fcmInitialized) {
            _fcmInitialized = true;
            _fcmService.initialize();
          }

          // Start monitoring when user is authenticated
          _monitoringManager.startMonitoring();
          return const PostLoginRouter();
        }

        // Not logged in - stop monitoring and reset FCM flag
        _fcmInitialized = false;
        _monitoringManager.stopMonitoring();
        return const LoginScreen();
      },
    );
  }

  @override
  void dispose() {
    _monitoringManager.stopMonitoring();
    super.dispose();
  }
}

/// ------------------------------------------------------------
/// POST LOGIN ROUTER
/// Decides whether user goes to:
/// - Onboarding (first ever launch, no crops)
/// - Crop Management / Get Started (no crop, seen onboarding)
/// - Main Navigation (has crop)
/// ------------------------------------------------------------
class PostLoginRouter extends StatelessWidget {
  const PostLoginRouter({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;

    return FutureBuilder<_PostLoginData>(
      future: _resolveRoute(user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SplashScreen();
        }

        final data = snapshot.data;
        final hasCrop = data?.hasCrop ?? false;
        final onboardingSeen = data?.onboardingSeen ?? true;

        // Has crop — go straight to main app
        if (hasCrop) return const MainNavigation();

        // First time ever — show onboarding first
        if (!onboardingSeen) {
          return OnboardingScreen(
            onDone: () {
              // After onboarding, replace with GetStartedScreen
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => const CropListScreen(showBackButton: false),
                ),
              );
            },
          );
        }

        // No crop, seen onboarding — go to setup screen
        return const CropListScreen(showBackButton: false);
      },
    );
  }

  Future<_PostLoginData> _resolveRoute(String uid) async {
    // Kick off both in parallel
    final cropFuture = FirebaseFirestore.instance
        .collection('crops')
        .where('farmer_id', isEqualTo: uid)
        .where('status', isEqualTo: 'active')
        .limit(1)
        .get();
    final prefsFuture = SharedPreferences.getInstance();

    final cropSnap = await cropFuture;
    final prefs = await prefsFuture;

    return _PostLoginData(
      hasCrop: cropSnap.docs.isNotEmpty,
      onboardingSeen: prefs.getBool('onboarding_seen') ?? false,
    );
  }
}

class _PostLoginData {
  final bool hasCrop;
  final bool onboardingSeen;
  const _PostLoginData({required this.hasCrop, required this.onboardingSeen});
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
              child: Image.asset(
                'assets/images/app_logo.png',
                width: 80,
                height: 80,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              AppLocalizations.of(context).t('AgroEzuran'),
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context).t('Smart Farming Solutions'),
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
