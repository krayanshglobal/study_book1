import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../common/widgets/app_logo.dart';
import '../../common/widgets/root_exit_pop_scope.dart';

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return RootExitPopScope(
      child: Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Navbar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  children: [
                    const AppLogo(size: 36),
                    const SizedBox(width: 10),
                    Text('StudyBook',
                        style: GoogleFonts.fraunces(
                            fontWeight: FontWeight.w700, fontSize: 18, color: AppColors.navy)),
                    const Spacer(),
                    TextButton(
                      onPressed: () => context.go('/login'),
                      child: Text('Login',
                          style: GoogleFonts.inter(color: AppColors.blue, fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => context.go('/register'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.navy,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text('Get started',
                          style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                    ),
                  ],
                ),
              ),

              // Hero section
              Container(
                padding: const EdgeInsets.fromLTRB(24, 48, 24, 64),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [AppColors.white, AppColors.slate50],
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.violet.withAlpha(15),
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(color: AppColors.violet.withAlpha(40)),
                      ),
                      child: Text('AI-powered learning platform',
                          style: GoogleFonts.inter(
                              fontSize: 12, color: AppColors.violet, fontWeight: FontWeight.w600,
                              letterSpacing: 0.5)),
                    ),
                    const SizedBox(height: 20),
                    Text('Study smarter.\nScore higher.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.fraunces(
                            fontSize: 40, fontWeight: FontWeight.w600, color: AppColors.navy, height: 1.15)),
                    const SizedBox(height: 16),
                    Text(
                      'Practice tests, video lessons, question banks and analytics — everything you need to excel in Class 8, 9 & 10.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(fontSize: 15, color: AppColors.slate500, height: 1.6),
                    ),
                    const SizedBox(height: 32),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => context.go('/register'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.navy,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text('Start for free',
                                style: GoogleFonts.inter(
                                    color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => context.go('/login'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              side: const BorderSide(color: AppColors.slate200),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text('Sign in',
                                style: GoogleFonts.inter(
                                    color: AppColors.navy, fontWeight: FontWeight.w600, fontSize: 15)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Features grid
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 40, 24, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('EVERYTHING YOU NEED',
                        style: GoogleFonts.inter(
                            fontSize: 10, fontWeight: FontWeight.w700,
                            letterSpacing: 2, color: AppColors.blue)),
                    const SizedBox(height: 6),
                    Text('Built for students, guided by experts',
                        style: GoogleFonts.fraunces(
                            fontSize: 24, fontWeight: FontWeight.w600, color: AppColors.navy)),
                    const SizedBox(height: 24),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.2,
                      children: const [
                        _FeatureCard(icon: Icons.assignment_outlined, title: 'Mock Tests',
                            desc: 'Timed tests with auto-submit and detailed results', color: AppColors.blue),
                        _FeatureCard(icon: Icons.quiz_outlined, title: 'Question Bank',
                            desc: 'Thousands of practice questions across topics', color: AppColors.violet),
                        _FeatureCard(icon: Icons.play_circle_outline, title: 'Video Lessons',
                            desc: 'Expert video explanations for every concept', color: AppColors.navy),
                        _FeatureCard(icon: Icons.bar_chart_outlined, title: 'Analytics',
                            desc: 'Track your strengths & weaknesses precisely', color: AppColors.blue),
                      ],
                    ),
                  ],
                ),
              ),

              // Footer CTA
              Container(
                margin: const EdgeInsets.fromLTRB(24, 0, 24, 48),
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  gradient: AppColors.navyPurpleGradient,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    Text('Ready to get started?',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.fraunces(
                            fontSize: 24, fontWeight: FontWeight.w600, color: Colors.white)),
                    const SizedBox(height: 8),
                    Text('Join thousands of students already using StudyBook.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(fontSize: 13, color: Colors.white60)),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () => context.go('/register'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('Create free account',
                          style: GoogleFonts.inter(
                              color: AppColors.navy, fontWeight: FontWeight.w700, fontSize: 14)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String desc;
  final Color color;
  const _FeatureCard({required this.icon, required this.title, required this.desc, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: color.withAlpha(20),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(height: 10),
          Text(title,
              style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.navy)),
          const SizedBox(height: 4),
          Text(desc,
              style: GoogleFonts.inter(fontSize: 11, color: AppColors.slate500, height: 1.4),
              maxLines: 2, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}
