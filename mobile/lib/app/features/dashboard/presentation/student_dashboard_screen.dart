import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/api/api_endpoints.dart';
import '../../../core/api/dio_client.dart';
import '../../../core/models/promo_model.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../../common/widgets/app_drawer.dart';
import '../../common/widgets/shared_widgets.dart';

// ─── countdown helpers ────────────────────────────────────────────────────────
String _fmtCountdown(Duration d) {
  if (d.isNegative || d.inSeconds <= 0) return 'starts now';
  final days = d.inDays;
  final hours = d.inHours % 24;
  final mins = d.inMinutes % 60;
  if (days > 0) return 'in ${days}d ${hours}h';
  if (hours > 0) return 'in ${hours}h ${mins}m';
  return 'in ${mins}m';
}

String _fmtPromoCountdown(Duration d) {
  if (d.isNegative || d.inSeconds <= 0) return 'Expired';
  final h = d.inHours;
  final m = d.inMinutes % 60;
  final s = d.inSeconds % 60;
  return '${h}h : ${m.toString().padLeft(2, '0')}m : ${s.toString().padLeft(2, '0')}s';
}

DateTime? _parseTestTime(Map t, String field) {
  try {
    final date = t['scheduled_date'] as String;
    final time = (t[field] as String?) ?? '20:00';
    return DateTime.parse('${date}T$time:00Z');
  } catch (_) {
    return null;
  }
}

String _fmtDate(DateTime dt) {
  final now = DateTime.now();
  final local = dt.toLocal();
  final diff = DateTime(local.year, local.month, local.day)
      .difference(DateTime(now.year, now.month, now.day))
      .inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Tomorrow';
  const months = [
    '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  return '${local.day} ${months[local.month]}';
}

String _fmtTime(DateTime dt) {
  final local = dt.toLocal();
  final h = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final m = local.minute.toString().padLeft(2, '0');
  final ampm = local.hour < 12 ? 'AM' : 'PM';
  return '$h:$m $ampm';
}

// ─────────────────────────────────────────────────────────────────────────────
class StudentDashboardScreen extends ConsumerStatefulWidget {
  const StudentDashboardScreen({super.key});

  @override
  ConsumerState<StudentDashboardScreen> createState() => _State();
}

class _State extends ConsumerState<StudentDashboardScreen> {
  List _upcoming = [];
  List _lb = [];
  Map? _refs;
  List _announcements = [];
  List<PromoModel> _promos = [];
  int _activePromoIndex = 0;
  Map<String, String> _promoTimes = {};
  bool _loading = true;
  Timer? _promoTimer;

  @override
  void initState() {
    super.initState();
    // Silently refresh user profile so that premium badges and quick-access
    // cards on the dashboard always show the current subscription state.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authProvider.notifier).refreshSilently();
    });
    _load();
  }

  @override
  void dispose() {
    _promoTimer?.cancel();
    super.dispose();
  }

  void _startPromoTimer() {
    _promoTimer?.cancel();
    if (_promos.isEmpty) return;
    _promoTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final updated = <String, String>{};
      for (final p in _promos) {
        updated[p.id] = _fmtPromoCountdown(p.remainingTime());
      }
      setState(() => _promoTimes = updated);
    });
  }

  Future<void> _load() async {
    final user = ref.read(authProvider).user;
    try {
      final results = await Future.wait([
        dioClient.get(ApiEndpoints.upcomingTests),
        dioClient.get(ApiEndpoints.leaderboard,
            queryParameters: {'class_level': user?.classLevel, 'limit': 5}),
        dioClient.get(ApiEndpoints.myReferrals),
        dioClient.get(ApiEndpoints.announcements),
        dioClient.get(ApiEndpoints.promos),
      ]);
      if (!mounted) return;
      final promos = (results[4].data['items'] as List? ?? [])
          .map((e) => PromoModel.fromJson(e))
          .toList();
      setState(() {
        _upcoming = results[0].data['items'] ?? [];
        _lb = results[1].data['items'] ?? [];
        _refs = results[2].data as Map;
        _announcements = results[3].data['items'] ?? [];
        _promos = promos;
        _loading = false;
      });
      _startPromoTimer();
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final isPremium = user?.subscriptionActive == true;
    final now = DateTime.now().toUtc();
    final firstName = user?.name.split(' ').first ?? '';
    final myRank = _lb.indexWhere((x) => x['user_id'] == user?.id);
    final rankStr = myRank >= 0 ? '#${myRank + 1}' : '—';

    // Find soonest upcoming test
    Map? soonest;
    DateTime? soonestStart, soonestEnd;
    for (final t in _upcoming) {
      final start = _parseTestTime(t, 'start_time');
      final end = _parseTestTime(t, 'end_time');
      if (start == null || end == null || end.isBefore(now)) continue;
      if (soonest == null || start.isBefore(soonestStart!)) {
        soonest = t;
        soonestStart = start;
        soonestEnd = end;
      }
    }
    final msToEnd =
        soonestEnd != null ? soonestEnd.difference(now) : Duration.zero;
    final msToStart =
        soonestStart != null ? soonestStart.difference(now) : Duration.zero;
    final isLive = soonest != null &&
        !msToStart.isNegative &&
        msToStart.inSeconds <= 0 &&
        !msToEnd.isNegative;
    final showReminder = soonest != null &&
        msToStart.isNegative == false &&
        msToStart < const Duration(hours: 24);

    final currentPromo =
        _promos.isNotEmpty ? _promos[_activePromoIndex] : null;

    final referralCode = _refs?['referral_code'] as String? ?? '';

    return MainScaffold(
      title: 'StudyBook',
      body: _loading
          ? const LoadingIndicator()
          : RefreshIndicator(
              onRefresh: _load,
              color: AppColors.blue,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── 1. Welcome Section ────────────────────────────────
                    _WelcomeHeader(
                      firstName: firstName,
                      isPremium: isPremium,
                    ),
                    const SizedBox(height: 20),

                    // ── 2. Offers Section ─────────────────────────────────
                    if (currentPromo != null) ...[
                      _OffersCard(
                        promo: currentPromo,
                        countdown:
                            _promoTimes[currentPromo.id] ??
                                '${currentPromo.countdownHours}h : 00m : 00s',
                        totalPromos: _promos.length,
                        activeIndex: _activePromoIndex,
                        onDotTap: (i) =>
                            setState(() => _activePromoIndex = i),
                        onViewTap: () => context.push('/pricing'),
                      ),
                      const SizedBox(height: 16),
                    ] else ...[
                      _OffersEmptyCard(onViewTap: () => context.push('/pricing')),
                      const SizedBox(height: 16),
                    ],

                    // ── 3. Announcement Banner (compact, scrollable) ───────
                    if (_announcements.isNotEmpty) ...[
                      _CompactAnnouncementBanner(
                        announcements: _announcements,
                      ),
                      const SizedBox(height: 16),
                    ],

                    // ── Live / Reminder banner ─────────────────────────────
                    if (showReminder || isLive) ...[
                      _TestReminderBanner(
                        soonest: soonest,
                        isLive: isLive,
                        msToEnd: msToEnd,
                        msToStart: msToStart,
                        onTap: () => context.push(
                            isLive
                                ? '/tests/${soonest?['_id']}/live'
                                : '/tests'),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // ── 4. Test Schedule ──────────────────────────────────
                    _TestScheduleCard(
                      soonest: soonest,
                      soonestStart: soonestStart,
                      onViewSchedule: () => context.push('/tests'),
                    ),
                    const SizedBox(height: 16),

                    // ── 4b. Daily Practice Card ───────────────────────────
                    _DailyPracticeCard(
                      isPremium: isPremium,
                      onTap: () => context.push(
                          isPremium ? '/questions' : '/pricing'),
                    ),
                    const SizedBox(height: 16),

                    // ── 5. Statistics 2×2 Grid ────────────────────────────
                    _StatisticsGrid(
                      points: user?.totalPoints ?? 0,
                      rankStr: rankStr,
                      referralCount: _refs?['count'] ?? 0,
                      referralCode: referralCode,
                    ),
                    const SizedBox(height: 20),

                    // ── 6. Quick Access (compact 2×3 grid) ────────────────
                    _QuickAccessSection(
                      isPremium: isPremium,
                      items: const [
                        _QuickItem(
                          icon: Icons.explore_rounded,
                          label: 'Study\nExplorer',
                          color: Color(0xFFE8F0FE),
                          iconColor: Color(0xFF1A73E8),
                          route: '/explorer',
                          isPremiumOnly: false,
                        ),
                        _QuickItem(
                          icon: Icons.quiz_rounded,
                          label: 'Question\nBank',
                          color: Color(0xFFF3E8FF),
                          iconColor: Color(0xFF7C3AED),
                          route: '/questions',
                          isPremiumOnly: false,
                        ),
                        _QuickItem(
                          icon: Icons.assignment_rounded,
                          label: 'Tests',
                          color: Color(0xFFE6F4EA),
                          iconColor: Color(0xFF1E8E3E),
                          route: '/tests',
                          isPremiumOnly: false,
                        ),
                        _QuickItem(
                          icon: Icons.play_circle_rounded,
                          label: 'Videos',
                          color: Color(0xFFFCE8E6),
                          iconColor: Color(0xFFD93025),
                          route: '/videos',
                          isPremiumOnly: false,
                        ),
                        _QuickItem(
                          icon: Icons.bar_chart_rounded,
                          label: 'Analytics',
                          color: Color(0xFFE3F2FD),
                          iconColor: Color(0xFF0288D1),
                          route: '/my-analytics',
                          isPremiumOnly: true,
                        ),
                        _QuickItem(
                          icon: Icons.emoji_events_rounded,
                          label: 'Leaderboard',
                          color: Color(0xFFFFF3E0),
                          iconColor: Color(0xFFF57C00),
                          route: '/leaderboard',
                          isPremiumOnly: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // ── 7. Your Ranking card ──────────────────────────────
                    _YourRankingCard(
                      rank: myRank >= 0 ? myRank + 1 : null,
                      points: user?.totalPoints ?? 0,
                      isPremium: isPremium,
                      onViewAll: () => context.push('/leaderboard'),
                    ),
                    const SizedBox(height: 16),

                    // ── 8. Continue Learning CTAs ──────────────────────────
                    _GradientCTA(
                      gradient: AppColors.blueVioletGradient,
                      eyebrow: 'INSIGHTS',
                      title: 'Your strengths & weaknesses',
                      subtitle:
                          'See exactly where you shine and what to work on.',
                      actionText: 'View my analytics',
                      backgroundIcon: Icons.bar_chart_rounded,
                      onTap: () => context.push('/my-analytics'),
                    ),
                    const SizedBox(height: 12),
                    _GradientCTA(
                      gradient: AppColors.navyPurpleGradient,
                      eyebrow: 'GO PREMIUM',
                      title: 'Unlock finals + videos',
                      subtitle:
                          'Premium members get exclusive content from your admin.',
                      actionText: 'See plans',
                      backgroundIcon: Icons.workspace_premium_rounded,
                      onTap: () => context.push('/pricing'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 1. Welcome Header
// ─────────────────────────────────────────────────────────────────────────────

class _WelcomeHeader extends StatelessWidget {
  final String firstName;
  final bool isPremium;
  const _WelcomeHeader({required this.firstName, required this.isPremium});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'WELCOME BACK',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2.5,
                  color: AppColors.blue,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Hey, $firstName! 👋',
                style: GoogleFonts.fraunces(
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      gradient: isPremium
                          ? const LinearGradient(colors: [
                              Color(0xFF7C3AED),
                              Color(0xFF1A73E8),
                            ])
                          : null,
                      color: isPremium ? null : AppColors.slate100,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isPremium
                              ? Icons.workspace_premium_rounded
                              : Icons.person_outline_rounded,
                          size: 11,
                          color: isPremium ? Colors.white : AppColors.slate500,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isPremium ? 'Premium' : 'Free Plan',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isPremium ? Colors.white : AppColors.slate500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '· Your personalised study space',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.slate400,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 2. Compact Announcement Banner (horizontally scrollable chips)
// ─────────────────────────────────────────────────────────────────────────────

class _CompactAnnouncementBanner extends StatelessWidget {
  final List announcements;
  const _CompactAnnouncementBanner({required this.announcements});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFF0F1B4C), Color(0xFF1A3A8A)],
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(20),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.campaign_rounded,
                color: Colors.white, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: announcements.length,
              separatorBuilder: (_, __) => Container(
                width: 1,
                margin: const EdgeInsets.symmetric(
                    vertical: 16, horizontal: 10),
                color: Colors.white.withAlpha(40),
              ),
              itemBuilder: (context, i) {
                final a = announcements[i];
                final title = (a['title'] as String?) ?? '';
                final createdAt = a['created_at'] as String?;
                String dateStr = '';
                if (createdAt != null) {
                  try {
                    final dt = DateTime.parse(createdAt).toLocal();
                    const months = [
                      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
                    ];
                    dateStr = '${dt.day} ${months[dt.month]}';
                  } catch (_) {}
                }
                return GestureDetector(
                  onTap: () => context.push('/dashboard'),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (dateStr.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Text(
                            dateStr,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: Colors.white60,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 12),
          const Icon(Icons.chevron_right_rounded,
              color: Colors.white54, size: 18),
          const SizedBox(width: 10),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 3a. Offers Card (when promos exist)
// ─────────────────────────────────────────────────────────────────────────────

class _OffersCard extends StatelessWidget {
  final PromoModel promo;
  final String countdown;
  final int totalPromos;
  final int activeIndex;
  final ValueChanged<int> onDotTap;
  final VoidCallback onViewTap;

  const _OffersCard({
    required this.promo,
    required this.countdown,
    required this.totalPromos,
    required this.activeIndex,
    required this.onDotTap,
    required this.onViewTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: [0.0, 0.5, 1.0],
          colors: [
            Color(0xFF0F1B4C),
            Color(0xFF1E3A8A),
            Color(0xFF4C1D95),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Stack(
        children: [
          // Background icon
          Positioned(
            right: -16,
            top: -16,
            child: Icon(
              Icons.card_giftcard_rounded,
              size: 110,
              color: Colors.white.withAlpha(18),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFBBF24).withAlpha(30),
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(
                            color: const Color(0xFFFBBF24).withAlpha(80)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.local_offer_rounded,
                              size: 12, color: Color(0xFFFBBF24)),
                          const SizedBox(width: 5),
                          Text(
                            'SPECIAL OFFER',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFFFBBF24),
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  promo.title,
                  style: GoogleFonts.fraunces(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  promo.subtitle,
                  style: GoogleFonts.inter(
                      fontSize: 13, color: const Color(0xFFCBD5E1)),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    // Code badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: const Color(0xFFF59E0B).withAlpha(80)),
                      ),
                      child: Text(
                        promo.code,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFFBBF24),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Countdown
                    Text(
                      'Ends in: $countdown',
                      style: GoogleFonts.inter(
                          fontSize: 11, color: Colors.white60),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: onViewTap,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFBBF24),
                        foregroundColor: const Color(0xFF0F1B4C),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(99)),
                        elevation: 0,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('View Offer',
                              style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700)),
                          const SizedBox(width: 5),
                          const Icon(Icons.arrow_forward_rounded, size: 13),
                        ],
                      ),
                    ),
                    if (totalPromos > 1) ...[
                      const SizedBox(width: 14),
                      ...List.generate(
                        totalPromos,
                        (i) => GestureDetector(
                          onTap: () => onDotTap(i),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin:
                                const EdgeInsets.symmetric(horizontal: 3),
                            width: i == activeIndex ? 16 : 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: i == activeIndex
                                  ? Colors.white
                                  : Colors.white.withAlpha(60),
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 3b. Offers Empty State Card
// ─────────────────────────────────────────────────────────────────────────────

class _OffersEmptyCard extends StatelessWidget {
  final VoidCallback onViewTap;
  const _OffersEmptyCard({required this.onViewTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.slate200),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withAlpha(6),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.violet.withAlpha(15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.card_giftcard_rounded,
                size: 20, color: AppColors.violet),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No offers right now',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.navy,
                  ),
                ),
                Text(
                  'Check back soon for exclusive deals',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.slate500,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onViewTap,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                gradient: AppColors.blueVioletGradient,
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                'View Plans',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 4. Test Schedule Card
// ─────────────────────────────────────────────────────────────────────────────

class _TestScheduleCard extends StatelessWidget {
  final Map? soonest;
  final DateTime? soonestStart;
  final VoidCallback onViewSchedule;

  const _TestScheduleCard({
    required this.soonest,
    required this.soonestStart,
    required this.onViewSchedule,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.slate200),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withAlpha(7),
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Calendar icon area
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: AppColors.blue.withAlpha(12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.calendar_month_rounded,
                color: AppColors.blue, size: 24),
          ),
          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TEST SCHEDULE',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                    color: AppColors.blue,
                  ),
                ),
                const SizedBox(height: 2),
                soonest == null
                    ? Text(
                        'No upcoming tests',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.slate500,
                        ),
                      )
                    : Text(
                        (soonest!['title'] as String?) ?? 'Upcoming Test',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.navy,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                if (soonestStart != null) ...[
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.blue.withAlpha(12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _fmtDate(soonestStart!),
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.blue,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _fmtTime(soonestStart!),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.slate500,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),

          // View Schedule button
          GestureDetector(
            onTap: onViewSchedule,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.navy,
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                'View',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 4b. Daily Practice Card (Premium Only)
// ─────────────────────────────────────────────────────────────────────────────

class _DailyPracticeCard extends StatelessWidget {
  final bool isPremium;
  final VoidCallback onTap;

  const _DailyPracticeCard({
    required this.isPremium,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFDE68A).withAlpha(180)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF59E0B).withAlpha(20),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Subtle background icon
          Positioned(
            right: -10,
            top: -10,
            child: Icon(
              Icons.auto_stories_rounded,
              size: 90,
              color: const Color(0xFFFBBF24).withAlpha(22),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                // Left accent icon area
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFFBBF24), Color(0xFFF97316)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Center(
                    child: Text(
                      '⭐',
                      style: TextStyle(fontSize: 24),
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Middle text content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'DAILY PRACTICE',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                          color: const Color(0xFFF59E0B),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Practice Today\'s Question',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.navy,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Solve today\'s featured question and improve your score.',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.slate500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),

                // Practice Now button
                GestureDetector(
                  onTap: onTap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 13, vertical: 9),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFBBF24), Color(0xFFF97316)],
                      ),
                      borderRadius: BorderRadius.circular(99),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFF59E0B).withAlpha(60),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!isPremium)
                          const Icon(Icons.lock_rounded,
                              size: 13, color: Color(0xFF0F1B4C)),
                        if (!isPremium) const SizedBox(width: 4),
                        Text(
                          'Practice Now',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0F1B4C),
                          ),
                        ),
                        if (isPremium) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.arrow_forward_rounded,
                              size: 13, color: Color(0xFF0F1B4C)),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 5. Statistics 2×2 Grid
// ─────────────────────────────────────────────────────────────────────────────

class _StatisticsGrid extends StatelessWidget {
  final int points;
  final String rankStr;
  final int referralCount;
  final String referralCode;

  const _StatisticsGrid({
    required this.points,
    required this.rankStr,
    required this.referralCount,
    required this.referralCode,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'STATISTICS',
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
            color: AppColors.violet,
          ),
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final cardWidth = (constraints.maxWidth - 12) / 2;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: cardWidth,
                  child: StatCard(
                    icon: Icons.emoji_events_rounded,
                    label: 'Total Points',
                    value: '$points',
                    iconColor: AppColors.violet,
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: StatCard(
                    icon: Icons.trending_up_rounded,
                    label: 'Class Rank',
                    value: rankStr,
                    iconColor: AppColors.blue,
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: StatCard(
                    icon: Icons.group_rounded,
                    label: 'Referrals',
                    value: '$referralCount',
                    iconColor: AppColors.navy,
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _ReferralCodeCard(code: referralCode),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Referral Code Card with Copy Button
// ─────────────────────────────────────────────────────────────────────────────

class _ReferralCodeCard extends StatelessWidget {
  final String code;
  const _ReferralCodeCard({required this.code});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.slate200),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withAlpha(10),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  'REFERRAL CODE',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                    color: AppColors.slate500,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.violet.withAlpha(30),
                      AppColors.violet.withAlpha(40),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Icon(Icons.stars_rounded,
                      size: 20, color: AppColors.violet),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              code.isEmpty ? '—' : code,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.navy,
              ),
            ),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () {
              if (code.isEmpty) return;
              Clipboard.setData(ClipboardData(text: code));
              ScaffoldMessenger.of(context).clearSnackBars();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.check_circle_outline,
                          color: Colors.white, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'Referral code copied.',
                        style: GoogleFonts.inter(
                            color: Colors.white, fontSize: 13),
                      ),
                    ],
                  ),
                  backgroundColor: AppColors.navy,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  margin: const EdgeInsets.all(16),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.slate100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.copy_rounded,
                      size: 12, color: AppColors.slate500),
                  const SizedBox(width: 5),
                  Text(
                    'Copy Code',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.slate600,
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
// 6. Quick Access Section (compact 2×3 grid ~95×95)
// ─────────────────────────────────────────────────────────────────────────────

class _QuickItem {
  final IconData icon;
  final String label;
  final Color color;
  final Color iconColor;
  final String route;
  final bool isPremiumOnly;

  const _QuickItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.iconColor,
    required this.route,
    required this.isPremiumOnly,
  });
}

class _QuickAccessSection extends ConsumerWidget {
  final List<_QuickItem> items;
  final bool isPremium;
  const _QuickAccessSection(
      {required this.items, required this.isPremium});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'QUICK ACCESS',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.8,
                color: AppColors.violet,
              ),
            ),
            GestureDetector(
              onTap: () => context.push('/explorer'),
              child: Row(
                children: [
                  Text(
                    'View All',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.blue,
                    ),
                  ),
                  const SizedBox(width: 2),
                  const Icon(Icons.arrow_outward_rounded,
                      size: 14, color: AppColors.blue),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            // Always 3 columns → ~95px wide cards
            const cols = 3;
            const spacing = 10.0;
            final cardWidth =
                (constraints.maxWidth - spacing * (cols - 1)) / cols;
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: items
                  .map((item) => SizedBox(
                        width: cardWidth,
                        child: _QuickAccessCard(
                          item: item,
                          isPremium: isPremium,
                        ),
                      ))
                  .toList(),
            );
          },
        ),
      ],
    );
  }
}

class _QuickAccessCard extends StatefulWidget {
  final _QuickItem item;
  final bool isPremium;
  const _QuickAccessCard(
      {required this.item, required this.isPremium});

  @override
  State<_QuickAccessCard> createState() => _QuickAccessCardState();
}

class _QuickAccessCardState extends State<_QuickAccessCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0.0,
      upperBound: 1.0,
    );
    _scale = Tween<double>(begin: 1.0, end: 0.94).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) => _ctrl.forward();
  void _onTapUp(TapUpDetails _) => _ctrl.reverse();
  void _onTapCancel() => _ctrl.reverse();

  @override
  Widget build(BuildContext context) {
    final isLocked = widget.item.isPremiumOnly && !widget.isPremium;

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: () => context.push(widget.item.route),
      child: AnimatedBuilder(
        animation: _scale,
        builder: (_, child) =>
            Transform.scale(scale: _scale.value, child: child),
        child: Container(
          // Target: ~95×95 — achieved via padding + constrained icon
          padding:
              const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          decoration: BoxDecoration(
            color: widget.item.color,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: widget.item.iconColor.withAlpha(30), width: 1),
            boxShadow: [
              BoxShadow(
                color: widget.item.iconColor.withAlpha(15),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                alignment: Alignment.topRight,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: widget.item.iconColor.withAlpha(22),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      widget.item.icon,
                      color: widget.item.iconColor,
                      size: 18,
                    ),
                  ),
                  // Premium lock badge
                  if (isLocked)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          gradient: AppColors.navyPurpleGradient,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: Colors.white, width: 1.5),
                        ),
                        child: const Icon(Icons.lock_rounded,
                            size: 8, color: Colors.white),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 7),
              Text(
                widget.item.label,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.navy,
                  height: 1.3,
                ),
              ),
              if (isLocked) ...[
                const SizedBox(height: 3),
                Text(
                  'Premium',
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: AppColors.violet,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}



// ─────────────────────────────────────────────────────────────────────────────
// Gradient CTA card
// ─────────────────────────────────────────────────────────────────────────────

class _GradientCTA extends StatelessWidget {
  final Gradient gradient;
  final String eyebrow;
  final String title;
  final String subtitle;
  final String actionText;
  final IconData backgroundIcon;
  final VoidCallback onTap;

  const _GradientCTA({
    required this.gradient,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.actionText,
    required this.backgroundIcon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  eyebrow,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: Colors.white70,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  title,
                  style: GoogleFonts.fraunces(
                    fontSize: 20,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                      fontSize: 13, color: Colors.white70, height: 1.4),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(25),
                    borderRadius: BorderRadius.circular(99),
                    border:
                        Border.all(color: Colors.white.withAlpha(60)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        actionText,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 5),
                      const Icon(Icons.arrow_forward_rounded,
                          size: 13, color: Colors.white),
                    ],
                  ),
                ),
              ],
            ),
            Positioned(
              right: -14,
              bottom: -14,
              child: Icon(backgroundIcon,
                  size: 90, color: Colors.white.withAlpha(22)),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Test reminder banner (live/upcoming)
// ─────────────────────────────────────────────────────────────────────────────

class _TestReminderBanner extends StatelessWidget {
  final Map? soonest;
  final bool isLive;
  final Duration msToEnd;
  final Duration msToStart;
  final VoidCallback onTap;

  const _TestReminderBanner({
    required this.soonest,
    required this.isLive,
    required this.msToEnd,
    required this.msToStart,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color bgColor = isLive
        ? AppColors.violet.withAlpha(20)
        : AppColors.blue.withAlpha(10);
    final Color borderColor = isLive
        ? AppColors.violet.withAlpha(80)
        : AppColors.blue.withAlpha(50);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isLive ? AppColors.violet : AppColors.blue,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isLive
                  ? Icons.radio_button_checked_rounded
                  : Icons.notifications_active_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isLive ? 'TEST IS LIVE' : 'UPCOMING TEST',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                    color: isLive ? AppColors.violet : AppColors.blue,
                  ),
                ),
                const SizedBox(height: 2),
                RichText(
                  text: TextSpan(
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.navy),
                    children: [
                      TextSpan(text: (soonest?['title'] as String?) ?? ''),
                      TextSpan(
                        text:
                            ' — ${isLive ? 'ends ${_fmtCountdown(msToEnd)}' : _fmtCountdown(msToStart)}',
                        style: GoogleFonts.inter(
                            fontSize: 13,
                            color: AppColors.slate500,
                            fontWeight: FontWeight.w400),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            onPressed: onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: isLive ? AppColors.violet : AppColors.navy,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(99)),
              elevation: 0,
            ),
            child: Text(
              isLive ? 'Start' : 'View',
              style:
                  GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Your Ranking card — compact, shows only the logged-in student's stats
// ─────────────────────────────────────────────────────────────────────────────

class _YourRankingCard extends StatelessWidget {
  /// 1-based rank position, or null if not ranked yet.
  final int? rank;
  final int points;
  final bool isPremium;
  final VoidCallback onViewAll;

  const _YourRankingCard({
    required this.rank,
    required this.points,
    required this.isPremium,
    required this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.slate200),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withAlpha(8),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row ────────────────────────────────────────────────
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFFFDE68A),
                    width: 1,
                  ),
                ),
                child: const Center(
                  child: Text('🏆', style: TextStyle(fontSize: 17)),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Your Ranking',
                style: GoogleFonts.fraunces(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.navy,
                ),
              ),
              const Spacer(),
              // View All button — subtle, with lock for Free users
              GestureDetector(
                onTap: onViewAll,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.blue.withAlpha(12),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'View All',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.blue,
                        ),
                      ),
                      const SizedBox(width: 4),
                      isPremium
                          ? const Icon(Icons.arrow_outward_rounded,
                              size: 13, color: AppColors.blue)
                          : const Icon(Icons.lock_rounded,
                              size: 12, color: AppColors.violet),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          const Divider(height: 1, color: AppColors.slate100),
          const SizedBox(height: 16),

          // ── Rank + Points row ──────────────────────────────────────────
          Row(
            children: [
              // Rank
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'RANK',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                        color: AppColors.slate400,
                      ),
                    ),
                    const SizedBox(height: 6),
                    rank != null
                        ? RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: '#',
                                  style: GoogleFonts.fraunces(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.blue,
                                  ),
                                ),
                                TextSpan(
                                  text: '$rank',
                                  style: GoogleFonts.fraunces(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.navy,
                                    letterSpacing: -1,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Not Ranked',
                                style: GoogleFonts.fraunces(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.slate400,
                                ),
                              ),
                              Text(
                                'Yet',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: AppColors.slate400,
                                ),
                              ),
                            ],
                          ),
                  ],
                ),
              ),

              // Vertical divider
              Container(
                width: 1,
                height: 56,
                color: AppColors.slate100,
                margin: const EdgeInsets.symmetric(horizontal: 20),
              ),

              // Points
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'POINTS',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                        color: AppColors.slate400,
                      ),
                    ),
                    const SizedBox(height: 6),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '$points',
                        style: GoogleFonts.fraunces(
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          color: AppColors.navy,
                          letterSpacing: -1,
                        ),
                      ),
                    ),
                    Text(
                      'total pts',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppColors.slate400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
