import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../core/theme.dart';
import '../core/constants.dart';
import '../core/app_localizations.dart';
import 'auth_service.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _authService = AuthService();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _acceptedTerms = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_acceptedTerms) {
      _showError('Please accept the Terms & Conditions');
      return;
    }
    setState(() => _isLoading = true);
    try {
      final result = await _authService.registerWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        name: _nameController.text.trim(),
      );
      if (!mounted) return;
      if (!result['success']) {
        _showError(result['error'] ?? AppStrings.somethingWentWrong);
      } else {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (_) {
      _showError(AppStrings.somethingWentWrong);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: ThemeColors.bg(context),
      body: Column(
        children: [
          _buildHero(l10n),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _fieldLabel(l10n.t('Full Name')),
                    const SizedBox(height: 8),
                    _nameField(l10n),
                    const SizedBox(height: 18),
                    _fieldLabel(l10n.t('Email address')),
                    const SizedBox(height: 8),
                    _emailField(l10n),
                    const SizedBox(height: 18),
                    _fieldLabel(l10n.t('Password')),
                    const SizedBox(height: 8),
                    _passwordField(l10n),
                    const SizedBox(height: 18),
                    _fieldLabel(l10n.t('Confirm Password')),
                    const SizedBox(height: 8),
                    _confirmPasswordField(l10n),
                    const SizedBox(height: 20),
                    _termsRow(l10n),
                    const SizedBox(height: 24),
                    _createAccountButton(l10n),
                    const SizedBox(height: 28),
                    _loginLink(l10n),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // HERO BAND
  // ─────────────────────────────────────────────
  Widget _buildHero(AppLocalizations l10n) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(28, 60, 28, 30),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back button + logo row
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
                ),
              ),
              const SizedBox(width: 12),
              SvgPicture.asset(
                'assets/icons/agroezuran_icon_allmode.svg',
                width: 36,
                height: 36,
              ),
              const SizedBox(width: 8),
              const Text(
                'AgroEzuran',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            l10n.t('Create Account'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.t('Start monitoring your farm with smart IoT solutions today.'),
            style: TextStyle(
              color: Colors.white.withOpacity(0.72),
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // FIELD COMPONENTS
  // ─────────────────────────────────────────────
  Widget _fieldLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: ThemeColors.textPrimary(context),
      ),
    );
  }

  Widget _nameField(AppLocalizations l10n) {
    return TextFormField(
      controller: _nameController,
      textCapitalization: TextCapitalization.words,
      style: TextStyle(color: ThemeColors.textPrimary(context), fontSize: 15),
      decoration: _dec(hint: 'e.g. Ahmad Rizal', icon: Icons.person_outline_rounded),
      validator: (v) {
        if (v == null || v.isEmpty) return l10n.t(AppStrings.fieldRequired);
        if (v.trim().length < 2) return l10n.t('Name must be at least 2 characters');
        return null;
      },
    );
  }

  Widget _emailField(AppLocalizations l10n) {
    return TextFormField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      style: TextStyle(color: ThemeColors.textPrimary(context), fontSize: 15),
      decoration: _dec(hint: 'farmer@example.com', icon: Icons.alternate_email_rounded),
      validator: (v) => _validateEmail(v, l10n),
    );
  }

  String? _validateEmail(String? v, AppLocalizations l10n) {
    if (v == null || v.isEmpty) return l10n.t(AppStrings.fieldRequired);

    final email = v.trim().toLowerCase();

    // Basic format check
    if (!RegExp(r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$')
        .hasMatch(email)) {
      return 'Enter a valid email address';
    }

    // Must have at least 2 chars before @
    final localPart = email.split('@').first;
    if (localPart.length < 2) return 'Enter a valid email address';

    // Block disposable / dummy email domains
    final domain = email.split('@').last;
    if (_isDisposableDomain(domain)) {
      return 'Disposable or temporary emails are not allowed';
    }

    return null;
  }

  bool _isDisposableDomain(String domain) {
    const blocked = {
      // Mailinator family
      'mailinator.com', 'trashmail.com', 'trashmail.at', 'trashmail.io',
      'trashmail.me', 'trashmail.net', 'trashmail.org',
      // Guerrilla Mail
      'guerrillamail.com', 'guerrillamail.net', 'guerrillamail.org',
      'guerrillamail.de', 'guerrillamail.biz', 'guerrillamail.info',
      'guerrillamailblock.com', 'grr.la', 'sharklasers.com',
      'spam4.me', 'spamgourmet.com',
      // 10 Minute Mail
      '10minutemail.com', '10minutemail.net', '10minemail.com',
      // Yop Mail
      'yopmail.com', 'yopmail.fr', 'cool.fr.nf', 'jetable.fr.nf',
      // Temp Mail & family
      'temp-mail.org', 'tempmail.com', 'tempmail.net', 'tempmail.de',
      'tempr.email', 'discard.email', 'dispostable.com',
      // Throwaway
      'throwaway.email', 'throwam.com',
      // Fake Inbox
      'fakeinbox.com', 'fakeinbox.net', 'mailnull.com',
      // Maildrop
      'maildrop.cc',
      // Others
      'getnada.com', 'filzmail.com', 'zetmail.com', 'wegwerfmail.de',
      'spamfree24.org', 'spamfree.eu', 'spamoff.de', 'objectmail.com',
      'spam.la', 'binkmail.com', 'safetymail.info', 'mailexpire.com',
      'spamherelots.com', 'spamhereplease.com', 'spamthisplease.com',
      'spamtrail.com', 'spamtraps.nl',
      // Common test/dummy patterns
      'example.com', 'example.net', 'example.org',
      'test.com', 'testing.com',
    };
    return blocked.contains(domain);
  }

  Widget _passwordField(AppLocalizations l10n) {
    return TextFormField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      style: TextStyle(color: ThemeColors.textPrimary(context), fontSize: 15),
      decoration: _dec(
        hint: 'Min. 6 characters',
        icon: Icons.lock_outline_rounded,
        suffix: IconButton(
          icon: Icon(
            _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
            color: ThemeColors.textSecondary(context).withOpacity(0.45),
            size: 20,
          ),
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
        ),
      ),
      validator: (v) {
        if (v == null || v.isEmpty) return l10n.t(AppStrings.fieldRequired);
        if (v.length < 6) return l10n.t(AppStrings.invalidPassword);
        return null;
      },
    );
  }

  Widget _confirmPasswordField(AppLocalizations l10n) {
    return TextFormField(
      controller: _confirmPasswordController,
      obscureText: _obscureConfirmPassword,
      style: TextStyle(color: ThemeColors.textPrimary(context), fontSize: 15),
      decoration: _dec(
        hint: 'Re-enter your password',
        icon: Icons.lock_outline_rounded,
        suffix: IconButton(
          icon: Icon(
            _obscureConfirmPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
            color: ThemeColors.textSecondary(context).withOpacity(0.45),
            size: 20,
          ),
          onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
        ),
      ),
      validator: (v) {
        if (v == null || v.isEmpty) return l10n.t(AppStrings.fieldRequired);
        if (v != _passwordController.text) return l10n.t(AppStrings.passwordsDoNotMatch);
        return null;
      },
    );
  }

  Widget _termsRow(AppLocalizations l10n) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: Checkbox(
            value: _acceptedTerms,
            onChanged: (v) => setState(() => _acceptedTerms = v ?? false),
            activeColor: AppColors.primary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            side: BorderSide(color: ThemeColors.border(context), width: 1.5),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            l10n.t('I agree to the Terms & Conditions and Privacy Policy'),
            style: TextStyle(
              fontSize: 13,
              color: ThemeColors.textSecondary(context).withOpacity(0.7),
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  Widget _createAccountButton(AppLocalizations l10n) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _register,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.primary.withOpacity(0.5),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                l10n.t('Create Account'),
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
      ),
    );
  }

  Widget _loginLink(AppLocalizations l10n) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          l10n.t('Already have an account? '),
          style: TextStyle(
            fontSize: 14,
            color: ThemeColors.textSecondary(context).withOpacity(0.65),
          ),
        ),
        GestureDetector(
          onTap: () => Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          ),
          child: const Text(
            'Sign in',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────
  // SHARED DECORATION
  // ─────────────────────────────────────────────
  InputDecoration _dec({required String hint, required IconData icon, Widget? suffix}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: ThemeColors.textSecondary(context).withOpacity(0.3), fontSize: 14),
      prefixIcon: Icon(icon, color: AppColors.primary.withOpacity(0.6), size: 20),
      suffixIcon: suffix,
      filled: true,
      fillColor: ThemeColors.surface(context),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: ThemeColors.border(context))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: ThemeColors.border(context))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.error)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.error, width: 2)),
    );
  }
}
