import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../common/widgets/app_logo.dart';
import '../../common/widgets/custom_button.dart';
import '../../common/widgets/custom_text_field.dart';
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await ref.read(authProvider.notifier).register(
          name: _nameCtrl.text.trim(),
          email: _emailCtrl.text.trim(),
          phone: _phoneCtrl.text.trim(),
          password: _passwordCtrl.text,
          classLevel: _classLevel,
          referralCode: _referralCtrl.text.trim().isEmpty
              ? null
              : _referralCtrl.text.trim(),
        );
    if (!mounted) return;
    if (ok) {
      context.go('/dashboard');
    } else {
      final err =
          ref.read(authProvider).error ?? 'Registration failed';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(err),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: AppColors.white,
      body: Stack(
        children: [
          // Subtle gradient header decoration
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
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 32),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.stretch,
                        children: [
                          // Logo
                          const Center(child: AppLogo(size: 80)),
                          const SizedBox(height: 32),

                          // Heading
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

                          // ── Form card ────────────────────────────────
                          Container(
                            padding: const EdgeInsets.all(28),
                            decoration: BoxDecoration(
                              color: AppColors.white,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                  color: AppColors.slate200),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.navy.withAlpha(12),
                                  blurRadius: 24,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.stretch,
                              children: [
                                CustomTextField(
                                  label: 'Full name',
                                  hint: 'Your full name',
                                  controller: _nameCtrl,
                                  prefixIcon:
                                      Icons.person_outline_rounded,
                                  textCapitalization:
                                      TextCapitalization.words,
                                  validator: (v) =>
                                      (v == null || v.trim().isEmpty)
                                          ? 'Name is required'
                                          : null,
                                ),
                                const SizedBox(height: 16),
                                CustomTextField(
                                  label: 'Email address',
                                  hint: 'you@example.com',
                                  controller: _emailCtrl,
                                  keyboardType:
                                      TextInputType.emailAddress,
                                  prefixIcon:
                                      Icons.mail_outline_rounded,
                                  validator: (v) {
                                    if (v == null || !v.contains('@')) {
                                      return 'Enter a valid email';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                                CustomTextField(
                                  label: 'Phone number',
                                  hint: '10-digit mobile number',
                                  controller: _phoneCtrl,
                                  keyboardType: TextInputType.phone,
                                  prefixIcon:
                                      Icons.phone_outlined,
                                  validator: (v) =>
                                      (v == null || v.trim().isEmpty)
                                          ? 'Phone is required'
                                          : null,
                                ),
                                const SizedBox(height: 16),
                                CustomTextField(
                                  label: 'Password',
                                  hint: 'Min. 6 characters',
                                  controller: _passwordCtrl,
                                  obscureText: _obscure,
                                  prefixIcon:
                                      Icons.lock_outline_rounded,
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscure
                                          ? Icons
                                              .visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      color: AppColors.slate400,
                                      size: 20,
                                    ),
                                    onPressed: () => setState(
                                        () => _obscure = !_obscure),
                                  ),
                                  validator: (v) {
                                    if (v == null || v.length < 6) {
                                      return 'Password must be at least 6 characters';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),

                                // Class Level dropdown
                                DropdownButtonFormField<String>(
                                  initialValue: _classLevel,
                                  decoration: InputDecoration(
                                    labelText: 'Class (optional)',
                                    filled: true,
                                    fillColor: AppColors.slate50,
                                    prefixIcon: const Icon(
                                        Icons.school_outlined,
                                        size: 20,
                                        color: AppColors.slate400),
                                    border: OutlineInputBorder(
                                      borderRadius:
                                          BorderRadius.circular(14),
                                      borderSide: const BorderSide(
                                          color: AppColors.slate200),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius:
                                          BorderRadius.circular(14),
                                      borderSide: const BorderSide(
                                          color: AppColors.slate200),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius:
                                          BorderRadius.circular(14),
                                      borderSide: const BorderSide(
                                          color: AppColors.blue,
                                          width: 2),
                                    ),
                                    contentPadding:
                                        const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 16),
                                  ),
                                  hint: Text('Select class',
                                      style: GoogleFonts.inter(
                                          color: AppColors.slate400,
                                          fontSize: 14)),
                                  items: _classes
                                      .map((c) => DropdownMenuItem(
                                            value: c,
                                            child: Text('Class $c',
                                                style: GoogleFonts.inter(
                                                    fontSize: 14)),
                                          ))
                                      .toList(),
                                  onChanged: (v) => setState(
                                      () => _classLevel = v),
                                ),
                                const SizedBox(height: 16),
                                CustomTextField(
                                  label: 'Referral code (optional)',
                                  hint: 'Enter referral code',
                                  controller: _referralCtrl,
                                  prefixIcon:
                                      Icons.card_giftcard_outlined,
                                ),
                                const SizedBox(height: 24),
                                CustomButton(
                                  text: 'Create account',
                                  isLoading: state.isLoading,
                                  onPressed: _submit,
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 28),

                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.center,
                            children: [
                              Text(
                                'Already have an account? ',
                                style: GoogleFonts.inter(
                                    color: AppColors.slate500,
                                    fontSize: 14),
                              ),
                              GestureDetector(
                                onTap: () =>
                                    context.go('/login'),
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
