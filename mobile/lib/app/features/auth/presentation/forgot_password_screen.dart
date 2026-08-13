import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/api/api_endpoints.dart';
import '../../../core/api/dio_client.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../common/widgets/app_logo.dart';
import '../../common/widgets/custom_button.dart';
import '../../common/widgets/custom_text_field.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Forgot Password — 3-step Gmail-style flow
//
//  Step 1: Enter email  → POST /forgot-password (sends/logs reset token)
//  Step 2: Enter token  → (validates locally — moves to step 3)
//  Step 3: New password → POST /reset-password  (token + new password)
// ─────────────────────────────────────────────────────────────────────────────

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState
    extends ConsumerState<ForgotPasswordScreen>
    with SingleTickerProviderStateMixin {
  int _step = 1; // 1 = email, 2 = token, 3 = new password, 4 = done

  // Step 1
  final _emailFormKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();

  // Step 2
  final _tokenFormKey = GlobalKey<FormState>();
  final _tokenCtrl = TextEditingController();

  // Step 3
  final _pwFormKey = GlobalKey<FormState>();
  final _newPwCtrl = TextEditingController();
  final _confirmPwCtrl = TextEditingController();
  bool _showNew = false;
  bool _showConfirm = false;

  bool _loading = false;

  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();
    _fadeIn = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _tokenCtrl.dispose();
    _newPwCtrl.dispose();
    _confirmPwCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  void _animateStep(int next) {
    _fadeCtrl.reset();
    setState(() => _step = next);
    _fadeCtrl.forward();
  }

  // ── Step 1: Send reset email ───────────────────────────────────────────────
  Future<void> _submitEmail() async {
    if (!_emailFormKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await dioClient.post(
        ApiEndpoints.forgotPassword,
        data: {'email': _emailCtrl.text.trim()},
      );
      if (mounted) _animateStep(2);
    } catch (e) {
      if (mounted) _showError(AuthService.formatError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Step 2: Validate token (just advance; real validation happens on step 3)
  void _submitToken() {
    if (!_tokenFormKey.currentState!.validate()) return;
    _animateStep(3);
  }

  // ── Step 3: Reset password ─────────────────────────────────────────────────
  Future<void> _submitNewPassword() async {
    if (!_pwFormKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await dioClient.post(
        ApiEndpoints.resetPassword,
        data: {
          'token': _tokenCtrl.text.trim(),
          'password': _newPwCtrl.text,
        },
      );
      if (mounted) _animateStep(4);
    } catch (e) {
      if (mounted) _showError(AuthService.formatError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.error_outline, color: Colors.white, size: 18),
          const SizedBox(width: 10),
          Expanded(
              child: Text(msg,
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 13))),
        ]),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: Stack(
        children: [
          // Gradient header decoration
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 220,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFEEF2FF), AppColors.white],
                ),
              ),
            ),
          ),

          SafeArea(
            child: FadeTransition(
              opacity: _fadeIn,
              child: Center(
                child: SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Center(child: AppLogo(size: 72)),
                        const SizedBox(height: 20),

                        // Step indicator
                        if (_step < 4) ...[
                          _StepIndicator(currentStep: _step, totalSteps: 3),
                          const SizedBox(height: 24),
                        ],

                        Text(
                          _stepTitle(),
                          textAlign: TextAlign.center,
                          style: GoogleFonts.fraunces(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: AppColors.navy,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _stepSubtitle(),
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                              fontSize: 13,
                              color: AppColors.slate500,
                              height: 1.5),
                        ),
                        const SizedBox(height: 28),

                        // ── Form card ────────────────────────────────────────
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: AppColors.slate200),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.navy.withAlpha(12),
                                blurRadius: 24,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: _buildStepContent(),
                        ),

                        const SizedBox(height: 24),
                        Center(
                          child: TextButton.icon(
                            onPressed: () => context.go('/login'),
                            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                                size: 13, color: AppColors.blue),
                            label: Text(
                              'Back to login',
                              style: GoogleFonts.inter(
                                  color: AppColors.blue,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Step content builder
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildStepContent() {
    switch (_step) {
      case 1:
        return _buildStep1();
      case 2:
        return _buildStep2();
      case 3:
        return _buildStep3();
      default:
        return _buildSuccess();
    }
  }

  // Step 1 — Email
  Widget _buildStep1() {
    return Form(
      key: _emailFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CustomTextField(
            label: 'Email address',
            hint: 'you@example.com',
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            prefixIcon: Icons.mail_outline_rounded,
            validator: (v) {
              if (v == null || !v.contains('@')) {
                return 'Enter a valid email address';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          CustomButton(
            text: 'Send reset link',
            isLoading: _loading,
            onPressed: _submitEmail,
          ),
        ],
      ),
    );
  }

  // Step 2 — Token
  Widget _buildStep2() {
    return Form(
      key: _tokenFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Info banner
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.blue.withAlpha(10),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.blue.withAlpha(30)),
            ),
            child: Row(
              children: [
                const Icon(Icons.mail_outline_rounded,
                    size: 16, color: AppColors.blue),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'We\'ve sent a reset link to ${_emailCtrl.text.trim()}. '
                    'Copy the token from the link (after ?token=).',
                    style: GoogleFonts.inter(
                        fontSize: 12, color: AppColors.blue, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          CustomTextField(
            label: 'Reset Token',
            hint: 'Paste token from your email link',
            controller: _tokenCtrl,
            prefixIcon: Icons.vpn_key_rounded,
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return 'Please enter the reset token';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          CustomButton(
            text: 'Verify Token',
            isLoading: false,
            onPressed: _submitToken,
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: _submitEmail,
              child: Text(
                'Resend email',
                style: GoogleFonts.inter(
                    fontSize: 13, color: AppColors.slate500),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Step 3 — New password
  Widget _buildStep3() {
    return Form(
      key: _pwFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PwField(
            controller: _newPwCtrl,
            label: 'New Password',
            hint: 'At least 6 characters',
            show: _showNew,
            onToggle: () => setState(() => _showNew = !_showNew),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Password is required';
              if (v.length < 6) return 'Minimum 6 characters';
              return null;
            },
          ),
          const SizedBox(height: 16),
          _PwField(
            controller: _confirmPwCtrl,
            label: 'Confirm Password',
            hint: 'Repeat your new password',
            show: _showConfirm,
            onToggle: () => setState(() => _showConfirm = !_showConfirm),
            validator: (v) {
              if (v != _newPwCtrl.text) return 'Passwords do not match';
              return null;
            },
          ),
          const SizedBox(height: 24),
          CustomButton(
            text: 'Reset Password',
            isLoading: _loading,
            onPressed: _submitNewPassword,
          ),
        ],
      ),
    );
  }

  // Success
  Widget _buildSuccess() {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: AppColors.success.withAlpha(15),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_circle_outline_rounded,
              color: AppColors.success, size: 36),
        ),
        const SizedBox(height: 16),
        Text(
          'Password reset!',
          style: GoogleFonts.fraunces(
              fontWeight: FontWeight.w700, color: AppColors.navy, fontSize: 20),
        ),
        const SizedBox(height: 8),
        Text(
          'Your password has been updated. You can now log in with your new password.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(color: AppColors.slate500, fontSize: 13, height: 1.5),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: () => context.go('/login'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.navy,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: Text('Go to Login',
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: Colors.white)),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────────────────

  String _stepTitle() {
    switch (_step) {
      case 1: return 'Forgot password?';
      case 2: return 'Check your email';
      case 3: return 'Create new password';
      default: return 'All done!';
    }
  }

  String _stepSubtitle() {
    switch (_step) {
      case 1:
        return 'Enter your email and we\'ll send reset instructions.';
      case 2:
        return 'Enter the token from the reset link in your inbox.';
      case 3:
        return 'Choose a strong password you haven\'t used before.';
      default:
        return 'Your account is secure with your new password.';
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step Indicator
// ─────────────────────────────────────────────────────────────────────────────

class _StepIndicator extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  const _StepIndicator({required this.currentStep, required this.totalSteps});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(totalSteps * 2 - 1, (i) {
        if (i.isOdd) {
          // Connector line
          final stepLeft = (i ~/ 2) + 1;
          final active = currentStep > stepLeft;
          return Expanded(
            child: Container(
              height: 2,
              color: active ? AppColors.blue : AppColors.slate200,
            ),
          );
        }
        final step = (i ~/ 2) + 1;
        final done = currentStep > step;
        final current = currentStep == step;
        return Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: done
                ? AppColors.success
                : current
                    ? AppColors.blue
                    : AppColors.slate200,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: done
                ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                : Text(
                    '$step',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: current ? Colors.white : AppColors.slate500,
                    ),
                  ),
          ),
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Password field helper
// ─────────────────────────────────────────────────────────────────────────────

class _PwField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final bool show;
  final VoidCallback onToggle;
  final String? Function(String?) validator;

  const _PwField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.show,
    required this.onToggle,
    required this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.slate700)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          obscureText: !show,
          validator: validator,
          style: GoogleFonts.inter(fontSize: 14, color: AppColors.navy),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle:
                GoogleFonts.inter(fontSize: 13, color: AppColors.slate400),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            prefixIcon: const Icon(Icons.lock_outline_rounded,
                size: 18, color: AppColors.slate400),
            suffixIcon: IconButton(
              icon: Icon(
                show ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                size: 18,
                color: AppColors.slate400,
              ),
              onPressed: onToggle,
            ),
            filled: true,
            fillColor: AppColors.slate50,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.slate200)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.slate200)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: AppColors.blue, width: 1.5)),
            errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.error)),
          ),
        ),
      ],
    );
  }
}
