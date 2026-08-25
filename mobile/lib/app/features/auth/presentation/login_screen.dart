import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/models/user_model.dart';
import '../../common/widgets/app_logo.dart';
import '../../common/widgets/custom_button.dart';
import '../../common/widgets/custom_text_field.dart';
import '../../common/widgets/root_exit_pop_scope.dart';
import '../../common/widgets/shared_widgets.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeIn;

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
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await ref.read(authProvider.notifier).login(
          _emailCtrl.text.trim(),
          _passwordCtrl.text,
        );
    if (!mounted) return;
    if (ok) {
      final user = ref.read(authProvider).user!;
      debugPrint('[LOGIN DIAGNOSTICS] Login success for user: ${user.email}, role: ${user.role}');
      context.go(user.isAdmin ? '/admin' : '/dashboard');
    } else {
      final err = ref.read(authProvider).error ?? 'Invalid email or password';
      showToast(context, err, isError: true);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    try {
      final googleSignIn = GoogleSignIn(
        serverClientId: AppConfig.googleServerClientId.isNotEmpty
            ? AppConfig.googleServerClientId
            : null,
        scopes: const ['email', 'profile', 'openid'],
      );

      final account = await googleSignIn.signIn();
      if (account == null) {
        if (mounted) showToast(context, 'Google sign-in was cancelled.');
        return;
      }

      final auth = await account.authentication;
      final token = auth.idToken ?? auth.accessToken;

      if (token == null || token.isEmpty) {
        debugPrint('Google Sign-In Warning: Both idToken and accessToken are null.');
        if (mounted) showToast(context, 'Failed to obtain Google authentication token', isError: true);
        return;
      }

      final ok = await ref.read(authProvider.notifier).loginWithGoogle(token);
      if (!mounted) return;
      if (ok) {
        final user = ref.read(authProvider).user!;
        debugPrint('[LOGIN DIAGNOSTICS] Google login success for user: ${user.email}, role: ${user.role}');
        context.go(user.isAdmin ? '/admin' : '/dashboard');
      } else {
        final err = ref.read(authProvider).error ?? 'Google authentication failed';
        showToast(context, err, isError: true);
      }
    } catch (e, stack) {
      debugPrint('Google Sign-In Technical Exception: $e\n$stack');
      if (!mounted) return;

      String userMsg = 'Google sign-in is currently unavailable. Please try again.';
      final str = e.toString().toLowerCase();
      if (str.contains('canceled') || str.contains('cancelled') || str.contains('12501')) {
        userMsg = 'Google sign-in was cancelled.';
      } else if (str.contains('api_exception: 10') || str.contains('developer_error')) {
        userMsg = 'Google sign-in configuration error. Ensure app SHA-1 fingerprint is registered.';
      } else if (str.contains('network_error') || str.contains('socketexception')) {
        userMsg = 'Unable to connect to Google services. Check internet connection.';
      }
      showToast(context, userMsg, isError: true);
    }
  }

  void _openMobileOtpModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _MobileOtpSheet(
        onSuccess: (user) {
          Navigator.pop(ctx);
          debugPrint('[LOGIN DIAGNOSTICS] OTP login success for user: ${user.email}, role: ${user.role}');
          context.go(user.isAdmin ? '/admin' : '/dashboard');
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authProvider);

    return RootExitPopScope(
      child: Scaffold(
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
                            const SizedBox(height: 24),
                            Text(
                              'Welcome back',
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
                              'Sign in to continue your learning journey',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: AppColors.slate500,
                                  height: 1.5),
                            ),
                            const SizedBox(height: 28),

                            // ── QUICK AUTH BUTTONS (GOOGLE & MOBILE OTP) ──
                            OutlinedButton(
                              onPressed: state.isLoading ? null : _handleGoogleSignIn,
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                side: const BorderSide(color: AppColors.slate200),
                                backgroundColor: AppColors.white,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 20,
                                    height: 20,
                                    decoration: const BoxDecoration(shape: BoxShape.circle),
                                    child: Center(
                                      child: Text('G', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: const Color(0xFF4285F4))),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text('Continue with Google', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.navy)),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),

                            OutlinedButton(
                              onPressed: state.isLoading ? null : _openMobileOtpModal,
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                side: const BorderSide(color: AppColors.slate200),
                                backgroundColor: AppColors.white,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.phone_iphone_rounded, size: 18, color: AppColors.violet),
                                  const SizedBox(width: 10),
                                  Text('Login with Mobile OTP', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.navy)),
                                ],
                              ),
                            ),

                            const SizedBox(height: 20),

                            Row(
                              children: [
                                const Expanded(child: Divider(color: AppColors.slate200)),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  child: Text('OR', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.slate400)),
                                ),
                                const Expanded(child: Divider(color: AppColors.slate200)),
                              ],
                            ),

                            const SizedBox(height: 20),

                            // ── FORM CARD (EMAIL + PASSWORD) ─────────────
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
                                      if (v == null || v.isEmpty || !v.contains('@')) {
                                        return 'Enter a valid email address';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  CustomTextField(
                                    label: 'Password',
                                    hint: '••••••••',
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
                                  const SizedBox(height: 8),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      onPressed: () => context.push('/forgot-password'),
                                      style: TextButton.styleFrom(
                                        padding: EdgeInsets.zero,
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      child: Text(
                                        'Forgot password?',
                                        style: GoogleFonts.inter(
                                          color: AppColors.blue,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  CustomButton(
                                    text: 'Sign in',
                                    isLoading: state.isLoading,
                                    onPressed: _submit,
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 28),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  "Don't have an account? ",
                                  style: GoogleFonts.inter(color: AppColors.slate500, fontSize: 14),
                                ),
                                GestureDetector(
                                  onTap: () => context.push('/register'),
                                  child: Text(
                                    'Register',
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
      ),
    );
  }
}

// ── MOBILE OTP BOTTOM SHEET ──────────────────────────────────────────────────
class _MobileOtpSheet extends ConsumerStatefulWidget {
  final ValueChanged<UserModel> onSuccess;
  const _MobileOtpSheet({required this.onSuccess});

  @override
  ConsumerState<_MobileOtpSheet> createState() => _MobileOtpSheetState();
}

class _MobileOtpSheetState extends ConsumerState<_MobileOtpSheet> {
  int _step = 1; // 1 = Enter Phone, 2 = Verify OTP
  final _phoneCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  String _classLevel = '10';

  bool _sending = false;
  bool _verifying = false;
  bool _userExists = false;

  Timer? _timer;
  int _countdown = 30;

  @override
  void dispose() {
    _timer?.cancel();
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    _nameCtrl.dispose();
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

  Future<void> _sendOtp() async {
    final rawPhone = _phoneCtrl.text.trim();
    final digits = rawPhone.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 10) {
      showToast(context, 'Enter a valid 10-digit mobile number', isError: true);
      return;
    }

    setState(() => _sending = true);
    final res = await ref.read(authProvider.notifier).sendMobileOtp(rawPhone);
    if (!mounted) return;
    setState(() => _sending = false);

    if (res != null && res['ok'] == true) {
      setState(() {
        _step = 2;
        _userExists = res['exists'] == true;
      });
      _startTimer();
      showToast(context, 'OTP sent successfully!');
    } else {
      final err = ref.read(authProvider).error ?? 'Failed to send OTP';
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
    final ok = await ref.read(authProvider.notifier).verifyMobileOtp(
          phone: _phoneCtrl.text.trim(),
          otp: otp,
          name: _nameCtrl.text.trim(),
          classLevel: _classLevel,
        );
    if (!mounted) return;
    setState(() => _verifying = false);

    if (ok) {
      final user = ref.read(authProvider).user!;
      widget.onSuccess(user);
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
                _step == 1 ? 'Login with Mobile OTP' : 'Verify Mobile OTP',
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
          const SizedBox(height: 16),

          if (_step == 1) ...[
            Text(
              'Enter your 10-digit mobile number to receive a verification OTP.',
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.slate500),
            ),
            const SizedBox(height: 16),
            CustomTextField(
              label: 'Mobile Number',
              hint: '9876543210',
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              prefixIcon: Icons.phone_android_rounded,
            ),
            const SizedBox(height: 20),
            CustomButton(
              text: 'Send Verification OTP',
              isLoading: _sending,
              onPressed: _sendOtp,
            ),
          ] else ...[
            Text(
              'Enter the 6-digit OTP code sent to ${_phoneCtrl.text.trim()}.',
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.slate500),
            ),
            const SizedBox(height: 16),

            CustomTextField(
              label: 'Enter 6-Digit OTP',
              hint: '123456',
              controller: _otpCtrl,
              keyboardType: TextInputType.number,
              prefixIcon: Icons.pin_outlined,
            ),

            if (!_userExists) ...[
              const SizedBox(height: 14),
              CustomTextField(
                label: 'Your Name (New Student)',
                hint: 'Full Name',
                controller: _nameCtrl,
                prefixIcon: Icons.person_outline_rounded,
              ),
              const SizedBox(height: 14),
              Text('Class Level', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.slate600)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: _classLevel,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.slate200)),
                ),
                items: const [
                  DropdownMenuItem(value: '8', child: Text('Class 8')),
                  DropdownMenuItem(value: '9', child: Text('Class 9')),
                  DropdownMenuItem(value: '10', child: Text('Class 10')),
                ],
                onChanged: (v) => setState(() => _classLevel = v ?? '10'),
              ),
            ],

            const SizedBox(height: 20),

            CustomButton(
              text: 'Verify OTP & Login',
              isLoading: _verifying,
              onPressed: _verifyOtp,
            ),

            const SizedBox(height: 12),

            Center(
              child: _countdown > 0
                  ? Text(
                      'Resend OTP in ${_countdown}s',
                      style: GoogleFonts.inter(fontSize: 12, color: AppColors.slate400, fontWeight: FontWeight.w600),
                    )
                  : TextButton(
                      onPressed: _sendOtp,
                      child: Text('Resend OTP', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.blue)),
                    ),
            ),
          ],
        ],
      ),
    );
  }
}
