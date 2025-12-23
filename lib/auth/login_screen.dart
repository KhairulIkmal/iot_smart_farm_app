import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../core/constants.dart';
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
      }
      // ✅ DO NOTHING on success
      // AuthWrapper in main.dart will auto redirect
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
      }
      // ✅ DO NOTHING on success
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
      _showErrorSnackBar('Please enter your email address first');
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
      backgroundColor: AppColors.backgroundDark,
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
    return Column(
      children: [
        const Text(
          'Welcome Back',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Monitor your crops and control irrigation from\nanywhere.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: Colors.white.withOpacity(0.7),
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
    return TextFormField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      style: const TextStyle(color: Colors.white),
      decoration: _inputDecoration('Email address', 'farmer@example.com'),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return AppStrings.fieldRequired;
        }
        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
          return AppStrings.invalidEmail;
        }
        return null;
      },
    );
  }

  Widget _passwordField() {
    return TextFormField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      style: const TextStyle(color: Colors.white),
      decoration: _inputDecoration(
        'Password',
        '••••••••',
        suffix: IconButton(
          icon: Icon(
            _obscurePassword ? Icons.visibility : Icons.visibility_off,
            color: Colors.white.withOpacity(0.5),
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
          return AppStrings.fieldRequired;
        }
        if (value.length < 6) {
          return AppStrings.invalidPassword;
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
      hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
      filled: true,
      fillColor: AppColors.surfaceDark,
      suffixIcon: suffix,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.borderDark),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.borderDark),
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
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        onPressed: _forgotPassword,
        child: const Text(
          'Forgot password?',
          style: TextStyle(
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
            : const Text('Sign in'),
      ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(child: Container(height: 1, color: AppColors.borderDark)),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Or continue with',
            style: TextStyle(color: Colors.white54),
          ),
        ),
        Expanded(child: Container(height: 1, color: AppColors.borderDark)),
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
            : const Text('Sign in with Google'),
      ),
    );
  }

  Widget _buildCreateAccountLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          "Don't have an account? ",
          style: TextStyle(color: Colors.white70),
        ),
        GestureDetector(
          onTap: _navigateToRegister,
          child: const Text(
            'Create an account',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }
}
