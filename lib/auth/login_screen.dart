import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../core/constants.dart';
import '../core/app_localizations.dart';
import 'register_screen.dart';
import 'auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();

  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// -------------------------------
  /// EMAIL SIGN IN
  /// -------------------------------
  Future<void> _signInWithEmail() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final result = await _authService.signInWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

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
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// -------------------------------
  /// GOOGLE SIGN IN
  /// -------------------------------
  Future<void> _signInWithGoogle() async {
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

  /// -------------------------------
  /// FORGOT PASSWORD
  /// -------------------------------
  Future<void> _forgotPassword() async {
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      final l10n = AppLocalizations.of(context);
      _showErrorSnackBar(l10n.t('Please enter your email address first'));
      return;
    }

    try {
      final result = await _authService.sendPasswordResetEmail(email);

      if (!mounted) return;

      if (result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(AppStrings.passwordResetEmailSent),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      } else {
        _showErrorSnackBar(result['error'] ?? AppStrings.somethingWentWrong);
      }
    } catch (_) {
      _showErrorSnackBar(AppStrings.somethingWentWrong);
    }
  }

  /// -------------------------------
  /// NAVIGATION
  /// -------------------------------
  void _navigateToRegister() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const RegisterScreen()));
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
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 60),
              _buildLogo(),
              const SizedBox(height: 32),
              _buildWelcomeText(),
              const SizedBox(height: 48),
              _buildLoginForm(),
              const SizedBox(height: 16),
              _buildForgotPassword(),
              const SizedBox(height: 24),
              _buildSignInButton(),
              const SizedBox(height: 32),
              _buildDivider(),
              const SizedBox(height: 32),
              _buildGoogleSignIn(),
              const SizedBox(height: 48),
              _buildCreateAccountLink(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  /// -------------------------------
  /// UI COMPONENTS (UNCHANGED)
  /// -------------------------------
  Widget _buildLogo() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Icon(
        Icons.agriculture,
        size: 48,
        color: AppColors.backgroundDark,
      ),
    );
  }

  Widget _buildWelcomeText() {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        Text(
          l10n.t('Welcome Back'),
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: ThemeColors.textPrimary(context),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.t('Monitor your crops and control irrigation from\nanywhere.'),
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

  Widget _buildLoginForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [_emailField(), const SizedBox(height: 20), _passwordField()],
      ),
    );
  }

  Widget _emailField() {
    final l10n = AppLocalizations.of(context);
    return TextFormField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      style: TextStyle(color: ThemeColors.textPrimary(context)),
      decoration: _inputDecoration(l10n.t('Email address'), l10n.t('farmer@example.com')),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return l10n.t(AppStrings.fieldRequired);
        }
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
        l10n.t('Password'),
        '••••••••',
        suffix: IconButton(
          icon: Icon(
            _obscurePassword ? Icons.visibility : Icons.visibility_off,
            color: ThemeColors.textSecondary(context).withOpacity(0.5),
          ),
          onPressed: () {
            setState(() {
              _obscurePassword = !_obscurePassword;
            });
          },
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return l10n.t(AppStrings.fieldRequired);
        }
        if (value.length < 6) {
          return l10n.t(AppStrings.invalidPassword);
        }
        return null;
      },
    );
  }

  InputDecoration _inputDecoration(
    String label,
    String hint, {
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: ThemeColors.textSecondary(context).withOpacity(0.3)),
      filled: true,
      fillColor: ThemeColors.surface(context),
      suffixIcon: suffix,
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

  Widget _buildForgotPassword() {
    final l10n = AppLocalizations.of(context);
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        onPressed: _forgotPassword,
        child: Text(
          l10n.t('Forgot password?'),
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.primary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildSignInButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _signInWithEmail,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.backgroundDark,
        ),
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              )
            : Text(AppLocalizations.of(context).t('Sign in')),
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
            l10n.t('Or continue with'),
            style: TextStyle(color: ThemeColors.textSecondary(context)),
          ),
        ),
        Expanded(child: Container(height: 1, color: ThemeColors.border(context))),
      ],
    );
  }

  Widget _buildGoogleSignIn() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        onPressed: _isGoogleLoading ? null : _signInWithGoogle,
        child: _isGoogleLoading
            ? const CircularProgressIndicator()
            : Text(AppLocalizations.of(context).t('Sign in with Google')),
      ),
    );
  }

  Widget _buildCreateAccountLink() {
    final l10n = AppLocalizations.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          l10n.t("Don't have an account? "),
          style: TextStyle(color: ThemeColors.textSecondary(context)),
        ),
        GestureDetector(
          onTap: _navigateToRegister,
          child: Text(
            l10n.t('Create an account'),
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }
}
