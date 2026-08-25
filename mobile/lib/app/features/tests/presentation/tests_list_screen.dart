import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/api/api_endpoints.dart';
import '../../../core/api/dio_client.dart';
import '../../../core/models/test_model.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../../common/widgets/app_drawer.dart';
import '../../common/widgets/shared_widgets.dart';

bool _isLiveNow(TestModel t) {
  try {
    final now = DateTime.now().toUtc();
    final start = DateTime.parse('${t.scheduledDate}T${t.startTime}:00Z');
    final end = DateTime.parse('${t.scheduledDate}T${t.endTime}:00Z');
    return now.isAfter(start) && now.isBefore(end);
  } catch (_) {
    return false;
  }
}

bool _isPast(TestModel t) {
  try {
    final now = DateTime.now().toUtc();
    final end = DateTime.parse('${t.scheduledDate}T${t.endTime}:00Z');
    return now.isAfter(end);
  } catch (_) {
    return false;
  }
}

class TestsListScreen extends ConsumerStatefulWidget {
  const TestsListScreen({super.key});

  @override
  ConsumerState<TestsListScreen> createState() => _TestsListScreenState();
}

class _TestsListScreenState extends ConsumerState<TestsListScreen> {
  List<TestModel> _items = [];
  bool _loading = true;
  String? _classLevel; // set from user profile for students

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).user;
    // Auto-scope to student's assigned class
    if (user != null && !user.isAdmin && user.classLevel != null) {
      _classLevel = user.classLevel;
    }
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final params = <String, dynamic>{};
      if (_classLevel != null) params['class_level'] = _classLevel;
      final r = await dioClient.get(ApiEndpoints.tests, queryParameters: params.isNotEmpty ? params : null);
      final list = (r.data['items'] as List).map((e) => TestModel.fromJson(e)).toList();
      if (mounted) setState(() { _items = list; _loading = false; });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        showToast(context, formatApiError(e), isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MainScaffold(
      title: 'Practice & Final Tests',
      body: _loading
          ? const LoadingIndicator()
          : RefreshIndicator(
              onRefresh: _load,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ASSESSMENTS',
                        style: GoogleFonts.inter(
                            fontSize: 10, fontWeight: FontWeight.w700,
                            letterSpacing: 2, color: AppColors.blue)),
                    const SizedBox(height: 4),
                    Text('Practice & final tests',
                        style: GoogleFonts.fraunces(
                            fontSize: 28, fontWeight: FontWeight.w600, color: AppColors.navy)),
                    const SizedBox(height: 4),
                    Text(
                      'Take scheduled tests during their live window. Every submission tracks toward your rank.',
                      style: GoogleFonts.inter(fontSize: 13, color: AppColors.slate500),
                    ),
                    const SizedBox(height: 20),

                    if (_items.isEmpty)
                      const EmptyState(
                        message: 'No tests published yet. Check back soon!',
                        icon: Icons.assignment_outlined,
                      )
                    else
                      ..._items.map((t) => _TestCard(test: t)),
                  ],
                ),
              ),
            ),
    );
  }
}

class _TestCard extends StatelessWidget {
  final TestModel test;
  const _TestCard({required this.test});

  @override
  Widget build(BuildContext context) {
    final live = _isLiveNow(test);
    final past = _isPast(test);
    final submitted = test.myScore != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: test.testType == 'final' ? AppColors.violet : AppColors.slate100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  test.testType.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 10, fontWeight: FontWeight.w700,
                    color: test.testType == 'final' ? Colors.white : AppColors.navy,
                  ),
                ),
              ),
              if (test.premiumOnly) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.warning,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('PREMIUM',
                      style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              ],
              if (live && !submitted) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.success,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('LIVE NOW',
                      style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              ],
              const Spacer(),
              if (test.locked)
                const Icon(Icons.lock_outlined, size: 18, color: AppColors.slate400),
            ],
          ),
          const SizedBox(height: 12),
          Text(test.title,
              style: GoogleFonts.fraunces(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.navy)),
          if (test.description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(test.description,
                style: GoogleFonts.inter(fontSize: 13, color: AppColors.slate500)),
          ],
          const SizedBox(height: 16),

          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.calendar_today_outlined, size: 14, color: AppColors.blue),
                  const SizedBox(width: 6),
                  Text(test.scheduledDate, style: GoogleFonts.inter(fontSize: 12, color: AppColors.slate600)),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.access_time_outlined, size: 14, color: AppColors.blue),
                  const SizedBox(width: 6),
                  Text('${test.startTime}–${test.endTime} UTC', style: GoogleFonts.inter(fontSize: 12, color: AppColors.slate600)),
                ],
              ),
              Text('Class ${test.classLevel}', style: GoogleFonts.inter(fontSize: 12, color: AppColors.slate600)),
              Text('${test.questionIds.length} qns', style: GoogleFonts.inter(fontSize: 12, color: AppColors.slate600)),
            ],
          ),

          if (test.unlockScoreRequired != null && test.locked) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.warning.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.warning.withAlpha(60)),
              ),
              child: Text(
                'Requires ≥ ${test.unlockScoreRequired}% on prerequisite test.',
                style: GoogleFonts.inter(fontSize: 12, color: AppColors.warning),
              ),
            ),
          ],

          const SizedBox(height: 16),
          const Divider(height: 1, color: AppColors.slate200),
          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (submitted) ...[
                Row(
                  children: [
                    Text('Your score: ', style: GoogleFonts.inter(fontSize: 13, color: AppColors.slate500)),
                    Text('${test.myScore}', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.navy)),
                  ],
                ),
                OutlinedButton(
                  onPressed: () => context.push('/tests/${test.id}/result'),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
                    side: const BorderSide(color: AppColors.slate200),
                  ),
                  child: Text('View result', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.navy)),
                ),
              ] else if (test.locked) ...[
                Text('Locked', style: GoogleFonts.inter(fontSize: 13, fontStyle: FontStyle.italic, color: AppColors.slate400)),
              ] else if (live) ...[
                ElevatedButton(
                  onPressed: () => context.push('/tests/${test.id}/live'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.violet,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
                  ),
                  child: Row(
                    children: [
                      Text('Start now', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_forward, size: 14),
                    ],
                  ),
                ),
              ] else if (past) ...[
                Text('Window ended', style: GoogleFonts.inter(fontSize: 13, fontStyle: FontStyle.italic, color: AppColors.slate400)),
              ] else ...[
                Text('Opens ${test.scheduledDate} · ${test.startTime} UTC',
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.blue)),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
