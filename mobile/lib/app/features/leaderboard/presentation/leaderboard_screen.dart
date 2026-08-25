import 'dart:convert';
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

ImageProvider? _getUserAvatarProvider(String? avatarUrl) {
  if (avatarUrl == null || avatarUrl.trim().isEmpty) return null;
  final trimmed = avatarUrl.trim();
  if (trimmed.startsWith('data:image/')) {
    try {
      final base64Str = trimmed.split(',').last;
      final bytes = base64Decode(base64Str);
      return MemoryImage(bytes);
    } catch (_) {
      return null;
    }
  }
  return NetworkImage(trimmed);
}

class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen> {
  int _step = 1; // 1 = Select Class, 2 = Select Test, 3 = Leaderboard & Release Control
  String _classLevel = 'all';
  String _selectedTestId = 'total';
  Map? _selectedTest;

  List _tests = [];
  List _items = [];

  bool _loadingTests = false;
  bool _loadingRankings = false;
  String? _blockedMsg;

  bool _releaseStatus = false;
  bool _releaseLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authProvider.notifier).refreshSilently().then((_) {
        if (mounted) {
          final user = ref.read(authProvider).user;
          if (user != null && !user.isAdmin && user.classLevel != null) {
            _classLevel = user.classLevel!;
          }
          _fetchTests();
        }
      });
    });
  }

  Future<void> _fetchTests() async {
    setState(() => _loadingTests = true);
    try {
      final params = <String, dynamic>{};
      if (_classLevel != 'all') params['class_level'] = _classLevel;
      final res = await dioClient.get(ApiEndpoints.tests, queryParameters: params);
      final rawItems = (res.data['items'] as List?) ?? [];
      if (mounted) {
        setState(() {
          _tests = rawItems.where((t) => t['is_published'] == true).toList();
          _loadingTests = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingTests = false);
        showToast(context, formatApiError(e), isError: true);
      }
    }
  }

  Future<void> _fetchReleaseStatus() async {
    final user = ref.read(authProvider).user;
    if (user?.isAdmin != true || _step != 3) return;

    try {
      if (_selectedTestId == 'total') {
        final res = await dioClient.get(ApiEndpoints.adminLeaderboardReleaseStatus);
        if (mounted) setState(() => _releaseStatus = res.data['released'] == true);
      } else {
        final res = await dioClient.get(ApiEndpoints.adminTestLeaderboardReleaseStatus(_selectedTestId));
        if (mounted) setState(() => _releaseStatus = res.data['released'] == true);
      }
    } catch (e) {
      debugPrint('Error fetching release status: $e');
    }
  }

  Future<void> _toggleRelease() async {
    setState(() => _releaseLoading = true);
    try {
      if (_selectedTestId == 'total') {
        final res = await dioClient.post(
          ApiEndpoints.adminLeaderboardRelease,
          data: {'released': !_releaseStatus},
        );
        final bool newRel = res.data['released'] == true;
        if (mounted) {
          setState(() {
            _releaseStatus = newRel;
            _releaseLoading = false;
          });
          showToast(context, newRel ? 'Overall leaderboard released to students!' : 'Overall leaderboard hidden from students.');
        }
      } else {
        final res = await dioClient.post(
          ApiEndpoints.adminTestLeaderboardRelease(_selectedTestId),
          data: {'released': !_releaseStatus},
        );
        final bool newRel = res.data['released'] == true;
        if (mounted) {
          setState(() {
            _releaseStatus = newRel;
            _releaseLoading = false;
          });
          showToast(context, newRel ? 'Test leaderboard released to students!' : 'Test leaderboard hidden from students.');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _releaseLoading = false);
        showToast(context, 'Failed to toggle release status.', isError: true);
      }
    }
  }

  Future<void> _fetchRankings() async {
    if (_step != 3) return;
    setState(() {
      _loadingRankings = true;
      _blockedMsg = null;
    });

    try {
      final params = <String, dynamic>{'limit': 100};
      if (_classLevel != 'all') params['class_level'] = _classLevel;
      if (_selectedTestId != 'total') params['test_id'] = _selectedTestId;

      final res = await dioClient.get(ApiEndpoints.leaderboard, queryParameters: params);
      if (mounted) {
        setState(() {
          _items = res.data['items'] ?? [];
          _loadingRankings = false;
        });
      }
    } catch (e) {
      if (mounted) {
        final String errStr = formatApiError(e);
        setState(() {
          _loadingRankings = false;
          if (errStr.contains('Leaderboard will be displayed shortly') || errStr.contains('403')) {
            _blockedMsg = 'Leaderboard will be displayed shortly by the admin...';
            _items = [];
          } else {
            showToast(context, errStr, isError: true);
          }
        });
      }
    }
  }

  void _onSelectClass(String cl) {
    setState(() {
      _classLevel = cl;
      _step = 2;
    });
    _fetchTests();
  }

  void _onSelectTest(String testId, [Map? testObj]) {
    setState(() {
      _selectedTestId = testId;
      _selectedTest = testObj;
      _step = 3;
    });
    _fetchReleaseStatus();
    _fetchRankings();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final isStudent = user != null && !user.isAdmin;
    final isPremium = user?.subscriptionActive == true;

    // Premium Lock for Non-Premium Students
    if (isStudent && !isPremium) {
      return MainScaffold(
        title: 'Leaderboard',
        body: Container(
          color: Colors.white,
          width: double.infinity,
          height: double.infinity,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFFFDE68A), width: 1.5),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.emoji_events_rounded,
                        size: 40,
                        color: Color(0xFFD97706),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Premium Feature',
                    style: GoogleFonts.fraunces(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.navy),
                  ),
                  const SizedBox(height: 14),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 340),
                    child: Text(
                      'The leaderboard is exclusive to Premium users.\nUpgrade your subscription today to see where you rank!',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(fontSize: 14, color: AppColors.slate600, height: 1.5),
                    ),
                  ),
                  const SizedBox(height: 28),
                  ElevatedButton(
                    onPressed: () => context.push('/pricing'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7C3AED),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                    ),
                    child: Text('Upgrade to Premium', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return MainScaffold(
      title: 'Leaderboard',
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Dashboard Back Button
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextButton.icon(
                  onPressed: () {
                    if (_step == 3) {
                      setState(() => _step = 2);
                    } else if (_step == 2) {
                      setState(() => _step = 1);
                    } else if (context.canPop()) {
                      context.pop();
                    } else {
                      final user = ref.read(authProvider).user;
                      context.go(user?.isAdmin == true ? '/admin' : '/dashboard');
                    }
                  },
                  icon: const Icon(Icons.arrow_back_rounded, size: 16, color: AppColors.slate600),
                  label: Text('Back', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.slate600)),
                ),
              ),

              // ── WEB-IDENTICAL PROGRESS STEPPER HEADER ─────────────────────
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.slate200),
                  boxShadow: [
                    BoxShadow(color: AppColors.navy.withAlpha(6), blurRadius: 10, offset: const Offset(0, 2)),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _StepButton(
                        stepNumber: 1,
                        label: '1. Select Class',
                        active: _step == 1,
                        onTap: () => setState(() => _step = 1),
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.slate300),
                    Expanded(
                      child: _StepButton(
                        stepNumber: 2,
                        label: '2. Select Test',
                        active: _step == 2,
                        onTap: () => setState(() => _step = 2),
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.slate300),
                    Expanded(
                      child: _StepButton(
                        stepNumber: 3,
                        label: '3. Leaderboard & Release',
                        active: _step == 3,
                        disabled: _step < 3,
                        onTap: () => setState(() => _step = 3),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ── STEP CONTENT ────────────────────────────────────────────────
              if (_step == 1)
                _buildStep1ClassSelection(isStudent)
              else if (_step == 2)
                _buildStep2TestSelection()
              else
                _buildStep3Leaderboard(user),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  // STEP 1: SELECT CLASS LEVEL
  Widget _buildStep1ClassSelection(bool isStudent) {
    final classesList = [
      if (!isStudent)
        {
          'id': 'all',
          'label': 'All Classes',
          'desc': 'Overall school-wide rankings across all grade levels',
          'bgColor': const Color(0xFFF3E8FF),
          'iconColor': const Color(0xFF7C3AED),
          'borderColor': const Color(0xFFE9D5FF),
        },
      {
        'id': '8',
        'label': 'Class 8',
        'desc': 'Leaderboards for Grade 8 students',
        'bgColor': const Color(0xFFEFF6FF),
        'iconColor': const Color(0xFF2563EB),
        'borderColor': const Color(0xFFBFDBFE),
      },
      {
        'id': '9',
        'label': 'Class 9',
        'desc': 'Leaderboards for Grade 9 students',
        'bgColor': const Color(0xFFECFDF5),
        'iconColor': const Color(0xFF047857),
        'borderColor': const Color(0xFFA7F3D0),
      },
      {
        'id': '10',
        'label': 'Class 10',
        'desc': 'Leaderboards for Grade 10 students',
        'bgColor': const Color(0xFFFFFBEB),
        'iconColor': const Color(0xFFB45309),
        'borderColor': const Color(0xFFFDE68A),
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'STEP 1 OF 3',
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 2.0,
            color: const Color(0xFF7C3AED),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Select Class Level',
          style: GoogleFonts.fraunces(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: AppColors.navy,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Choose a class to view its tests and leaderboard rankings.',
          style: GoogleFonts.inter(fontSize: 13, color: AppColors.slate500),
        ),
        const SizedBox(height: 20),

        LayoutBuilder(builder: (context, constraints) {
          final isWide = constraints.maxWidth > 550;
          final crossAxisCount = isWide ? 2 : 1;

          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              mainAxisExtent: 180,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
            ),
            itemCount: classesList.length,
            itemBuilder: (ctx, i) {
              final c = classesList[i];
              final isSelected = _classLevel == c['id'];

              return GestureDetector(
                onTap: () => _onSelectClass(c['id'] as String),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF7C3AED)
                          : AppColors.slate200,
                      width: isSelected ? 2 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isSelected
                            ? const Color(0xFF7C3AED).withAlpha(30)
                            : AppColors.navy.withAlpha(8),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
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
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: c['bgColor'] as Color,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: c['borderColor'] as Color),
                            ),
                            child: Center(
                              child: Icon(
                                Icons.school_rounded,
                                color: c['iconColor'] as Color,
                                size: 22,
                              ),
                            ),
                          ),
                          if (isSelected)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF7C3AED),
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: Text(
                                'Selected',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                        ],
                      ),

                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            c['label'] as String,
                            style: GoogleFonts.fraunces(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: AppColors.navy,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            c['desc'] as String,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: AppColors.slate500,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),

                      Container(
                        padding: const EdgeInsets.only(top: 8),
                        decoration: const BoxDecoration(
                          border: Border(
                            top: BorderSide(color: AppColors.slate100),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'View Class Tests',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF7C3AED),
                              ),
                            ),
                            const Icon(
                              Icons.arrow_forward_rounded,
                              size: 16,
                              color: Color(0xFF7C3AED),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        }),
      ],
    );
  }

  // STEP 2: SELECT TEST
  Widget _buildStep2TestSelection() {
    final classLabel =
        _classLevel == 'all' ? 'All Classes' : 'Class $_classLevel';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'STEP 2 OF 3',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2.0,
                      color: const Color(0xFF7C3AED),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Select Leaderboard / Test',
                    style: GoogleFonts.fraunces(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: () => setState(() => _step = 1),
              icon: const Icon(Icons.refresh_rounded, size: 14),
              label: Text(
                'Change Class',
                style: GoogleFonts.inter(
                    fontSize: 11, fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(99)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        RichText(
          text: TextSpan(
            style: GoogleFonts.inter(fontSize: 13, color: AppColors.slate500),
            children: [
              const TextSpan(text: 'Showing rankings options for '),
              TextSpan(
                text: classLabel,
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700, color: AppColors.navy),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Overall Total Card
        GestureDetector(
          onTap: () => _onSelectTest('total'),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFFBEB), Color(0xFFF3E8FF)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: _selectedTestId == 'total'
                    ? const Color(0xFFF59E0B)
                    : const Color(0xFFFDE68A),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFF59E0B).withAlpha(20),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Center(
                    child: Icon(Icons.emoji_events_rounded,
                        color: Color(0xFFB45309), size: 28),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              'Overall (Cumulative Points)',
                              style: GoogleFonts.fraunces(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AppColors.navy,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD97706),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'ALL TESTS',
                              style: GoogleFonts.inter(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Total points accumulated across mock and final exams.',
                        style: GoogleFonts.inter(
                            fontSize: 12, color: AppColors.slate500),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward_rounded,
                    color: Color(0xFFB45309), size: 20),
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),

        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            'INDIVIDUAL TESTS',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
              color: AppColors.slate500,
            ),
          ),
        ),

        if (_loadingTests)
          const LoadingIndicator()
        else if (_tests.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.slate200),
            ),
            child: Center(
              child: Text(
                'No published tests available for Class $_classLevel.\nSelect "Overall" above or choose another class.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                    fontSize: 13, color: AppColors.slate500, height: 1.5),
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _tests.length,
            itemBuilder: (ctx, i) {
              final t = _tests[i];
              final isFinal = t['test_type'] == 'final';
              final isSelected = _selectedTestId == t['_id'];

              return GestureDetector(
                onTap: () => _onSelectTest(t['_id'], t),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF7C3AED)
                          : AppColors.slate200,
                      width: isSelected ? 2 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.navy.withAlpha(6),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: isFinal
                              ? const Color(0xFFFEF3C7)
                              : const Color(0xFFF3E8FF),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Center(
                          child: Icon(
                            isFinal
                                ? Icons.military_tech_rounded
                                : Icons.description_rounded,
                            color: isFinal
                                ? const Color(0xFFB45309)
                                : const Color(0xFF7C3AED),
                            size: 22,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    t['title'] ?? '',
                                    style: GoogleFonts.fraunces(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.navy,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isFinal
                                        ? const Color(0xFFFFFBEB)
                                        : const Color(0xFFF3E8FF),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: isFinal
                                          ? const Color(0xFFFDE68A)
                                          : const Color(0xFFE9D5FF),
                                    ),
                                  ),
                                  child: Text(
                                    isFinal ? 'FINAL EXAM' : 'MOCK TEST',
                                    style: GoogleFonts.inter(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      color: isFinal
                                          ? const Color(0xFFB45309)
                                          : const Color(0xFF7C3AED),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${t['total_questions'] ?? t['questions']?.length ?? 0} Questions · Duration: ${t['duration_minutes'] ?? 30} mins',
                              style: GoogleFonts.inter(
                                  fontSize: 12, color: AppColors.slate500),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Row(
                        children: [
                          Text(
                            'View Leaderboard',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF7C3AED),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.arrow_forward_rounded,
                              size: 14, color: Color(0xFF7C3AED)),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  // STEP 3: LEADERBOARD & RELEASE CONTROL
  Widget _buildStep3Leaderboard(dynamic user) {
    final bool isAdmin = user?.isAdmin ?? false;
    final testTitle = _selectedTestId == 'total'
        ? 'Overall Leaderboard'
        : (_selectedTest?['title'] ?? 'Test Leaderboard');

    final classLabel =
        _classLevel == 'all' ? 'All Classes' : 'Class $_classLevel';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'STEP 3 OF 3',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2.0,
                      color: const Color(0xFF7C3AED),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    testTitle,
                    style: GoogleFonts.fraunces(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Class: $classLabel · Ranking & Scores',
                    style: GoogleFonts.inter(
                        fontSize: 12, color: AppColors.slate500),
                  ),
                ],
              ),
            ),
            Wrap(
              spacing: 6,
              children: [
                OutlinedButton(
                  onPressed: () => setState(() => _step = 2),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(99)),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  child: Text('Change Test',
                      style: GoogleFonts.inter(
                          fontSize: 11, fontWeight: FontWeight.w600)),
                ),
                OutlinedButton(
                  onPressed: () => setState(() => _step = 1),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(99)),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  child: Text('Change Class',
                      style: GoogleFonts.inter(
                          fontSize: 11, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ],
        ),

        const SizedBox(height: 20),

        // ADMIN RELEASE CONTROL BANNER
        if (isAdmin)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFFFFFBEB),
                  Color(0xFFF3E8FF),
                  Color(0xFFEFF6FF),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.slate200),
              boxShadow: [
                BoxShadow(
                  color: AppColors.navy.withAlpha(8),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        _selectedTestId == 'total'
                            ? 'Overall Leaderboard Visibility'
                            : 'Leaderboard Visibility — $testTitle',
                        style: GoogleFonts.fraunces(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.navy,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _releaseStatus
                            ? const Color(0xFF059669)
                            : const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(
                          color: _releaseStatus
                              ? const Color(0xFF059669)
                              : const Color(0xFFFDE68A),
                        ),
                      ),
                      child: Text(
                        _releaseStatus
                            ? 'LIVE TO STUDENTS'
                            : 'HIDDEN FROM STUDENTS',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: _releaseStatus
                              ? Colors.white
                              : const Color(0xFFB45309),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _selectedTestId == 'total'
                      ? 'Control whether general cumulative rankings are visible to students across the app.'
                      : 'Control whether leaderboard rankings for "$testTitle" are visible to students.',
                  style: GoogleFonts.inter(
                      fontSize: 12, color: AppColors.slate500, height: 1.4),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _releaseLoading ? null : _toggleRelease,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _releaseStatus
                          ? const Color(0xFFFFFBEB)
                          : const Color(0xFF7C3AED),
                      foregroundColor: _releaseStatus
                          ? const Color(0xFFB45309)
                          : Colors.white,
                      elevation: _releaseStatus ? 0 : 2,
                      side: _releaseStatus
                          ? const BorderSide(color: Color(0xFFFDE68A), width: 1.5)
                          : BorderSide.none,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(99)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: _releaseLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Text(
                            _releaseStatus
                                ? 'Hide Leaderboard from Students'
                                : 'Release Leaderboard to Students',
                            style: GoogleFonts.inter(
                                fontSize: 13, fontWeight: FontWeight.w700),
                          ),
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: 20),

        // RANKINGS TABLE CONTAINER
        if (_loadingRankings)
          const LoadingIndicator()
        else if (_blockedMsg != null)
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.slate200),
            ),
            child: Column(
              children: [
                const Icon(Icons.lock_clock_rounded,
                    size: 44, color: AppColors.slate400),
                const SizedBox(height: 14),
                Text(
                  _blockedMsg!,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.navy,
                      height: 1.4),
                ),
              ],
            ),
          )
        else if (_items.isEmpty)
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.slate200),
            ),
            child: Center(
              child: Text(
                _selectedTestId == 'total'
                    ? 'No rankings yet — students need to take a test to appear!'
                    : 'No student submissions found for this test yet.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                    fontSize: 13, color: AppColors.slate500, height: 1.4),
              ),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.slate200),
              boxShadow: [
                BoxShadow(
                  color: AppColors.navy.withAlpha(8),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                // Table Header
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: const BoxDecoration(
                    color: AppColors.slate50,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                    border: Border(bottom: BorderSide(color: AppColors.slate200)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'STUDENT RANK',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          color: AppColors.slate500,
                        ),
                      ),
                      Text(
                        'SCORE / POINTS',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          color: AppColors.slate500,
                        ),
                      ),
                    ],
                  ),
                ),

                // Table Rows
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _items.length,
                  separatorBuilder: (ctx, i) =>
                      const Divider(height: 1, color: AppColors.slate100),
                  itemBuilder: (ctx, i) {
                    final r = _items[i] as Map;
                    final bool isMe = r['user_id'] == user?.id;
                    final int rank = r['rank'] ?? (i + 1);

                    Widget rankWidget;
                    if (rank == 1) {
                      rankWidget = Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFEF3C7),
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Icon(Icons.workspace_premium_rounded,
                              color: Color(0xFFD97706), size: 18),
                        ),
                      );
                    } else if (rank == 2) {
                      rankWidget = Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(
                          color: AppColors.slate200,
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Icon(Icons.workspace_premium_rounded,
                              color: AppColors.slate600, size: 18),
                        ),
                      );
                    } else if (rank == 3) {
                      rankWidget = Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFFEDD5),
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Icon(Icons.emoji_events_rounded,
                              color: Color(0xFFC2410C), size: 16),
                        ),
                      );
                    } else {
                      rankWidget = Text(
                        '#$rank',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.slate600,
                        ),
                      );
                    }

                    final avatarProvider =
                        _getUserAvatarProvider(r['avatar_url']);
                    final initial = (r['name'] as String? ?? 'U').isNotEmpty
                        ? (r['name'] as String)[0].toUpperCase()
                        : 'U';

                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 14),
                      color: isMe
                          ? const Color(0xFFF3E8FF).withAlpha(120)
                          : Colors.transparent,
                      child: Row(
                        children: [
                          SizedBox(
                            width: 36,
                            child: Center(child: rankWidget),
                          ),
                          const SizedBox(width: 12),
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: const Color(0xFF7C3AED),
                            backgroundImage: avatarProvider,
                            child: avatarProvider == null
                                ? Text(
                                    initial,
                                    style: GoogleFonts.inter(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        r['name'] ?? '',
                                        style: GoogleFonts.inter(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.navy,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (r['student_id'] != null &&
                                        (r['student_id'] as String).isNotEmpty) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEFF6FF),
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(
                                              color: const Color(0xFFBFDBFE)),
                                        ),
                                        child: Text(
                                          r['student_id'],
                                          style: GoogleFonts.jetBrainsMono(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFF2563EB),
                                          ),
                                        ),
                                      ),
                                    ],
                                    if (isMe) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF7C3AED),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          'YOU',
                                          style: GoogleFonts.inter(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Class ${r['class_level'] ?? _classLevel}',
                                  style: GoogleFonts.inter(
                                      fontSize: 12, color: AppColors.slate500),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '${r['score'] ?? r['points'] ?? r['total_points'] ?? 0} pts',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF2563EB),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  final int stepNumber;
  final String label;
  final bool active;
  final bool disabled;
  final VoidCallback onTap;

  const _StepButton({
    required this.stepNumber,
    required this.label,
    required this.active,
    this.disabled = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppColors.navy : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: active ? Colors.white.withAlpha(40) : AppColors.slate200,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '$stepNumber',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: active ? Colors.white : AppColors.slate600,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: active
                      ? Colors.white
                      : disabled
                          ? AppColors.slate400
                          : AppColors.slate700,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
