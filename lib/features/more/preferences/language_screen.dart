import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/theme.dart';

/// ------------------------------------------------------------
/// LANGUAGE SCREEN
///
/// Shows:
/// - Language selection list
/// - Current language indicator
/// ------------------------------------------------------------
class LanguageScreen extends StatefulWidget {
  const LanguageScreen({super.key});

  @override
  State<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends State<LanguageScreen> {
  String _selectedLanguage = 'en';

  final List<_LanguageOption> _languages = [
    _LanguageOption(
      code: 'en',
      name: 'English',
      nativeName: 'English',
      flag: '🇺🇸',
    ),
    _LanguageOption(
      code: 'ms',
      name: 'Malay',
      nativeName: 'Bahasa Melayu',
      flag: '🇲🇾',
    ),
    _LanguageOption(
      code: 'zh',
      name: 'Chinese',
      nativeName: '中文',
      flag: '🇨🇳',
    ),
    _LanguageOption(
      code: 'ta',
      name: 'Tamil',
      nativeName: 'தமிழ்',
      flag: '🇮🇳',
    ),
    _LanguageOption(
      code: 'id',
      name: 'Indonesian',
      nativeName: 'Bahasa Indonesia',
      flag: '🇮🇩',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadLanguage();
  }

  Future<void> _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedLanguage = prefs.getString('language') ?? 'en';
    });
  }

  Future<void> _selectLanguage(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', code);

    setState(() {
      _selectedLanguage = code;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 12),
              Text(
                'Language changed to ${_languages.firstWhere((l) => l.code == code).name}',
              ),
            ],
          ),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Language',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _languages.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final language = _languages[index];
          final isSelected = _selectedLanguage == language.code;

          return GestureDetector(
            onTap: () => _selectLanguage(language.code),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceDark,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.borderDark,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  // Flag
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.backgroundDark,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        language.flag,
                        style: const TextStyle(fontSize: 24),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Language Name
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          language.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          language.nativeName,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Selected Indicator
                  if (isSelected)
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 18,
                      ),
                    )
                  else
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.borderDark,
                          width: 2,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _LanguageOption {
  final String code;
  final String name;
  final String nativeName;
  final String flag;

  _LanguageOption({
    required this.code,
    required this.name,
    required this.nativeName,
    required this.flag,
  });
}
