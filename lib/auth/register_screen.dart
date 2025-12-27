import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../core/constants.dart';
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
      _showErrorSnackBar('Please accept the Terms & Conditions');
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
      backgroundColor: AppColors.backgroundDark,
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
    return Column(
      children: [
        const Text(
          'Create Account',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Start monitoring your farm with smart\nIoT solutions today.',
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

  Widget _buildRegisterForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('Full Name'),
          _nameField(),
          const SizedBox(height: 18),
          _label('Email address'),
          _emailField(),
          const SizedBox(height: 18),
          _label('Password'),
          _passwordField(),
          const SizedBox(height: 18),
          _label('Confirm Password'),
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
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _nameField() {
    return TextFormField(
      controller: _nameController,
      style: const TextStyle(color: Colors.white),
      decoration: _inputDecoration(
        'Enter your full name',
        Icons.person_outline,
      ),
      validator: (value) {
        if (value == null || value.isEmpty) return AppStrings.fieldRequired;
        if (value.length < 2) return 'Name must be at least 2 characters';
        return null;
      },
    );
  }

  Widget _emailField() {
    return TextFormField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      style: const TextStyle(color: Colors.white),
      decoration: _inputDecoration('farmer@example.com', Icons.email_outlined),
      validator: (value) {
        if (value == null || value.isEmpty) return AppStrings.fieldRequired;
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
        'Create a strong password',
        Icons.lock_outline,
        suffix: IconButton(
          icon: Icon(
            _obscurePassword ? Icons.visibility : Icons.visibility_off,
            color: Colors.white.withOpacity(0.5),
          ),
          onPressed: () {
            setState(() => _obscurePassword = !_obscurePassword);
          },
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) return AppStrings.fieldRequired;
        if (value.length < 6) return AppStrings.invalidPassword;
        return null;
      },
    );
  }

  Widget _confirmPasswordField() {
    return TextFormField(
      controller: _confirmPasswordController,
      obscureText: _obscureConfirmPassword,
      style: const TextStyle(color: Colors.white),
      decoration: _inputDecoration(
        'Re-enter your password',
        Icons.lock_outline,
        suffix: IconButton(
          icon: Icon(
            _obscureConfirmPassword ? Icons.visibility : Icons.visibility_off,
            color: Colors.white.withOpacity(0.5),
          ),
          onPressed: () {
            setState(() => _obscureConfirmPassword = !_obscureConfirmPassword);
          },
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) return AppStrings.fieldRequired;
        if (value != _passwordController.text) {
          return AppStrings.passwordsDoNotMatch;
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
      hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
      prefixIcon: Icon(icon, color: Colors.white.withOpacity(0.5)),
      suffixIcon: suffix,
      filled: true,
      fillColor: AppColors.surfaceDark,
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

  Widget _buildTermsCheckbox() {
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
            'I agree to the Terms & Conditions and Privacy Policy',
            style: TextStyle(color: Colors.white.withOpacity(0.7)),
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
            : const Text('Create Account'),
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
            'Or sign up with',
            style: TextStyle(color: Colors.white54),
          ),
        ),
        Expanded(child: Container(height: 1, color: AppColors.borderDark)),
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
            : const Text('Sign up with Google'),
      ),
    );
  }

  Widget _buildLoginLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Already have an account? ',
          style: TextStyle(color: Colors.white.withOpacity(0.7)),
        ),
        GestureDetector(
          onTap: _navigateToLogin,
          child: const Text(
            'Sign in',
            style: TextStyle(color: AppColors.primary),
          ),
        ),
      ],
    );
  }
}
