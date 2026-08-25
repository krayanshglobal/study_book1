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
  String? _errorMsg;
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
      setState(() {
        _loading = true;
        _errorMsg = null;
      });
    } else {
      setState(() {
        _cardLoading = true;
        _errorMsg = null;
      });
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
          _errorMsg = null;
        });
        _fadeController?.forward(from: 0.0);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _cardLoading = false;
          _errorMsg = 'Unable to load dashboard data.';
        });
      }
    }
  }

  void _onClassSelected(String lvl) {
    final currentClass = ref.read(selectedAdminClassProvider);
    if (currentClass == lvl && !_cardLoading) return;

    // Instantly update single source of truth in Riverpod
    ref.read(selectedAdminClassProvider.notifier).state = lvl;

    // Immediately trigger dashboard refresh for newly selected class
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
          : _errorMsg != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
                        const SizedBox(height: 12),
                        Text(
                          _errorMsg!,
                          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.navy),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => _loadStats(activeClass, isInitial: true),
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Retry'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.blue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => _loadStats(activeClass),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // COMMAND CENTRE TITLE SECTION
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.violet.withAlpha(20),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'COMMAND CENTRE',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.5,
                                  color: AppColors.violet,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              isSuperAdmin ? 'SuperAdmin dashboard' : 'Admin dashboard',
                              style: GoogleFonts.fraunces(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: AppColors.navy,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'You control the entire StudyBook experience.',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: AppColors.slate500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // 4 QUICK ACCESS CARDS (2x2 Grid)
                        GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1.15,
                          children: [
                            const _QuickAccessCard(
                              icon: Icons.emoji_events_outlined,
                              title: 'Leaderboard',
                              subtitle: 'Scores & release',
                              route: '/admin/leaderboard',
                              iconColor: Color(0xFFD97706),
                            ),
                            const _QuickAccessCard(
                              icon: Icons.assignment_outlined,
                              title: 'Mock & Final Tests',
                              subtitle: 'Schedule & test LBs',
                              route: '/admin/tests',
                              iconColor: AppColors.violet,
                            ),
                            const _QuickAccessCard(
                              icon: Icons.menu_book_outlined,
                              title: 'Question Bank',
                              subtitle: 'Add & manage questions',
                              route: '/admin/questions',
                              iconColor: AppColors.blue,
                            ),
                            _QuickAccessCard(
                              icon: Icons.share_outlined,
                              title: 'Top Referrals',
                              subtitle: (_stats['highest_referrals'] != null && (_stats['highest_referrals'] as int) > 0)
                                  ? 'Highest: ${_stats['highest_referrals']} referrals'
                                  : 'Highest student rank',
                              route: '/admin/users',
                              iconColor: const Color(0xFF059669),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // CLASS FILTER SEGMENTED CONTROL
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Filter by class',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.slate600,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: ['8', '9', '10'].map((lvl) {
                                  final isSel = activeClass == lvl;
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: ChoiceChip(
                                      label: Text(
                                        'Class $lvl',
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: isSel ? Colors.white : AppColors.slate700,
                                        ),
                                      ),
                                      selected: isSel,
                                      selectedColor: AppColors.navy,
                                      backgroundColor: AppColors.slate100,
                                      side: BorderSide(
                                        color: isSel ? AppColors.navy : AppColors.slate200,
                                      ),
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      onSelected: (_) => _onClassSelected(lvl),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // PENDING CLASS REQUEST BANNER
                        Builder(builder: (context) {
                          final reqCount = _stats['class_requests'] as int? ?? 0;
                          return Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.violet.withAlpha(25),
                                  AppColors.blue.withAlpha(15),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.violet.withAlpha(60)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppColors.violet.withAlpha(30),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.shield_outlined,
                                    color: AppColors.violet,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Class $activeClass: $reqCount pending Class Switch Requests',
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.navy,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Students waiting for approval to join Class $activeClass.',
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          color: AppColors.slate600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: () => context.push('/admin/class-requests'),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: AppColors.violet,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'Manage',
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(width: 2),
                                        const Icon(Icons.arrow_forward_rounded, size: 12, color: Colors.white),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                        const SizedBox(height: 20),

                        // MAIN STATISTICS GRID (2-Column Grid)
                        FadeTransition(
                          opacity: _fadeAnimation ?? const AlwaysStoppedAnimation(1.0),
                          child: GridView.count(
                            crossAxisCount: 2,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 1.25,
                            children: [
                              _StatTile(
                                icon: Icons.emoji_events_outlined,
                                category: 'CLASS $activeClass · LEADERBOARD',
                                val: _stats.containsKey('leaderboard') ? '${_stats['leaderboard']}' : '—',
                                route: '/admin/leaderboard',
                                color: const Color(0xFFD97706),
                                isLoading: _cardLoading,
                              ),
                              _StatTile(
                                icon: Icons.menu_book_outlined,
                                category: 'CLASS $activeClass · QUESTIONS',
                                val: '${_stats['questions'] ?? 0}',
                                route: '/admin/questions',
                                color: AppColors.blue,
                                isLoading: _cardLoading,
                              ),
                              _StatTile(
                                icon: Icons.assignment_outlined,
                                category: 'CLASS $activeClass · TESTS',
                                val: '${_stats['tests'] ?? 0}',
                                route: '/admin/tests',
                                color: AppColors.violet,
                                isLoading: _cardLoading,
                              ),
                              _StatTile(
                                icon: Icons.play_circle_outline,
                                category: 'CLASS $activeClass · VIDEOS',
                                val: '${_stats['videos'] ?? 0}',
                                route: '/admin/videos',
                                color: AppColors.navy,
                                isLoading: _cardLoading,
                              ),
                              _StatTile(
                                icon: Icons.style_outlined,
                                category: 'CLASS $activeClass · FLASHCARDS',
                                val: _stats.containsKey('flashcards') ? '${_stats['flashcards']}' : '—',
                                route: '/admin/flashcards',
                                color: AppColors.violet,
                                isLoading: _cardLoading,
                              ),
                              _StatTile(
                                icon: Icons.bar_chart_outlined,
                                category: 'CLASS $activeClass · ANALYTICS',
                                val: '${_stats['attempts'] ?? 0}',
                                route: '/admin/analytics',
                                color: AppColors.blue,
                                isLoading: _cardLoading,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // ALL OTHER ADMIN QUICK ACTIONS LIST
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.slate200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'MORE ADMIN OPERATIONS',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.5,
                                  color: AppColors.violet,
                                ),
                              ),
                              const SizedBox(height: 12),
                              const _QuickActionRow(
                                icon: Icons.article_outlined,
                                text: 'Publish study notes',
                                route: '/admin/notes',
                                color: AppColors.violet,
                              ),
                              const _QuickActionRow(
                                icon: Icons.local_offer_outlined,
                                text: 'Publish offer promo banners',
                                route: '/admin/promos',
                                color: Color(0xFF059669),
                              ),
                              const _QuickActionRow(
                                icon: Icons.card_giftcard_outlined,
                                text: 'Create & manage premium plans',
                                route: '/admin/plans',
                                color: AppColors.blue,
                              ),
                              const _QuickActionRow(
                                icon: Icons.campaign_outlined,
                                text: 'Broadcast announcements',
                                route: '/admin/announcements',
                                color: AppColors.navy,
                              ),
                              const _QuickActionRow(
                                icon: Icons.group_outlined,
                                text: 'Manage registered students',
                                route: '/admin/users',
                                color: AppColors.blue,
                              ),
                              const _QuickActionRow(
                                icon: Icons.payment_outlined,
                                text: 'View payment transactions',
                                route: '/admin/payments',
                                color: AppColors.navy,
                              ),
                              if (isSuperAdmin)
                                const _QuickActionRow(
                                  icon: Icons.admin_panel_settings_outlined,
                                  text: 'Manage Admin Accounts',
                                  route: '/superadmin',
                                  color: AppColors.error,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }
}

class _QuickAccessCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String route;
  final Color iconColor;

  const _QuickAccessCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.route,
    required this.iconColor,
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
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(6),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: iconColor),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            Text(
              subtitle,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: AppColors.slate500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Row(
              children: [
                Text(
                  'Manage',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.blue,
                  ),
                ),
                const SizedBox(width: 2),
                const Icon(Icons.arrow_forward_rounded, size: 12, color: AppColors.blue),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String category;
  final String val;
  final String route;
  final Color color;
  final bool isLoading;

  const _StatTile({
    required this.icon,
    required this.category,
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
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(4),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    category,
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: AppColors.slate500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(icon, size: 16, color: color),
              ],
            ),
            if (isLoading)
              SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: color,
                ),
              )
            else
              Text(
                val,
                style: GoogleFonts.fraunces(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy,
                ),
              ),
            Row(
              children: [
                Text(
                  'Manage',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.blue,
                  ),
                ),
                const SizedBox(width: 2),
                const Icon(Icons.arrow_forward_rounded, size: 12, color: AppColors.blue),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final String route;
  final Color color;

  const _QuickActionRow({
    required this.icon,
    required this.text,
    required this.route,
    required this.color,
  });

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
              child: Text(
                text,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppColors.navy,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, size: 18, color: AppColors.slate400),
          ],
        ),
      ),
    );
  }
}
