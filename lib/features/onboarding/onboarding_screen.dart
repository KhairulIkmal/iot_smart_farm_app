import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// ------------------------------------------------------------
/// ONBOARDING SCREEN
/// Shown exactly once for new users.
/// Stored in SharedPreferences: key 'onboarding_seen'
///
/// 4 slides:
///  1. Welcome to AgroEzuran
///  2. Connect Your IoT Sensor
///  3. Real-Time Monitoring
///  4. Smart AI Recommendations
/// ------------------------------------------------------------
class OnboardingScreen extends StatefulWidget {
  final VoidCallback onDone;

  const OnboardingScreen({super.key, required this.onDone});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;

  static const _slides = [
    _OnboardingSlide(
      icon: Icons.eco_rounded,
      iconSecondary: Icons.sensors_rounded,
      title: 'Welcome to AgroEzuran',
      subtitle: 'Smart farming starts here.',
      description:
          'Monitor your crops in real-time, get AI-powered advice, and keep your farm healthy — all from your phone.',
      gradient: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
      accentColor: Color(0xFF69F0AE),
    ),
    _OnboardingSlide(
      icon: Icons.developer_board_rounded,
      iconSecondary: Icons.qr_code_rounded,
      title: 'Connect Your IoT Sensor',
      subtitle: 'One code. One minute.',
      description:
          'Find the AGR-XXXX-XXXX code on your device packaging. Enter it once and your sensor is live — no technical setup required.',
      gradient: [Color(0xFF0D47A1), Color(0xFF1565C0)],
      accentColor: Color(0xFF40C4FF),
    ),
    _OnboardingSlide(
      icon: Icons.bar_chart_rounded,
      iconSecondary: Icons.water_drop_rounded,
      title: 'Real-Time Monitoring',
      subtitle: 'Always know your field\'s condition.',
      description:
          'Soil moisture, pH, temperature, humidity — updated live from your ESP32 sensor. Get instant alerts when anything needs attention.',
      gradient: [Color(0xFF4A148C), Color(0xFF6A1B9A)],
      accentColor: Color(0xFFE040FB),
    ),
    _OnboardingSlide(
      icon: Icons.psychology_rounded,
      iconSecondary: Icons.tips_and_updates_rounded,
      title: 'AI-Powered Advice',
      subtitle: 'Your personal farming assistant.',
      description:
          'Ask anything about your crops and get instant recommendations based on your live sensor data, weather, and proven agricultural science.',
      gradient: [Color(0xFFBF360C), Color(0xFFD84315)],
      accentColor: Color(0xFFFFD180),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeIn);
    _fadeController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _markSeenAndContinue() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_seen', true);
    widget.onDone();
  }

  void _nextPage() {
    if (_currentPage < _slides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      _markSeenAndContinue();
    }
  }

  @override
  Widget build(BuildContext context) {
    final slide = _slides[_currentPage];
    final isLast = _currentPage == _slides.length - 1;

    return Scaffold(
      backgroundColor: slide.gradient[0],
      body: FadeTransition(
        opacity: _fadeAnim,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: slide.gradient,
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // Skip button
                _buildTopBar(isLast),

                // Content
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (i) {
                      setState(() => _currentPage = i);
                      _fadeController
                        ..reset()
                        ..forward();
                    },
                    itemCount: _slides.length,
                    itemBuilder: (_, i) => _buildSlideContent(_slides[i]),
                  ),
                ),

                // Bottom: Dots + Button
                _buildBottomBar(slide, isLast),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(bool isLast) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // App Logo pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SvgPicture.asset(
                  'assets/icons/agroezuran_icon_allmode.svg',
                  width: 18,
                  height: 18,
                ),
                const SizedBox(width: 6),
                const Text(
                  'AgroEzuran',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          // Skip
          if (!isLast)
            TextButton(
              onPressed: _markSeenAndContinue,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white.withOpacity(0.7),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              child: const Text(
                'Skip',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            )
          else
            const SizedBox(width: 60),
        ],
      ),
    );
  }

  Widget _buildSlideContent(_OnboardingSlide slide) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon cluster
          Stack(
            alignment: Alignment.center,
            children: [
              // Outer glow ring
              Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.05),
                ),
              ),
              // Mid ring
              Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.08),
                ),
              ),
              // Main icon circle
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.15),
                  border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
                ),
                child: Icon(slide.icon, color: Colors.white, size: 48),
              ),
              // Secondary icon — top right
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: slide.accentColor.withOpacity(0.2),
                    border: Border.all(color: slide.accentColor.withOpacity(0.5)),
                  ),
                  child: Icon(slide.iconSecondary, color: slide.accentColor, size: 20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 48),

          // Subtitle pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: slide.accentColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: slide.accentColor.withOpacity(0.4)),
            ),
            child: Text(
              slide.subtitle,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: slide.accentColor,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Title
          Text(
            slide.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 16),

          // Description
          Text(
            slide.description,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: Colors.white.withOpacity(0.75),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(_OnboardingSlide slide, bool isLast) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 0, 32, 40),
      child: Column(
        children: [
          // Page dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_slides.length, (i) {
              final isActive = i == _currentPage;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: isActive ? 28 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: isActive
                      ? slide.accentColor
                      : Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
          const SizedBox(height: 32),

          // Action button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _nextPage,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: slide.gradient[0],
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    isLast ? 'Get Started' : 'Next',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    isLast ? Icons.rocket_launch_rounded : Icons.arrow_forward_rounded,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingSlide {
  final IconData icon;
  final IconData iconSecondary;
  final String title;
  final String subtitle;
  final String description;
  final List<Color> gradient;
  final Color accentColor;

  const _OnboardingSlide({
    required this.icon,
    required this.iconSecondary,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.gradient,
    required this.accentColor,
  });
}
