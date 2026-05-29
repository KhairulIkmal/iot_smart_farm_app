import 'package:flutter/material.dart';
import '../../../core/theme.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeColors.bg(context),
      appBar: AppBar(
        backgroundColor: ThemeColors.bg(context),
        title: const Text('Privacy Policy'),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          Text(
            'Last updated: 1 January 2025',
            style: TextStyle(
              fontSize: 13,
              color: ThemeColors.textSecondary(context).withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 24),

          _buildSection(
            context,
            title: '1. Information We Collect',
            body:
                'AgroEzuran collects the following information to provide our services:\n\n'
                '• Account information: name, email address, and password (stored securely via Firebase Authentication).\n'
                '• Farm data: farm name, location, crop types, planting dates, and field notes you enter.\n'
                '• Sensor data: real-time readings from your IoT devices including soil moisture, pH, temperature, humidity, and water levels.\n'
                '• Device information: device codes, online/offline status, and pump activity logs.\n'
                '• Usage data: app interactions used to improve the service.',
          ),

          _buildSection(
            context,
            title: '2. How We Use Your Information',
            body:
                'We use the information collected to:\n\n'
                '• Provide and maintain the AgroEzuran service.\n'
                '• Display live sensor data and historical readings on your Dashboard.\n'
                '• Power the AI advisory feature with your live farm context.\n'
                '• Send notifications for sensor alerts and pump activity.\n'
                '• Process and resolve support tickets you submit.\n'
                '• Improve app performance and user experience.',
          ),

          _buildSection(
            context,
            title: '3. Data Storage & Security',
            body:
                'Your data is stored on Google Firebase (Firestore and Realtime Database), which employs industry-standard encryption at rest and in transit. Sensor readings are stored under your unique user account and are not accessible by other users.',
          ),

          _buildSection(
            context,
            title: '4. AI Assistant & Third-Party Services',
            body:
                'The AI Assistant feature sends your live sensor readings, crop information, and irrigation rules to Anthropic\'s Claude API to generate responses. This data is sent securely over HTTPS and is governed by Anthropic\'s data usage policies. We do not send personally identifiable information (such as your name or email) to the AI service.',
          ),

          _buildSection(
            context,
            title: '5. Data Sharing',
            body:
                'We do not sell, trade, or rent your personal information to third parties. Data may be shared only with:\n\n'
                '• Service providers (Firebase, Anthropic) necessary to operate the App.\n'
                '• Law enforcement or regulatory bodies if required by applicable law.',
          ),

          _buildSection(
            context,
            title: '6. Data Retention',
            body:
                'We retain your data for as long as your account is active. You may request deletion of your account and associated data at any time by contacting us through Help & Support. Sensor readings may be retained in anonymised form for service improvement.',
          ),

          _buildSection(
            context,
            title: '7. Your Rights',
            body:
                'You have the right to:\n\n'
                '• Access the personal data we hold about you.\n'
                '• Correct inaccurate data via the Profile screen.\n'
                '• Request deletion of your account and data.\n'
                '• Withdraw consent for data processing at any time.',
          ),

          _buildSection(
            context,
            title: '8. Children\'s Privacy',
            body:
                'AgroEzuran is not intended for use by individuals under the age of 13. We do not knowingly collect personal information from children.',
          ),

          _buildSection(
            context,
            title: '9. Changes to This Policy',
            body:
                'We may update this Privacy Policy from time to time. We will notify you of significant changes through the App. Continued use of the App after changes are posted constitutes your acceptance.',
          ),

          _buildSection(
            context,
            title: '10. Contact Us',
            body:
                'If you have questions or concerns about this Privacy Policy, please reach out through the Help & Support section in the App.',
          ),
        ],
      ),
    );
  }

  Widget _buildSection(BuildContext context, {required String title, required String body}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: ThemeColors.textPrimary(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: TextStyle(
              fontSize: 14,
              height: 1.6,
              color: ThemeColors.textSecondary(context).withOpacity(0.75),
            ),
          ),
        ],
      ),
    );
  }
}
