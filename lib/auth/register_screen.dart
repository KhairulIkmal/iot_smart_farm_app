import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../core/theme.dart';
import '../core/constants.dart';
import '../core/app_localizations.dart';
import 'auth_service.dart';
import 'login_screen.dart';
import 'permission_setup_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
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

  late final AnimationController _animCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.07),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
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
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const PermissionSetupScreen()),
        );
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
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: Stack(
        children: [
          _buildGlowOrbs(),
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: Column(
                  children: [
                    // Top nav
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                      child: Row(
                        children: [
                          _backButton(),
                          const SizedBox(width: 12),
                          Row(
                            children: [
                              Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF161b1d),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color:
                                        AppColors.primary.withOpacity(0.2),
                                    width: 1,
                                  ),
                                ),
                                padding: const EdgeInsets.all(5),
                                child: SvgPicture.asset(
                                    'assets/icons/agroezuran_icon_allmode.svg'),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'AgroEzuran',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Scrollable form
                    Expanded(
                      child: SingleChildScrollView(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 28),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 32),
                            _buildHeading(l10n),
                            const SizedBox(height: 32),
                            Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  _fieldLabel('Full Name'),
                                  const SizedBox(height: 9),
                                  _nameField(l10n),
                                  const SizedBox(height: 20),
                                  _fieldLabel('Email Address'),
                                  const SizedBox(height: 9),
                                  _emailField(l10n),
                                  const SizedBox(height: 20),
                                  _fieldLabel('Password'),
                                  const SizedBox(height: 9),
                                  _passwordField(l10n),
                                  const SizedBox(height: 20),
                                  _fieldLabel('Confirm Password'),
                                  const SizedBox(height: 9),
                                  _confirmPasswordField(l10n),
                                  const SizedBox(height: 22),
                                  _termsRow(l10n),
                                  const SizedBox(height: 30),
                                  _createAccountButton(l10n),
                                ],
                              ),
                            ),
                            const SizedBox(height: 36),
                            _loginLink(l10n),
                            const SizedBox(height: 36),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Background glow orbs ──────────────────────────────────
  Widget _buildGlowOrbs() {
    return Stack(
      children: [
        Positioned(
          top: -60,
          left: -80,
          child: Container(
            width: 280,
            height: 280,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.primary.withOpacity(0.11),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 80,
          right: -90,
          child: Container(
            width: 210,
            height: 210,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.primary.withOpacity(0.07),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ─── Back button ───────────────────────────────────────────
  Widget _backButton() {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
              color: Colors.white.withOpacity(0.1), width: 1),
        ),
        child: Icon(
          Icons.arrow_back_rounded,
          color: Colors.white.withOpacity(0.85),
          size: 20,
        ),
      ),
    );
  }

  // ─── Page heading ──────────────────────────────────────────
  Widget _buildHeading(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.t('Create Account'),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 36,
            fontWeight: FontWeight.w800,
            height: 1.05,
            letterSpacing: -1.0,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.t(
              'Start monitoring your farm with\nsmart IoT solutions today.'),
          style: TextStyle(
            color: Colors.white.withOpacity(0.48),
            fontSize: 15,
            height: 1.6,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  // ─── Field components ──────────────────────────────────────
  Widget _fieldLabel(String text) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 10.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.1,
        color: Colors.white.withOpacity(0.4),
      ),
    );
  }

  Widget _nameField(AppLocalizations l10n) {
    return TextFormField(
      controller: _nameController,
      textCapitalization: TextCapitalization.words,
      style: const TextStyle(
          color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500),
      decoration:
          _dec(hint: 'e.g. Ahmad Rizal', icon: Icons.person_outline_rounded),
      validator: (v) {
        if (v == null || v.isEmpty) return l10n.t(AppStrings.fieldRequired);
        if (v.trim().length < 2) {
          return l10n.t('Name must be at least 2 characters');
        }
        return null;
      },
    );
  }

  Widget _emailField(AppLocalizations l10n) {
    return TextFormField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      style: const TextStyle(
          color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500),
      decoration: _dec(
          hint: 'farmer@example.com',
          icon: Icons.alternate_email_rounded),
      validator: (v) => _validateEmail(v, l10n),
    );
  }

  String? _validateEmail(String? v, AppLocalizations l10n) {
    if (v == null || v.isEmpty) return l10n.t(AppStrings.fieldRequired);
    final email = v.trim().toLowerCase();
    if (!RegExp(r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$')
        .hasMatch(email)) {
      return 'Enter a valid email address';
    }
    final localPart = email.split('@').first;
    if (localPart.length < 2) return 'Enter a valid email address';
    final domain = email.split('@').last;
    if (_isDisposableDomain(domain)) {
      return 'Disposable or temporary emails are not allowed';
    }
    return null;
  }

  bool _isDisposableDomain(String domain) {
    const blocked = {
      'mailinator.com', 'trashmail.com', 'trashmail.at', 'trashmail.io',
      'trashmail.me', 'trashmail.net', 'trashmail.org',
      'guerrillamail.com', 'guerrillamail.net', 'guerrillamail.org',
      'guerrillamail.de', 'guerrillamail.biz', 'guerrillamail.info',
      'guerrillamailblock.com', 'grr.la', 'sharklasers.com',
      'spam4.me', 'spamgourmet.com',
      '10minutemail.com', '10minutemail.net', '10minemail.com',
      'yopmail.com', 'yopmail.fr', 'cool.fr.nf', 'jetable.fr.nf',
      'temp-mail.org', 'tempmail.com', 'tempmail.net', 'tempmail.de',
      'tempr.email', 'discard.email', 'dispostable.com',
      'throwaway.email', 'throwam.com',
      'fakeinbox.com', 'fakeinbox.net', 'mailnull.com',
      'maildrop.cc',
      'getnada.com', 'filzmail.com', 'zetmail.com', 'wegwerfmail.de',
      'spamfree24.org', 'spamfree.eu', 'spamoff.de', 'objectmail.com',
      'spam.la', 'binkmail.com', 'safetymail.info', 'mailexpire.com',
      'spamherelots.com', 'spamhereplease.com', 'spamthisplease.com',
      'spamtrail.com', 'spamtraps.nl',
      'example.com', 'example.net', 'example.org',
      'test.com', 'testing.com',
    };
    return blocked.contains(domain);
  }

  Widget _passwordField(AppLocalizations l10n) {
    return TextFormField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      style: const TextStyle(
          color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500),
      decoration: _dec(
        hint: 'Min. 6 characters',
        icon: Icons.lock_outline_rounded,
        suffix: IconButton(
          icon: Icon(
            _obscurePassword
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
            color: Colors.white.withOpacity(0.32),
            size: 20,
          ),
          onPressed: () =>
              setState(() => _obscurePassword = !_obscurePassword),
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
      style: const TextStyle(
          color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500),
      decoration: _dec(
        hint: 'Re-enter your password',
        icon: Icons.lock_outline_rounded,
        suffix: IconButton(
          icon: Icon(
            _obscureConfirmPassword
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
            color: Colors.white.withOpacity(0.32),
            size: 20,
          ),
          onPressed: () => setState(
              () => _obscureConfirmPassword = !_obscureConfirmPassword),
        ),
      ),
      validator: (v) {
        if (v == null || v.isEmpty) return l10n.t(AppStrings.fieldRequired);
        if (v != _passwordController.text) {
          return l10n.t(AppStrings.passwordsDoNotMatch);
        }
        return null;
      },
    );
  }

  Widget _termsRow(AppLocalizations l10n) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 22,
          height: 22,
          child: Checkbox(
            value: _acceptedTerms,
            onChanged: (v) =>
                setState(() => _acceptedTerms = v ?? false),
            activeColor: AppColors.primary,
            checkColor: const Color(0xFF0A1A0D),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(5)),
            side: BorderSide(
                color: Colors.white.withOpacity(0.25), width: 1.5),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            l10n.t(
                'I agree to the Terms & Conditions and Privacy Policy'),
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withOpacity(0.45),
              height: 1.45,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }

  Widget _createAccountButton(AppLocalizations l10n) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: _isLoading
            ? null
            : const LinearGradient(
                colors: [Color(0xFF2AFF5C), Color(0xFF0DBF2D)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        color: _isLoading ? AppColors.primary.withOpacity(0.35) : null,
        borderRadius: BorderRadius.circular(16),
        boxShadow: _isLoading
            ? null
            : [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.38),
                  blurRadius: 22,
                  offset: const Offset(0, 8),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isLoading ? null : _register,
          borderRadius: BorderRadius.circular(16),
          splashColor: Colors.white.withOpacity(0.12),
          child: Center(
            child: _isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text(
                    'Create Account',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0A1A0D),
                      letterSpacing: 0.3,
                    ),
                  ),
          ),
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
            color: Colors.white.withOpacity(0.42),
            fontWeight: FontWeight.w400,
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
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }

  // ─── Shared field decoration ───────────────────────────────
  InputDecoration _dec(
      {required String hint, required IconData icon, Widget? suffix}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
          color: Colors.white.withOpacity(0.2),
          fontSize: 14,
          fontWeight: FontWeight.w400),
      prefixIcon:
          Icon(icon, color: AppColors.primary.withOpacity(0.55), size: 20),
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white.withOpacity(0.07),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide:
            BorderSide(color: Colors.white.withOpacity(0.1), width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide:
            BorderSide(color: Colors.white.withOpacity(0.1), width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide:
            const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide:
            const BorderSide(color: AppColors.error, width: 1.5),
      ),
    );
  }
}
