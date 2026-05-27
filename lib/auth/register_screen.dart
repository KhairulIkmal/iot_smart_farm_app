import 'package:flutter/material.dart';

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
  bool _isGoogleLoading = false;
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

  /// ------------------------------------------------
  /// EMAIL REGISTRATION
  /// ------------------------------------------------
  Future<void> _registerWithEmail() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_acceptedTerms) {
      final l10n = AppLocalizations.of(context);
      _showErrorSnackBar(l10n.t('Please accept the Terms & Conditions'));
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
        _showErrorSnackBar(result['error'] ?? AppStrings.somethingWentWrong);
      } else {
        if (mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      }
    } catch (_) {
      _showErrorSnackBar(AppStrings.somethingWentWrong);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// ------------------------------------------------
  /// GOOGLE SIGN UP
  /// ------------------------------------------------
  Future<void> _signUpWithGoogle() async {
    setState(() => _isGoogleLoading = true);

    try {
      final result = await _authService.signInWithGoogle();

      if (!mounted) return;

      if (!result['success']) {
        _showErrorSnackBar(result['error'] ?? AppStrings.somethingWentWrong);
      } else {
        // ✅ SUCCESS → Pop all routes and let AuthWrapper handle navigation
        if (mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      }
    } catch (_) {
      _showErrorSnackBar(AppStrings.somethingWentWrong);
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  void _navigateToLogin() {
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  void _showErrorSnackBar(String message) {
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
    return Scaffold(
      backgroundColor: ThemeColors.bg(context),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              children: [
                const SizedBox(height: 40),
                _buildLogo(),
                const SizedBox(height: 24),
                _buildWelcomeText(),
                const SizedBox(height: 36),
                _buildRegisterForm(),
                const SizedBox(height: 16),
                _buildTermsCheckbox(),
                const SizedBox(height: 24),
                _buildSignUpButton(),
                const SizedBox(height: 28),
                _buildDivider(),
                const SizedBox(height: 28),
                _buildGoogleSignUp(),
                const SizedBox(height: 36),
                _buildLoginLink(),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// ---------------- UI COMPONENTS (UNCHANGED) ----------------

  Widget _buildLogo() {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Icon(
        Icons.agriculture,
        size: 40,
        color: AppColors.backgroundDark,
      ),
    );
  }

  Widget _buildWelcomeText() {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        Text(
          l10n.t('Create Account'),
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: ThemeColors.textPrimary(context),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.t('Start monitoring your farm with smart\nIoT solutions today.'),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: ThemeColors.textSecondary(context).withOpacity(0.7),
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildRegisterForm() {
    final l10n = AppLocalizations.of(context);
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(l10n.t('Full Name')),
          _nameField(),
          const SizedBox(height: 18),
          _label(l10n.t('Email address')),
          _emailField(),
          const SizedBox(height: 18),
          _label(l10n.t('Password')),
          _passwordField(),
          const SizedBox(height: 18),
          _label(l10n.t('Confirm Password')),
          _confirmPasswordField(),
        ],
      ),
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: ThemeColors.textPrimary(context),
        ),
      ),
    );
  }

  Widget _nameField() {
    final l10n = AppLocalizations.of(context);
    return TextFormField(
      controller: _nameController,
      style: TextStyle(color: ThemeColors.textPrimary(context)),
      decoration: _inputDecoration(
        l10n.t('Enter your full name'),
        Icons.person_outline,
      ),
      validator: (value) {
        if (value == null || value.isEmpty) return l10n.t(AppStrings.fieldRequired);
        if (value.length < 2) return l10n.t('Name must be at least 2 characters');
        return null;
      },
    );
  }

  Widget _emailField() {
    final l10n = AppLocalizations.of(context);
    return TextFormField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      style: TextStyle(color: ThemeColors.textPrimary(context)),
      decoration: _inputDecoration(l10n.t('farmer@example.com'), Icons.email_outlined),
      validator: (value) {
        if (value == null || value.isEmpty) return l10n.t(AppStrings.fieldRequired);
        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
          return l10n.t(AppStrings.invalidEmail);
        }
        return null;
      },
    );
  }

  Widget _passwordField() {
    final l10n = AppLocalizations.of(context);
    return TextFormField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      style: TextStyle(color: ThemeColors.textPrimary(context)),
      decoration: _inputDecoration(
        l10n.t('Create a strong password'),
        Icons.lock_outline,
        suffix: IconButton(
          icon: Icon(
            _obscurePassword ? Icons.visibility : Icons.visibility_off,
            color: ThemeColors.textSecondary(context).withOpacity(0.5),
          ),
          onPressed: () {
            setState(() => _obscurePassword = !_obscurePassword);
          },
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) return l10n.t(AppStrings.fieldRequired);
        if (value.length < 6) return l10n.t(AppStrings.invalidPassword);
        return null;
      },
    );
  }

  Widget _confirmPasswordField() {
    final l10n = AppLocalizations.of(context);
    return TextFormField(
      controller: _confirmPasswordController,
      obscureText: _obscureConfirmPassword,
      style: TextStyle(color: ThemeColors.textPrimary(context)),
      decoration: _inputDecoration(
        l10n.t('Re-enter your password'),
        Icons.lock_outline,
        suffix: IconButton(
          icon: Icon(
            _obscureConfirmPassword ? Icons.visibility : Icons.visibility_off,
            color: ThemeColors.textSecondary(context).withOpacity(0.5),
          ),
          onPressed: () {
            setState(() => _obscureConfirmPassword = !_obscureConfirmPassword);
          },
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) return l10n.t(AppStrings.fieldRequired);
        if (value != _passwordController.text) {
          return l10n.t(AppStrings.passwordsDoNotMatch);
        }
        return null;
      },
    );
  }

  InputDecoration _inputDecoration(
    String hint,
    IconData icon, {
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: ThemeColors.textSecondary(context).withOpacity(0.3)),
      prefixIcon: Icon(icon, color: ThemeColors.textSecondary(context).withOpacity(0.5)),
      suffixIcon: suffix,
      filled: true,
      fillColor: ThemeColors.surface(context),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: ThemeColors.border(context)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: ThemeColors.border(context)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.error),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  Widget _buildTermsCheckbox() {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        Checkbox(
          value: _acceptedTerms,
          onChanged: (value) {
            setState(() => _acceptedTerms = value ?? false);
          },
          activeColor: AppColors.primary,
        ),
        Expanded(
          child: Text(
            l10n.t('I agree to the Terms & Conditions and Privacy Policy'),
            style: TextStyle(color: ThemeColors.textSecondary(context).withOpacity(0.7)),
          ),
        ),
      ],
    );
  }

  Widget _buildSignUpButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _registerWithEmail,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.backgroundDark,
        ),
        child: _isLoading
            ? const CircularProgressIndicator()
            : Text(AppLocalizations.of(context).t('Create Account')),
      ),
    );
  }

  Widget _buildDivider() {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        Expanded(child: Container(height: 1, color: ThemeColors.border(context))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            l10n.t('Or sign up with'),
            style: TextStyle(color: ThemeColors.textSecondary(context)),
          ),
        ),
        Expanded(child: Container(height: 1, color: ThemeColors.border(context))),
      ],
    );
  }

  Widget _buildGoogleSignUp() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        onPressed: _isGoogleLoading ? null : _signUpWithGoogle,
        child: _isGoogleLoading
            ? const CircularProgressIndicator()
            : Text(AppLocalizations.of(context).t('Sign up with Google')),
      ),
    );
  }

  Widget _buildLoginLink() {
    final l10n = AppLocalizations.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          l10n.t('Already have an account? '),
          style: TextStyle(color: ThemeColors.textSecondary(context).withOpacity(0.7)),
        ),
        GestureDetector(
          onTap: _navigateToLogin,
          child: Text(
            l10n.t('Sign in'),
            style: const TextStyle(color: AppColors.primary),
          ),
        ),
      ],
    );
  }
}
