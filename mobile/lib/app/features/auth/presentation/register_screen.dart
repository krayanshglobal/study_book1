import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../common/widgets/app_logo.dart';
import '../../common/widgets/custom_button.dart';
import '../../common/widgets/custom_text_field.dart';
import '../../common/widgets/shared_widgets.dart';
import '../providers/auth_provider.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _referralCtrl = TextEditingController();

  String? _classLevel;
  bool _obscure = true;
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeIn;

  // OTP Verification State
  bool _phoneVerified = false;
  String? _verificationToken;
  String _verifiedPhone = '';
  bool _sendingOtp = false;

  final _classes = ['8', '9', '10'];

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeIn = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    _referralCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  void _onPhoneChanged(String val) {
    if (_phoneVerified && val.trim() != _verifiedPhone) {
      setState(() {
        _phoneVerified = false;
        _verificationToken = null;
        _verifiedPhone = '';
      });
    }
  }

  Future<void> _startPhoneVerification() async {
    final rawPhone = _phoneCtrl.text.trim();
    final digits = rawPhone.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 10) {
      showToast(context, 'Enter a valid 10-digit mobile number', isError: true);
      return;
    }

    setState(() => _sendingOtp = true);
    final res = await ref.read(authProvider.notifier).sendMobileOtp(rawPhone);
    if (!mounted) return;
    setState(() => _sendingOtp = false);

    if (res != null && res['ok'] == true) {
      if (res['exists'] == true) {
        showToast(context, 'This mobile number is already registered. Please sign in.', isError: true);
        return;
      }

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => _RegistrationOtpSheet(
          phone: rawPhone,
          onVerified: (token) {
            Navigator.pop(ctx);
            setState(() {
              _phoneVerified = true;
              _verificationToken = token;
              _verifiedPhone = rawPhone;
            });
            showToast(context, 'Mobile number verified successfully!');
          },
        ),
      );
    } else {
      final err = ref.read(authProvider).error ?? 'Failed to send OTP';
      showToast(context, err, isError: true);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_phoneVerified) {
      showToast(context, 'Please verify your mobile number first.', isError: true);
      return;
    }

    final ok = await ref.read(authProvider.notifier).register(
          name: _nameCtrl.text.trim(),
          email: _emailCtrl.text.trim(),
          phone: _phoneCtrl.text.trim(),
          password: _passwordCtrl.text,
          classLevel: _classLevel,
          referralCode: _referralCtrl.text.trim().isEmpty ? null : _referralCtrl.text.trim(),
          verificationToken: _verificationToken,
        );
    if (!mounted) return;
    if (ok) {
      context.go('/dashboard');
    } else {
      final err = ref.read(authProvider).error ?? 'Registration failed';
      showToast(context, err, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: AppColors.white,
      body: Stack(
        children: [
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
                  colors: [
                    Color(0xFFEEF2FF),
                    AppColors.white,
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: FadeTransition(
              opacity: _fadeIn,
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Center(child: AppLogo(size: 80)),
                          const SizedBox(height: 32),

                          Text(
                            'Create account',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.fraunces(
                              fontSize: 32,
                              fontWeight: FontWeight.w700,
                              color: AppColors.navy,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Join StudyBook and start learning smarter.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                                fontSize: 14,
                                color: AppColors.slate500,
                                height: 1.5),
                          ),
                          const SizedBox(height: 36),

                          // ── FORM CARD ────────────────────────────────
                          Container(
                            padding: const EdgeInsets.all(28),
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
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                CustomTextField(
                                  label: 'Full name',
                                  hint: 'Your full name',
                                  controller: _nameCtrl,
                                  prefixIcon: Icons.person_outline_rounded,
                                  textCapitalization: TextCapitalization.words,
                                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                                ),
                                const SizedBox(height: 16),
                                CustomTextField(
                                  label: 'Email address',
                                  hint: 'you@example.com',
                                  controller: _emailCtrl,
                                  keyboardType: TextInputType.emailAddress,
                                  prefixIcon: Icons.mail_outline_rounded,
                                  validator: (v) {
                                    if (v == null || !v.contains('@')) {
                                      return 'Enter a valid email';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),

                                // ── PHONE NUMBER WITH VERIFY / VERIFIED BADGE ──
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Expanded(
                                          child: CustomTextField(
                                            label: 'Phone number',
                                            hint: '10-digit mobile number',
                                            controller: _phoneCtrl,
                                            readOnly: _phoneVerified,
                                            keyboardType: TextInputType.phone,
                                            prefixIcon: Icons.phone_outlined,
                                            onChanged: _onPhoneChanged,
                                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Phone is required' : null,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Padding(
                                          padding: const EdgeInsets.only(bottom: 2),
                                          child: _phoneVerified
                                              ? Container(
                                                  height: 48,
                                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.emerald.withAlpha(25),
                                                    borderRadius: BorderRadius.circular(14),
                                                    border: Border.all(color: AppColors.emerald),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      const Icon(Icons.check_circle_rounded, color: AppColors.emerald, size: 16),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        'Verified',
                                                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.emerald),
                                                      ),
                                                    ],
                                                  ),
                                                )
                                              : SizedBox(
                                                  height: 48,
                                                  child: ElevatedButton(
                                                    onPressed: _sendingOtp ? null : _startPhoneVerification,
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: AppColors.violet,
                                                      foregroundColor: AppColors.white,
                                                      elevation: 0,
                                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                                      padding: const EdgeInsets.symmetric(horizontal: 14),
                                                    ),
                                                    child: _sendingOtp
                                                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                                        : Text('Verify', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700)),
                                                  ),
                                                ),
                                        ),
                                      ],
                                    ),
                                    if (_phoneVerified) ...[
                                      const SizedBox(height: 4),
                                      GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _phoneVerified = false;
                                            _verificationToken = null;
                                            _verifiedPhone = '';
                                          });
                                        },
                                        child: Text(
                                          'Edit number',
                                          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.blue),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),

                                const SizedBox(height: 16),
                                CustomTextField(
                                  label: 'Password',
                                  hint: 'Min. 6 characters',
                                  controller: _passwordCtrl,
                                  obscureText: _obscure,
                                  prefixIcon: Icons.lock_outline_rounded,
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                      color: AppColors.slate400,
                                      size: 20,
                                    ),
                                    onPressed: () => setState(() => _obscure = !_obscure),
                                  ),
                                  validator: (v) {
                                    if (v == null || v.length < 6) {
                                      return 'Password must be at least 6 characters';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),

                                DropdownButtonFormField<String>(
                                  initialValue: _classLevel,
                                  decoration: InputDecoration(
                                    labelText: 'Class (optional)',
                                    filled: true,
                                    fillColor: AppColors.slate50,
                                    prefixIcon: const Icon(Icons.school_outlined, size: 20, color: AppColors.slate400),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.slate200)),
                                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.slate200)),
                                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.blue, width: 2)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                  ),
                                  hint: Text('Select class', style: GoogleFonts.inter(color: AppColors.slate400, fontSize: 14)),
                                  items: _classes
                                      .map((c) => DropdownMenuItem(
                                            value: c,
                                            child: Text('Class $c', style: GoogleFonts.inter(fontSize: 14)),
                                          ))
                                      .toList(),
                                  onChanged: (v) => setState(() => _classLevel = v),
                                ),
                                const SizedBox(height: 16),
                                CustomTextField(
                                  label: 'Referral code (optional)',
                                  hint: 'Enter referral code',
                                  controller: _referralCtrl,
                                  prefixIcon: Icons.card_giftcard_outlined,
                                ),
                                const SizedBox(height: 24),

                                CustomButton(
                                  text: _phoneVerified ? 'Create account' : 'Verify Phone to Continue',
                                  isLoading: state.isLoading,
                                  onPressed: _phoneVerified ? _submit : _startPhoneVerification,
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 28),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Already have an account? ',
                                style: GoogleFonts.inter(color: AppColors.slate500, fontSize: 14),
                              ),
                              GestureDetector(
                                onTap: () => context.go('/login'),
                                child: Text(
                                  'Sign in',
                                  style: GoogleFonts.inter(
                                    color: AppColors.blue,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
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
}

// ── REGISTRATION OTP SHEET ───────────────────────────────────────────────────
class _RegistrationOtpSheet extends ConsumerStatefulWidget {
  final String phone;
  final ValueChanged<String?> onVerified;
  const _RegistrationOtpSheet({required this.phone, required this.onVerified});

  @override
  ConsumerState<_RegistrationOtpSheet> createState() => _RegistrationOtpSheetState();
}

class _RegistrationOtpSheetState extends ConsumerState<_RegistrationOtpSheet> {
  final _otpCtrl = TextEditingController();
  bool _verifying = false;
  Timer? _timer;
  int _countdown = 30;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpCtrl.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _countdown = 30);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_countdown > 0) {
        if (mounted) setState(() => _countdown--);
      } else {
        t.cancel();
      }
    });
  }

  Future<void> _resendOtp() async {
    final res = await ref.read(authProvider.notifier).sendMobileOtp(widget.phone);
    if (!mounted) return;
    if (res != null && res['ok'] == true) {
      _startTimer();
      showToast(context, 'OTP resent successfully!');
    } else {
      final err = ref.read(authProvider).error ?? 'Failed to resend OTP';
      showToast(context, err, isError: true);
    }
  }

  Future<void> _verifyOtp() async {
    final otp = _otpCtrl.text.trim();
    if (otp.length != 6) {
      showToast(context, 'Enter 6-digit OTP code', isError: true);
      return;
    }

    setState(() => _verifying = true);
    final res = await ref.read(authProvider.notifier).verifyOtpForRegistration(
          phone: widget.phone,
          otp: otp,
        );
    if (!mounted) return;
    setState(() => _verifying = false);

    if (res != null && (res['verified'] == true || res['verification_token'] != null)) {
      final token = res['verification_token']?.toString();
      widget.onVerified(token);
    } else {
      final err = ref.read(authProvider).error ?? 'Invalid OTP code';
      showToast(context, err, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Verify your mobile number',
                style: GoogleFonts.fraunces(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: AppColors.slate400),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'OTP sent to: ${widget.phone}',
            style: GoogleFonts.inter(fontSize: 13, color: AppColors.slate500, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),

          CustomTextField(
            label: 'Enter 6-Digit OTP',
            hint: '123456',
            controller: _otpCtrl,
            keyboardType: TextInputType.number,
            prefixIcon: Icons.pin_outlined,
          ),
          const SizedBox(height: 20),

          CustomButton(
            text: 'Verify OTP',
            isLoading: _verifying,
            onPressed: _verifyOtp,
          ),

          const SizedBox(height: 14),

          Center(
            child: _countdown > 0
                ? Text(
                    'Resend in ${_countdown}s',
                    style: GoogleFonts.inter(fontSize: 12, color: AppColors.slate400, fontWeight: FontWeight.w600),
                  )
                : TextButton(
                    onPressed: _resendOtp,
                    child: Text('Resend OTP', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.blue)),
                  ),
          ),
        ],
      ),
    );
  }
}
