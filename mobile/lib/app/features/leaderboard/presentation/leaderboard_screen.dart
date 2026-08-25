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

class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  List _items = [];
  bool _loading = true;
  String _classLevel = 'all';
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
    _scaleAnim = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );
    _animController.forward();
    // Silently refresh user profile before checking premium status.
    // Ensures premium upgrades granted by Super Admin are reflected
    // immediately when the student navigates to this screen.
    ref.read(authProvider.notifier).refreshSilently().then((_) {
      if (mounted) {
        final user = ref.read(authProvider).user;
        // Students are auto-pinned to their assigned class
        if (user != null && !user.isAdmin && user.classLevel != null) {
          _classLevel = user.classLevel!;
        }
        _load();
      }
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final user = ref.read(authProvider).user;
    if (user?.subscriptionActive != true) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    setState(() => _loading = true);
    try {
      final params = <String, dynamic>{'limit': 100};
      if (_classLevel != 'all') params['class_level'] = _classLevel;
      final r = await dioClient.get(ApiEndpoints.leaderboard, queryParameters: params);
      if (mounted) {
        setState(() {
          _items = r.data['items'] ?? [];
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        showToast(context, formatApiError(e), isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final isPremium = user?.subscriptionActive == true;

    if (!isPremium) {
      return MainScaffold(
        title: 'Leaderboard',
        body: Container(
          color: Colors.white,
          width: double.infinity,
          height: double.infinity,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: FadeTransition(
                opacity: _fadeAnim,
                child: ScaleTransition(
                  scale: _scaleAnim,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Centered trophy illustration inside soft rounded container
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB), // Amber-50 background
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: const Color(0xFFFDE68A), // Amber-200 border
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFF59E0B).withAlpha(31),
                              blurRadius: 20,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.emoji_events_rounded,
                            size: 40,
                            color: Color(0xFFD97706), // Amber-600 gold icon
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Title
                      Text(
                        'Premium Feature',
                        style: GoogleFonts.fraunces(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: AppColors.navy,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 14),
                      // Description matching Web UI reference
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 340),
                        child: Text(
                          'The leaderboard is exclusive to Premium users.\nUpgrade your subscription to compete with other students,\ntrack rankings,\nand unlock detailed performance insights.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: AppColors.slate600,
                            height: 1.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      // Upgrade to Premium Button
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(99),
                          onTap: () => context.push('/pricing'),
                          splashColor: Colors.white24,
                          highlightColor: Colors.white10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF7C3AED), // StudyBook Premium Purple
                              borderRadius: BorderRadius.circular(99),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF7C3AED).withAlpha(77),
                                  blurRadius: 14,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Text(
                              'Upgrade to Premium',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
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
      );
    }

    return MainScaffold(
      title: 'Leaderboard',
      body: Column(
        children: [
          // Class selector — read-only for students, dropdown for admins
          Builder(builder: (context) {
            final user = ref.read(authProvider).user;
            final isStudent = user != null && !user.isAdmin;
            if (isStudent) {
              return Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                color: AppColors.white,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.blue.withAlpha(10),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.blue.withAlpha(40)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.school_rounded, size: 14, color: AppColors.blue),
                          const SizedBox(width: 6),
                          Text(
                            _classLevel == 'all' ? 'All Classes' : 'Class $_classLevel',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.blue,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }
            return Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              color: AppColors.white,
              child: Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _classLevel,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        isDense: true,
                      ),
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('All classes')),
                        DropdownMenuItem(value: '8', child: Text('Class 8')),
                        DropdownMenuItem(value: '9', child: Text('Class 9')),
                        DropdownMenuItem(value: '10', child: Text('Class 10')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _classLevel = val);
                          _load();
                        }
                      },
                    ),
                  ),
                ],
              ),
            );
          }),
          const Divider(height: 1, color: AppColors.slate200),
          Expanded(
            child: _loading
                ? const LoadingIndicator()
                : _items.isEmpty
                    ? const EmptyState(message: 'No rankings yet — take a test to appear!', icon: Icons.emoji_events_outlined)
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _items.length,
                          itemBuilder: (ctx, i) {
                            final r = _items[i] as Map;
                            final bool isMe = r['user_id'] == user?.id;
                            final int rank = r['rank'] ?? (i + 1);

                            Widget rankWidget;
                            if (rank == 1) {
                              rankWidget = const Icon(Icons.emoji_events, color: Color(0xFFB45309), size: 20); // Amber 700
                            } else if (rank == 2) {
                              rankWidget = const Icon(Icons.emoji_events, color: AppColors.slate600, size: 20);
                            } else if (rank == 3) {
                              rankWidget = const Icon(Icons.emoji_events, color: Color(0xFFC2410C), size: 20); // Orange 700
                            } else {
                              rankWidget = Text('#$rank', style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.slate600));
                            }

                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: isMe ? AppColors.violet.withAlpha(15) : AppColors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: isMe ? AppColors.violet.withAlpha(60) : AppColors.slate200),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 38, height: 38,
                                    decoration: BoxDecoration(
                                      color: rank == 1 ? const Color(0xFFFEF3C7) : rank == 2 ? AppColors.slate100 : rank == 3 ? const Color(0xFFFFEDD5) : AppColors.slate50,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Center(child: rankWidget),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              r['name'] ?? '',
                                              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.navy),
                                            ),
                                            if (isMe) ...[
                                              const SizedBox(width: 6),
                                              Text('(you)', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.violet)),
                                            ],
                                          ],
                                        ),
                                        Text('Class ${r['class_level'] ?? '—'}', style: GoogleFonts.inter(fontSize: 12, color: AppColors.slate500)),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    '${r['total_points']} pts',
                                    style: GoogleFonts.jetBrainsMono(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.blue),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

