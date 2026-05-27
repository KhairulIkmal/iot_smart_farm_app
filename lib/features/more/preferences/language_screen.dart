import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../core/app_localizations.dart';
import '../../../core/language_notifier.dart';

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
  ];

  @override
  void initState() {
    super.initState();
    _selectedLanguage = LanguageNotifier.instance.languageCode;
  }

  Future<void> _selectLanguage(String code) async {
    await LanguageNotifier.instance.setLanguage(code);

    setState(() {
      _selectedLanguage = code;
    });

    if (mounted) {
      final message = code == 'ms'
          ? 'Language changed to Malay'
          : 'Language changed to English';
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 12),
              Text(l10n.t(message)),
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
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: ThemeColors.bg(context),
      appBar: AppBar(
        backgroundColor: ThemeColors.bg(context),
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 8),
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: ThemeColors.surface(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ThemeColors.border(context)),
              ),
              child: Icon(
                Icons.arrow_back,
                color: ThemeColors.icon(context),
                size: 24,
              ),
            ),
          ),
        ),
        title: Text(
          l10n.t('Language'),
          style: TextStyle(color: ThemeColors.textPrimary(context), fontWeight: FontWeight.bold),
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
                color: ThemeColors.surface(context),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? AppColors.primary : ThemeColors.border(context),
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
                      color: ThemeColors.bg(context),
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
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: ThemeColors.textPrimary(context),
                          ),
                        ),
                        Text(
                          language.nativeName,
                          style: TextStyle(
                            fontSize: 14,
                            color: ThemeColors.textSecondary(context).withOpacity(0.5),
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
                          color: ThemeColors.border(context),
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
