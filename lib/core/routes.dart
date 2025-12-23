import 'package:flutter/material.dart';

// Auth Screens
import '../auth/login_screen.dart';
import '../auth/register_screen.dart';

// Main Navigation
import '../features/navigation/main_navigation.dart';

// Dashboard
import '../features/dashboard/dashboard_screen.dart';

// Sensors
import '../features/sensors/sensors_screen.dart';

// Analytics
import '../features/analytics/sensor_graph_screen.dart';

// Irrigation
import '../features/irrigation/irrigation_screen.dart';

// Chatbot
import '../features/chatbot/ai_chatbot_screen.dart';

// Crop Management
import '../features/crop_management/crop_list_screen.dart';
import '../features/crop_management/claim_device_screen.dart';

// More Menu
import '../features/more/more_screen.dart';
import '../features/more/profile/profile_screen.dart';
import '../features/more/farm/farm_location_screen.dart';
import '../features/more/farm/farm_details_screen.dart';
import '../features/more/notifications/notifications_screen.dart';
import '../features/more/preferences/language_screen.dart';
import '../features/more/preferences/alert_tone_screen.dart';
import '../features/more/preferences/change_password_screen.dart';

/// App route names
class AppRoutes {
  // Prevent instantiation
  AppRoutes._();

  // Auth Routes
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';

  // Main Routes
  static const String main = '/main';
  static const String dashboard = '/dashboard';
  static const String sensors = '/sensors';
  static const String irrigation = '/irrigation';
  static const String aiChatbot = '/ai-chatbot';
  static const String more = '/more';

  // Analytics Routes
  static const String sensorGraph = '/sensor-graph';

  // Crop Management Routes
  static const String cropList = '/crop-list';
  static const String claimDevice = '/claim-device';

  // Profile & Settings Routes
  static const String profile = '/profile';
  static const String editProfile = '/edit-profile';
  static const String farmLocation = '/farm-location';
  static const String farmDetails = '/farm-details';
  static const String notifications = '/notifications';
  static const String language = '/language';
  static const String alertTone = '/alert-tone';
  static const String changePassword = '/change-password';

  // Initial route
  static const String initial = login;
}

/// Route generator for named navigation
class AppRouter {
  // Prevent instantiation
  AppRouter._();

  /// Generate route based on route settings
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      // Auth Routes
      case AppRoutes.login:
        return _buildRoute(const LoginScreen(), settings);

      case AppRoutes.register:
        return _buildRoute(const RegisterScreen(), settings);

      // Main Routes
      case AppRoutes.main:
        return _buildRoute(const MainNavigation(), settings);

      case AppRoutes.dashboard:
        return _buildRoute(const DashboardScreen(), settings);

      case AppRoutes.sensors:
        return _buildRoute(const SensorsScreen(), settings);

      case AppRoutes.irrigation:
        return _buildRoute(const IrrigationScreen(), settings);

      case AppRoutes.aiChatbot:
        return _buildRoute(const AiChatbotScreen(), settings);

      case AppRoutes.more:
        return _buildRoute(const MoreScreen(), settings);

      // Analytics Routes
      case AppRoutes.sensorGraph:
        final args = settings.arguments as Map<String, dynamic>?;
        return _buildRoute(
          SensorGraphScreen(
            sensorType: args?['sensorType'] ?? 'temperature',
            deviceId: args?['deviceId'] ?? '',
          ),
          settings,
        );

      // Crop Management Routes
      case AppRoutes.cropList:
        return _buildRoute(const CropListScreen(), settings);

      case AppRoutes.claimDevice:
        return _buildRoute(const ClaimDeviceScreen(), settings);

      // Profile & Settings Routes
      case AppRoutes.profile:
        return _buildRoute(const ProfileScreen(), settings);

      case AppRoutes.farmLocation:
        return _buildRoute(const FarmLocationScreen(), settings);

      case AppRoutes.farmDetails:
        return _buildRoute(const FarmDetailsScreen(), settings);

      case AppRoutes.notifications:
        return _buildRoute(const NotificationsScreen(), settings);

      case AppRoutes.language:
        return _buildRoute(const LanguageScreen(), settings);

      case AppRoutes.alertTone:
        return _buildRoute(const AlertToneScreen(), settings);

      case AppRoutes.changePassword:
        return _buildRoute(const ChangePasswordScreen(), settings);

      // Unknown Route
      default:
        return _buildRoute(const _UnknownRouteScreen(), settings);
    }
  }

  /// Build a MaterialPageRoute with the given widget and settings
  static MaterialPageRoute<dynamic> _buildRoute(
    Widget widget,
    RouteSettings settings,
  ) {
    return MaterialPageRoute(builder: (_) => widget, settings: settings);
  }

  /// Build a route with slide transition from right
  static Route<dynamic> _buildSlideRoute(
    Widget widget,
    RouteSettings settings,
  ) {
    return PageRouteBuilder(
      settings: settings,
      pageBuilder: (context, animation, secondaryAnimation) => widget,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        const curve = Curves.easeInOut;

        var tween = Tween(
          begin: begin,
          end: end,
        ).chain(CurveTween(curve: curve));

        return SlideTransition(position: animation.drive(tween), child: child);
      },
      transitionDuration: const Duration(milliseconds: 300),
    );
  }

  /// Build a route with fade transition
  static Route<dynamic> _buildFadeRoute(Widget widget, RouteSettings settings) {
    return PageRouteBuilder(
      settings: settings,
      pageBuilder: (context, animation, secondaryAnimation) => widget,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
      transitionDuration: const Duration(milliseconds: 300),
    );
  }
}

/// Screen shown when route is not found
class _UnknownRouteScreen extends StatelessWidget {
  const _UnknownRouteScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Page Not Found')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              '404',
              style: Theme.of(
                context,
              ).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Page not found',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.of(
                  context,
                ).pushNamedAndRemoveUntil(AppRoutes.main, (route) => false);
              },
              child: const Text('Go to Home'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Extension for easy navigation
extension NavigatorExtension on BuildContext {
  /// Navigate to a named route
  Future<T?> pushNamed<T>(String routeName, {Object? arguments}) {
    return Navigator.of(this).pushNamed<T>(routeName, arguments: arguments);
  }

  /// Replace current route with a named route
  Future<T?> pushReplacementNamed<T, TO>(
    String routeName, {
    Object? arguments,
  }) {
    return Navigator.of(
      this,
    ).pushReplacementNamed<T, TO>(routeName, arguments: arguments);
  }

  /// Navigate to a named route and remove all previous routes
  Future<T?> pushNamedAndRemoveUntil<T>(String routeName, {Object? arguments}) {
    return Navigator.of(this).pushNamedAndRemoveUntil<T>(
      routeName,
      (route) => false,
      arguments: arguments,
    );
  }

  /// Pop the current route
  void pop<T>([T? result]) {
    Navigator.of(this).pop<T>(result);
  }

  /// Check if can pop
  bool canPop() {
    return Navigator.of(this).canPop();
  }

  /// Pop until a specific route
  void popUntil(String routeName) {
    Navigator.of(this).popUntil(ModalRoute.withName(routeName));
  }
}
