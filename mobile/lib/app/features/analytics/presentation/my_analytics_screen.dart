import 'dart:ui';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/api/api_endpoints.dart';
import '../../../core/api/dio_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../../common/widgets/app_drawer.dart';
import '../../common/widgets/shared_widgets.dart';

class MyAnalyticsScreen extends ConsumerStatefulWidget {
  const MyAnalyticsScreen({super.key});

  @override
  ConsumerState<MyAnalyticsScreen> createState() => _MyAnalyticsScreenState();
}

class _MyAnalyticsScreenState extends ConsumerState<MyAnalyticsScreen>
    with SingleTickerProviderStateMixin {
  Map? _data;
  bool _loading = true;
  bool _dialogDismissed = false;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
    _scaleAnim = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );
    _animController.forward();
    // Silently refresh the user profile before loading analytics data.
    // This ensures that if a Super Admin upgraded this student to Premium
    // while the app was open, the change is reflected immediately without
    // requiring a logout or restart.
    ref.read(authProvider.notifier).refreshSilently().then((_) {
      if (mounted) _load();
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final isPremium = ref.read(authProvider).user?.subscriptionActive == true;
    try {
      final r = await dioClient.get(ApiEndpoints.studentAnalytics);
      if (mounted) {
        setState(() {
          _data = r.data as Map;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        if (!isPremium) {
          // Fallback analytics mock structure for Free user to render background page behind blur
          setState(() {
            _data = {
              'overall_accuracy': 75.0,
              'total_attempts': 14,
              'total_points': 420,
              'strengths': [
                {'topic': 'Algebraic Expressions', 'accuracy': 88},
                {'topic': 'Linear Equations', 'accuracy': 82},
              ],
              'weaknesses': [
                {'topic': 'Quadratic Formulas', 'accuracy': 45},
                {'topic': 'Coordinate Geometry', 'accuracy': 52},
              ],
              'recent_scores': [
                {'percent': 65},
                {'percent': 70},
                {'percent': 78},
                {'percent': 75},
                {'percent': 85}
              ],
              'topics': [
                {'topic': 'Algebra', 'accuracy': 85},
                {'topic': 'Geometry', 'accuracy': 60},
                {'topic': 'Trigonometry', 'accuracy': 45},
                {'topic': 'Calculus', 'accuracy': 72},
              ]
            };
            _loading = false;
          });
        } else {
          setState(() => _loading = false);
          showToast(context, formatApiError(e), isError: true);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final isPremium = user?.subscriptionActive == true;

    if (_loading) {
      return const MainScaffold(
        title: 'My Analytics',
        showBack: true,
        parentRoute: '/dashboard',
        body: LoadingIndicator(),
      );
    }

    final data = _data ?? {
      'overall_accuracy': 75.0,
      'total_attempts': 14,
      'total_points': 420,
      'strengths': [],
      'weaknesses': [],
      'recent_scores': [],
      'topics': [],
    };

    final Widget analyticsContent = _buildAnalyticsBody(user, data);

    if (isPremium) {
      return MainScaffold(
        title: 'My Analytics',
        showBack: true,
        parentRoute: '/dashboard',
        body: analyticsContent,
      );
    }

    // FREE USER EXPERIENCE: Analytics page behind blurred backdrop + centered dialog
    return MainScaffold(
      title: 'My Analytics',
      showBack: true,
      parentRoute: '/dashboard',
      body: Stack(
        children: [
          // 1. Underlying Analytics Page
          Positioned.fill(child: analyticsContent),

          // 2. Backdrop Blur Layer
          Positioned.fill(
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Container(
                  color: Colors.white.withAlpha(90),
                ),
              ),
            ),
          ),

          // 3. Centered Premium Dialog (Dismissible)
          if (!_dialogDismissed)
            Positioned.fill(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  child: FadeTransition(
                    opacity: _fadeAnim,
                    child: ScaleTransition(
                      scale: _scaleAnim,
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 380),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0F172A).withAlpha(31),
                              blurRadius: 30,
                              spreadRadius: 2,
                              offset: const Offset(0, 10),
                            ),
                          ],
                          border: Border.all(color: AppColors.slate200.withAlpha(120)),
                        ),
                        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Close Button for dismissible dialog
                            Align(
                              alignment: Alignment.topRight,
                              child: InkWell(
                                onTap: () {
                                  setState(() => _dialogDismissed = true);
                                },
                                borderRadius: BorderRadius.circular(99),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: AppColors.slate100,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close_rounded,
                                    size: 18,
                                    color: AppColors.slate600,
                                  ),
                                ),
                              ),
                            ),

                            // Lock Icon Badge
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF3C7), // Light gold/yellow background
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.lock_rounded,
                                  size: 26,
                                  color: Color(0xFFD97706), // Amber lock icon
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Title
                            Text(
                              'Your Personalized Analysis',
                              style: GoogleFonts.fraunces(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppColors.navy,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 10),

                            // Badge: PREMIUM SUBSCRIPTION REQUIRED
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3E8FF), // Light purple badge
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: Text(
                                'PREMIUM SUBSCRIPTION REQUIRED',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8,
                                  color: const Color(0xFF7C3AED), // Purple text
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),

                            // Description matching reference image 1
                            Text(
                              'Unlock a detailed breakdown of your learning performance.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: AppColors.slate600,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 18),
                            const Divider(height: 1, color: AppColors.slate200),
                            const SizedBox(height: 18),

                            // Feature list
                            const Column(
                              children: [
                                _FeatureBulletItem(label: 'Average Accuracy Breakdown'),
                                SizedBox(height: 10),
                                _FeatureBulletItem(label: 'Performance Percentile Comparison'),
                                SizedBox(height: 10),
                                _FeatureBulletItem(label: 'Mock Test Score Trend'),
                                SizedBox(height: 10),
                                _FeatureBulletItem(label: 'Detailed Strength & Weakness Analysis'),
                              ],
                            ),
                            const SizedBox(height: 24),

                            // Primary Button: Upgrade to StudyBook Premium >
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(99),
                                onTap: () => context.push('/pricing'),
                                splashColor: Colors.white10,
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0F172A), // Dark navy button matching web reference
                                    borderRadius: BorderRadius.circular(99),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF0F172A).withAlpha(51),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'Upgrade to StudyBook Premium',
                                        style: GoogleFonts.inter(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      const Icon(
                                        Icons.chevron_right_rounded,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                    ],
                                  ),
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
            ),

          // Floating button if dialog was dismissed, keeping background blurred & allowing re-open
          if (_dialogDismissed)
            Positioned(
              bottom: 24,
              left: 20,
              right: 20,
              child: Center(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      setState(() => _dialogDismissed = false);
                      _animController.forward(from: 0);
                    },
                    borderRadius: BorderRadius.circular(99),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7C3AED),
                        borderRadius: BorderRadius.circular(99),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF7C3AED).withAlpha(77),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.lock_rounded, color: Colors.white, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            'Unlock Premium Analytics',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
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

  Widget _buildAnalyticsBody(user, Map data) {
    final double overall = (data['overall_accuracy'] as num?)?.toDouble() ?? 0.0;
    final int totalAttempts = data['total_attempts'] ?? 0;
    final int totalPoints = data['total_points'] ?? 0;
    final List strengths = data['strengths'] ?? [];
    final List weaknesses = data['weaknesses'] ?? [];
    final List recentScores = data['recent_scores'] ?? [];
    final List topics = data['topics'] ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('YOUR JOURNEY',
                        style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 2, color: AppColors.violet)),
                    const SizedBox(height: 2),
                    Text('Hey ${user?.name.split(' ').first ?? 'Student'}, here\'s your performance',
                        style: GoogleFonts.fraunces(fontSize: 22, fontWeight: FontWeight.w600, color: AppColors.navy)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _Chip('$totalAttempts tests taken', AppColors.blue),
              const SizedBox(width: 8),
              _Chip('$totalPoints points', AppColors.violet),
            ],
          ),
          const SizedBox(height: 20),

          // Accuracy gauge + Recent Trend Grid
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.slate200),
                  ),
                  child: Column(
                    children: [
                      Text('OVERALL ACCURACY', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: AppColors.blue)),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 100,
                        child: Stack(
                          children: [
                            PieChart(
                              PieChartData(
                                startDegreeOffset: 180,
                                sectionsSpace: 0,
                                centerSpaceRadius: 36,
                                sections: [
                                  PieChartSectionData(
                                    value: overall,
                                    color: overall >= 75 ? AppColors.success : overall >= 50 ? AppColors.violet : AppColors.error,
                                    radius: 12,
                                    showTitle: false,
                                  ),
                                  PieChartSectionData(
                                    value: 100 - overall,
                                    color: AppColors.slate100,
                                    radius: 12,
                                    showTitle: false,
                                  ),
                                ],
                              ),
                            ),
                            Center(
                              child: Text('$overall%',
                                  style: GoogleFonts.fraunces(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.navy)),
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

          const SizedBox(height: 20),
          // Recent score trend chart
          if (recentScores.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.slate200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('RECENT TESTS', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: AppColors.violet)),
                  const SizedBox(height: 4),
                  Text('Score trend', style: GoogleFonts.fraunces(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.navy)),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 160,
                    child: LineChart(
                      LineChartData(
                        gridData: const FlGridData(show: true, drawVerticalLine: false),
                        titlesData: const FlTitlesData(
                          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30)),
                          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        borderData: FlBorderData(show: false),
                        lineBarsData: [
                          LineChartBarData(
                            spots: recentScores.asMap().entries.map((e) {
                              final double y = (e.value['percent'] as num?)?.toDouble() ?? 0.0;
                              return FlSpot(e.key.toDouble(), y);
                            }).toList(),
                            isCurved: true,
                            color: AppColors.violet,
                            barWidth: 3,
                            dotData: const FlDotData(show: true),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Strengths & Weaknesses
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.slate200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('STRENGTHS', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.success)),
                      const SizedBox(height: 8),
                      if (strengths.isEmpty)
                        Text('Keep practising! >70% shows here.', style: GoogleFonts.inter(fontSize: 12, color: AppColors.slate500))
                      else
                        ...strengths.map((s) => Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                children: [
                                  Expanded(child: Text('${s['topic']}', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500))),
                                  Text('${s['accuracy']}%', style: GoogleFonts.jetBrainsMono(fontSize: 12, color: AppColors.success, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            )),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.slate200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('WEAKNESSES', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.error)),
                      const SizedBox(height: 8),
                      if (weaknesses.isEmpty)
                        Text('Nothing below 60%. Great job! 🔥', style: GoogleFonts.inter(fontSize: 12, color: AppColors.slate500))
                      else
                        ...weaknesses.map((w) => Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                children: [
                                  Expanded(child: Text('${w['topic']}', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500))),
                                  Text('${w['accuracy']}%', style: GoogleFonts.jetBrainsMono(fontSize: 12, color: AppColors.error, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            )),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),
          // Topic accuracy bar chart
          if (topics.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.slate200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('EVERY TOPIC', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: AppColors.blue)),
                  const SizedBox(height: 4),
                  Text('Accuracy per topic', style: GoogleFonts.fraunces(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.navy)),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 180,
                    child: BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: 100,
                        barTouchData: BarTouchData(enabled: true),
                        titlesData: const FlTitlesData(
                          show: true,
                          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30)),
                          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        borderData: FlBorderData(show: false),
                        barGroups: topics.asMap().entries.map((e) {
                          final double acc = (e.value['accuracy'] as num?)?.toDouble() ?? 0.0;
                          return BarChartGroupData(
                            x: e.key,
                            barRods: [
                              BarChartRodData(
                                toY: acc,
                                color: acc >= 70 ? AppColors.success : acc >= 50 ? AppColors.blue : AppColors.error,
                                width: 14,
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Motivational Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: AppColors.navyPurpleGradient,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Keep the streak going.', style: GoogleFonts.fraunces(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white)),
                const SizedBox(height: 6),
                Text(
                  overall >= 75
                      ? "Outstanding — you're in the top tier. Try an advanced test to push further."
                      : overall >= 50
                          ? "Great foundation! Focus on your weak topics — a few practice sessions and you'll cross 75%."
                          : "Every expert was once a beginner. Practise your weak topics daily and watch this number climb.",
                  style: GoogleFonts.inter(fontSize: 13, color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureBulletItem extends StatelessWidget {
  final String label;
  const _FeatureBulletItem({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: const BoxDecoration(
            color: Color(0xFFF59E0B), // Orange/gold bullet dot
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: AppColors.slate700,
            ),
          ),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withAlpha(50)),
      ),
      child: Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

