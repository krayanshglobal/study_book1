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
import '../providers/admin_provider.dart';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  Map _stats = {};
  bool _loading = true;
  bool _cardLoading = false;
  AnimationController? _fadeController;
  Animation<double>? _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
      value: 1.0,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController!,
      curve: Curves.easeOutCubic,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final activeClass = ref.read(selectedAdminClassProvider);
      _loadStats(activeClass, isInitial: true);
    });
  }

  @override
  void dispose() {
    _fadeController?.dispose();
    super.dispose();
  }

  Future<void> _loadStats(String classLevel, {bool isInitial = false}) async {
    if (isInitial) {
      setState(() => _loading = true);
    } else {
      setState(() => _cardLoading = true);
    }

    try {
      Future<int?> safeFetchCount(String endpoint) async {
        try {
          final res = await dioClient.get(
            endpoint,
            queryParameters: {'class_level': classLevel},
          );
          final items = res.data['items'] as List? ?? [];
          return items.length;
        } catch (_) {
          return null;
        }
      }

      final statsRes = await dioClient.get(
        ApiEndpoints.adminStats,
        queryParameters: {'class_level': classLevel},
      );

      final extraCounts = await Future.wait([
        safeFetchCount(ApiEndpoints.notes),
        safeFetchCount(ApiEndpoints.flashcards),
        safeFetchCount(ApiEndpoints.promos),
      ]);

      final Map statsData = Map.from(statsRes.data as Map? ?? {});

      if (extraCounts[0] != null) statsData['notes'] = extraCounts[0];
      if (extraCounts[1] != null) statsData['flashcards'] = extraCounts[1];
      if (extraCounts[2] != null) statsData['promos'] = extraCounts[2];

      if (mounted) {
        setState(() {
          _stats = statsData;
          _loading = false;
          _cardLoading = false;
        });
        _fadeController?.forward(from: 0.0);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _cardLoading = false;
        });
        showToast(context, formatApiError(e), isError: true);
      }
    }
  }

  void _onClassSelected(String lvl) {
    final currentClass = ref.read(selectedAdminClassProvider);
    if (currentClass == lvl && !_cardLoading) return;

    // 1. Instantly update single source of truth in Riverpod
    ref.read(selectedAdminClassProvider.notifier).state = lvl;

    // 2. Immediately trigger dashboard refresh for newly selected class
    _loadStats(lvl);
  }

  @override
  Widget build(BuildContext context) {
    final activeClass = ref.watch(selectedAdminClassProvider);
    final user = ref.watch(authProvider).user;
    final isSuperAdmin = user?.isSuperAdmin ?? false;

    return MainScaffold(
      title: isSuperAdmin ? 'SuperAdmin Dashboard' : 'Admin Dashboard',
      body: _loading
          ? const LoadingIndicator()
          : RefreshIndicator(
              onRefresh: () => _loadStats(activeClass),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('COMMAND CENTRE',
                                style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 2,
                                    color: AppColors.violet)),
                            const SizedBox(height: 4),
                            Text(
                              isSuperAdmin
                                  ? 'SuperAdmin dashboard'
                                  : 'Admin dashboard',
                              style: GoogleFonts.fraunces(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.navy),
                            ),
                            const SizedBox(height: 2),
                            Text('You control the entire StudyBook experience.',
                                style: GoogleFonts.inter(
                                    fontSize: 12, color: AppColors.slate500)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Class switcher (Single Source of Truth)
                    Row(
                      children: ['8', '9', '10'].map((lvl) {
                        final isSel = activeClass == lvl;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(
                              'Class $lvl',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color:
                                    isSel ? Colors.white : AppColors.slate700,
                              ),
                            ),
                            selected: isSel,
                            selectedColor: AppColors.navy,
                            backgroundColor: AppColors.slate100,
                            onSelected: (_) => _onClassSelected(lvl),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),

                    // Fade-in animated Dashboard Tiles Container
                    FadeTransition(
                      opacity: _fadeAnimation ?? const AlwaysStoppedAnimation(1.0),
                      child: GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.3,
                        children: [
                          _Tile(
                            icon: Icons.quiz_outlined,
                            label: 'Questions',
                            val: '${_stats['questions'] ?? 0}',
                            route: '/admin/questions',
                            color: AppColors.blue,
                            isLoading: _cardLoading,
                          ),
                          _Tile(
                            icon: Icons.assignment_outlined,
                            label: 'Tests',
                            val: '${_stats['tests'] ?? 0}',
                            route: '/admin/tests',
                            color: AppColors.violet,
                            isLoading: _cardLoading,
                          ),
                          _Tile(
                            icon: Icons.play_circle_outline,
                            label: 'Videos',
                            val: '${_stats['videos'] ?? 0}',
                            route: '/admin/videos',
                            color: AppColors.navy,
                            isLoading: _cardLoading,
                          ),
                          _Tile(
                            icon: Icons.bar_chart_outlined,
                            label: 'Analytics',
                            val: '${_stats['attempts'] ?? 0}',
                            route: '/admin/analytics',
                            color: AppColors.violet,
                            isLoading: _cardLoading,
                          ),
                          _Tile(
                            icon: Icons.group_outlined,
                            label: 'Students',
                            val: '${_stats['students'] ?? 0}',
                            route: '/admin/users',
                            color: AppColors.blue,
                            isLoading: _cardLoading,
                          ),
                          _Tile(
                            icon: Icons.card_membership_outlined,
                            label: 'Active subs',
                            val: '${_stats['active_subs'] ?? 0}',
                            route: '/admin/plans',
                            color: AppColors.navy,
                            isLoading: _cardLoading,
                          ),
                          _Tile(
                            icon: Icons.security_outlined,
                            label: 'Class Requests',
                            val: '${_stats['class_requests'] ?? 0}',
                            route: '/admin/class-requests',
                            color: const Color(0xFFD97706),
                            isLoading: _cardLoading,
                          ),
                          _Tile(
                            icon: Icons.article_outlined,
                            label: 'Notes',
                            val: _stats.containsKey('notes')
                                ? '${_stats['notes']}'
                                : 'Manage',
                            route: '/admin/notes',
                            color: AppColors.violet,
                            isLoading: _cardLoading,
                          ),
                          _Tile(
                            icon: Icons.style_outlined,
                            label: 'Flashcards',
                            val: _stats.containsKey('flashcards')
                                ? '${_stats['flashcards']}'
                                : 'Manage',
                            route: '/admin/flashcards',
                            color: AppColors.blue,
                            isLoading: _cardLoading,
                          ),
                          _Tile(
                            icon: Icons.local_offer_outlined,
                            label: 'Promos',
                            val: _stats.containsKey('promos')
                                ? '${_stats['promos']}'
                                : 'Offers',
                            route: '/admin/promos',
                            color: const Color(0xFF059669),
                            isLoading: _cardLoading,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),
                    // Quick Actions Card
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
                          Text('QUICK ACTIONS',
                              style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.5,
                                  color: AppColors.violet)),
                          const SizedBox(height: 12),
                          const _QuickAction(
                              icon: Icons.add_circle_outline,
                              text: 'Add a new question to the bank',
                              route: '/admin/questions',
                              color: AppColors.blue),
                          const _QuickAction(
                              icon: Icons.calendar_today_outlined,
                              text: 'Schedule a Sunday mock test',
                              route: '/admin/tests',
                              color: AppColors.violet),
                          const _QuickAction(
                              icon: Icons.video_call_outlined,
                              text: 'Publish a new video lesson',
                              route: '/admin/videos',
                              color: AppColors.blue),
                          const _QuickAction(
                              icon: Icons.card_giftcard_outlined,
                              text: 'Create a premium plan',
                              route: '/admin/plans',
                              color: AppColors.violet),
                          const _QuickAction(
                              icon: Icons.campaign_outlined,
                              text: 'Broadcast an announcement',
                              route: '/admin/announcements',
                              color: AppColors.navy),
                          const _QuickAction(
                              icon: Icons.security_outlined,
                              text: 'Approve or reject class change requests',
                              route: '/admin/class-requests',
                              color: Color(0xFFD97706)),
                          const _QuickAction(
                              icon: Icons.article_outlined,
                              text: 'Publish study notes',
                              route: '/admin/notes',
                              color: AppColors.violet),
                          const _QuickAction(
                              icon: Icons.style_outlined,
                              text: 'Manage study flashcards',
                              route: '/admin/flashcards',
                              color: AppColors.blue),
                          const _QuickAction(
                              icon: Icons.local_offer_outlined,
                              text: 'Publish offer promo banners',
                              route: '/admin/promos',
                              color: Color(0xFF059669)),
                          const _QuickAction(
                              icon: Icons.payment_outlined,
                              text: 'View payment transactions',
                              route: '/admin/payments',
                              color: AppColors.navy),
                          if (isSuperAdmin)
                            const _QuickAction(
                                icon: Icons.admin_panel_settings_outlined,
                                text: 'Manage Admin Accounts',
                                route: '/superadmin',
                                color: AppColors.error),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),
                    // Platform Pulse Card
                    FadeTransition(
                      opacity: _fadeAnimation ?? const AlwaysStoppedAnimation(1.0),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.slate200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('CLASS $activeClass PULSE',
                                style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.5,
                                    color: AppColors.blue)),
                            const SizedBox(height: 12),
                            _PulseRow('Total students',
                                '${_stats['students'] ?? 0}',
                                isLoading: _cardLoading),
                            _PulseRow('Question bank size',
                                '${_stats['questions'] ?? 0}',
                                isLoading: _cardLoading),
                            _PulseRow('Tests scheduled',
                                '${_stats['tests'] ?? 0}',
                                isLoading: _cardLoading),
                            _PulseRow('Videos published',
                                '${_stats['videos'] ?? 0}',
                                isLoading: _cardLoading),
                            _PulseRow('Premium members',
                                '${_stats['active_subs'] ?? 0}',
                                isLoading: _cardLoading),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String val;
  final String route;
  final Color color;
  final bool isLoading;

  const _Tile({
    required this.icon,
    required this.label,
    required this.val,
    required this.route,
    required this.color,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push(route),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.slate200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(label.toUpperCase(),
                      style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                          color: AppColors.slate500),
                      overflow: TextOverflow.ellipsis),
                ),
                Icon(icon, size: 18, color: color),
              ],
            ),
            if (isLoading)
              SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: color,
                ),
              )
            else
              Text(val,
                  style: GoogleFonts.fraunces(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy)),
            Row(
              children: [
                Text('Manage',
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.blue)),
                const SizedBox(width: 2),
                const Icon(Icons.arrow_outward,
                    size: 12, color: AppColors.blue),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String text;
  final String route;
  final Color color;

  const _QuickAction(
      {required this.icon,
      required this.text,
      required this.route,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push(route),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.slate50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.slate200),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 10),
            Expanded(
                child: Text(text,
                    style: GoogleFonts.inter(
                        fontSize: 13, color: AppColors.navy))),
            const Icon(Icons.chevron_right, size: 18, color: AppColors.slate400),
          ],
        ),
      ),
    );
  }
}

class _PulseRow extends StatelessWidget {
  final String label;
  final String val;
  final bool isLoading;

  const _PulseRow(this.label, this.val, {this.isLoading = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 13, color: AppColors.slate700)),
          if (isLoading)
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.blue,
              ),
            )
          else
            Text(val,
                style: GoogleFonts.jetBrainsMono(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy)),
        ],
      ),
    );
  }
}
