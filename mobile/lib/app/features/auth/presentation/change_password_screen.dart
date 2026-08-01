import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/api/api_endpoints.dart';
import '../../../core/api/dio_client.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../common/widgets/shared_widgets.dart';

class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _oldCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _loading = false;
  bool _showOld = false;
  bool _showNew = false;
  bool _showConfirm = false;

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
    _oldCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await dioClient.post(ApiEndpoints.changePassword, data: {
        'current_password': _oldCtrl.text,
        'new_password': _newCtrl.text,
        'confirm_password': _confirmCtrl.text,
      });
      if (!mounted) return;
      // Clear fields for security
      _oldCtrl.clear();
      _newCtrl.clear();
      _confirmCtrl.clear();
      showToast(context, 'Password updated successfully ✓');
    } catch (e) {
      if (mounted) {
        showToast(context, AuthService.formatError(e), isError: true);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
            height: 200,
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
              child: Column(
                children: [
                  // App bar
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new_rounded,
                              color: AppColors.navy, size: 18),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        Text(
                          'Change Password',
                          style: GoogleFonts.fraunces(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppColors.navy,
                          ),
                        ),
                      ],
                    ),
                  ),

                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Icon + heading
                          Center(
                            child: Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                gradient: AppColors.blueVioletGradient,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Icon(Icons.lock_reset_rounded,
                                  color: Colors.white, size: 36),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Update your password',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.fraunces(
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                              color: AppColors.navy,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Enter your current password, then choose a new one.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                                fontSize: 13,
                                color: AppColors.slate500,
                                height: 1.5),
                          ),
                          const SizedBox(height: 32),

                          // Form card
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: AppColors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppColors.slate200),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.navy.withAlpha(10),
                                  blurRadius: 20,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Current password
                                  _PasswordField(
                                    controller: _oldCtrl,
                                    label: 'Current Password',
                                    hint: 'Enter your current password',
                                    showPassword: _showOld,
                                    onToggle: () =>
                                        setState(() => _showOld = !_showOld),
                                    validator: (v) {
                                      if (v == null || v.isEmpty) {
                                        return 'Current password is required';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),

                                  // Divider with label
                                  Row(children: [
                                    Expanded(
                                        child: Divider(
                                            color: AppColors.slate200,
                                            height: 1)),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12),
                                      child: Text('NEW PASSWORD',
                                          style: GoogleFonts.inter(
                                              fontSize: 9,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 1.5,
                                              color: AppColors.slate400)),
                                    ),
                                    Expanded(
                                        child: Divider(
                                            color: AppColors.slate200,
                                            height: 1)),
                                  ]),
                                  const SizedBox(height: 16),

                                  // New password
                                  _PasswordField(
                                    controller: _newCtrl,
                                    label: 'New Password',
                                    hint: 'At least 6 characters',
                                    showPassword: _showNew,
                                    onToggle: () =>
                                        setState(() => _showNew = !_showNew),
                                    validator: (v) {
                                      if (v == null || v.isEmpty) {
                                        return 'New password is required';
                                      }
                                      if (v.length < 6) {
                                        return 'Must be at least 6 characters';
                                      }
                                      if (v == _oldCtrl.text) {
                                        return 'New password must differ from current';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),

                                  // Confirm password
                                  _PasswordField(
                                    controller: _confirmCtrl,
                                    label: 'Confirm New Password',
                                    hint: 'Repeat your new password',
                                    showPassword: _showConfirm,
                                    onToggle: () => setState(
                                        () => _showConfirm = !_showConfirm),
                                    validator: (v) {
                                      if (v != _newCtrl.text) {
                                        return 'Passwords do not match';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 24),

                                  // Strength hints
                                  _PasswordStrengthHints(
                                      password: _newCtrl.text),
                                  const SizedBox(height: 24),

                                  // Submit button
                                  SizedBox(
                                    height: 50,
                                    child: ElevatedButton(
                                      onPressed: _loading ? null : _submit,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.navy,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(14),
                                        ),
                                        elevation: 0,
                                      ),
                                      child: _loading
                                          ? const SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                  color: Colors.white,
                                                  strokeWidth: 2),
                                            )
                                          : Text(
                                              'Update Password',
                                              style: GoogleFonts.inter(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 20),
                          // Security note
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.blue.withAlpha(8),
                              borderRadius: BorderRadius.circular(12),
                              border:
                                  Border.all(color: AppColors.blue.withAlpha(30)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.info_outline_rounded,
                                    size: 16, color: AppColors.blue),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'You will stay logged in after changing your password.',
                                    style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: AppColors.blue,
                                        height: 1.4),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Password Field Widget
// ─────────────────────────────────────────────────────────────────────────────

class _PasswordField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final bool showPassword;
  final VoidCallback onToggle;
  final String? Function(String?) validator;

  const _PasswordField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.showPassword,
    required this.onToggle,
    required this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.slate700,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          obscureText: !showPassword,
          style: GoogleFonts.inter(fontSize: 14, color: AppColors.navy),
          validator: validator,
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
                showPassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                size: 18,
                color: AppColors.slate400,
              ),
              onPressed: onToggle,
            ),
            filled: true,
            fillColor: AppColors.slate50,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.slate200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.slate200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: AppColors.blue, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.error),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Password Strength Hints
// ─────────────────────────────────────────────────────────────────────────────

class _PasswordStrengthHints extends StatelessWidget {
  final String password;
  const _PasswordStrengthHints({required this.password});

  @override
  Widget build(BuildContext context) {
    final hasLength = password.length >= 6;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PASSWORD REQUIREMENTS',
          style: GoogleFonts.inter(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
            color: AppColors.slate400,
          ),
        ),
        const SizedBox(height: 8),
        _Hint(met: hasLength, text: 'At least 6 characters'),
      ],
    );
  }
}

class _Hint extends StatelessWidget {
  final bool met;
  final String text;
  const _Hint({required this.met, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(
            met ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            size: 14,
            color: met ? AppColors.success : AppColors.slate400,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: met ? AppColors.success : AppColors.slate500,
            ),
          ),
        ],
      ),
    );
  }
}
