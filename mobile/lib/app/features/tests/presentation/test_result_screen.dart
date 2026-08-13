import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/api/api_endpoints.dart';
import '../../../core/api/dio_client.dart';
import '../../../core/models/question_model.dart';
import '../../../core/models/test_model.dart';
import '../../../core/theme/app_colors.dart';
import '../../common/widgets/app_drawer.dart';
import '../../common/widgets/shared_widgets.dart';

class TestResultScreen extends ConsumerStatefulWidget {
  final String testId;
  const TestResultScreen({super.key, required this.testId});

  @override
  ConsumerState<TestResultScreen> createState() => _TestResultScreenState();
}

class _TestResultScreenState extends ConsumerState<TestResultScreen> {
  Map? _attempt;
  TestModel? _test;
  List<QuestionModel> _questions = [];
  List _leaderboard = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await Future.wait([
        dioClient.get(ApiEndpoints.testResult(widget.testId)),
        dioClient.get(ApiEndpoints.testLeaderboard(widget.testId)),
      ]);

      final data = res[0].data as Map;
      final attempt = data['attempt'] as Map;
      final test = data['test'] != null ? TestModel.fromJson(data['test']) : null;
      final questions = (data['questions'] as List).map((e) => QuestionModel.fromJson(e)).toList();
      final leaderboard = (res[1].data['items'] as List?) ?? [];

      if (!mounted) return;
      setState(() {
        _attempt = attempt;
        _test = test;
        _questions = questions;
        _leaderboard = leaderboard;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        showToast(context, formatApiError(e), isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const MainScaffold(
        title: 'Test Result',
        showBack: true,
        parentRoute: '/tests',
        body: LoadingIndicator(),
      );
    }

    if (_attempt == null) {
      return const MainScaffold(
        title: 'Test Result',
        showBack: true,
        parentRoute: '/tests',
        body: EmptyState(message: 'No result data found.'),
      );
    }

    final a = _attempt!;
    final double percent = (a['percent'] as num?)?.toDouble() ?? 0.0;
    final passed = percent >= 50.0;

    return MainScaffold(
      title: 'Result Overview',
      showBack: true,
      parentRoute: '/tests',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('RESULT',
                style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 2, color: AppColors.violet)),
            const SizedBox(height: 4),
            Text(_test?.title ?? 'Test Result',
                style: GoogleFonts.fraunces(fontSize: 26, fontWeight: FontWeight.w600, color: AppColors.navy)),
            const SizedBox(height: 16),

            // Score Summary Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.slate200),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          Text('SCORE', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.slate500)),
                          const SizedBox(height: 4),
                          Text('${a['score']}', style: GoogleFonts.fraunces(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.navy)),
                          Text('of ${a['total_marks']}', style: GoogleFonts.inter(fontSize: 11, color: AppColors.slate500)),
                        ],
                      ),
                      Column(
                        children: [
                          Text('PERCENT', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.slate500)),
                          const SizedBox(height: 4),
                          Text('$percent%',
                              style: GoogleFonts.fraunces(
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                color: passed ? AppColors.success : AppColors.error,
                              )),
                        ],
                      ),
                      Column(
                        children: [
                          Text('ACCURACY', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.slate500)),
                          const SizedBox(height: 4),
                          Text('${a['correct_count']}/${a['incorrect_count']}',
                              style: GoogleFonts.jetBrainsMono(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.navy)),
                          Text('Correct/Wrong', style: GoogleFonts.inter(fontSize: 11, color: AppColors.slate500)),
                        ],
                      ),
                    ],
                  ),
                  if (passed && _test?.testType == 'mock') ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.success.withAlpha(15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.success.withAlpha(40)),
                      ),
                      child: Text(
                        'You scored above 50%. Final tests requiring this prerequisite are now unlocked.',
                        style: GoogleFonts.inter(fontSize: 12, color: AppColors.success, fontWeight: FontWeight.w500),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 24),
            Text('QUESTION REVIEW',
                style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 2, color: AppColors.navy)),
            const SizedBox(height: 12),

            // Questions Breakdown
            ..._questions.asMap().entries.map((entry) {
              final idx = entry.key;
              final q = entry.value;
              final answersList = (a['answers'] as List? ?? []);
              final userAnsMap = answersList.firstWhere(
                (x) => x['question_id'] == q.id,
                orElse: () => <String, dynamic>{},
              );

              final bool answered = userAnsMap['answered'] == true;
              final bool isCorrect = userAnsMap['is_correct'] == true;

              IconData icon = Icons.remove_circle_outline;
              Color iconColor = AppColors.slate400;
              if (answered) {
                icon = isCorrect ? Icons.check_circle_outline : Icons.cancel_outlined;
                iconColor = isCorrect ? AppColors.success : AppColors.error;
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.slate200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, color: iconColor, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(q.topic.toUpperCase(),
                              style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.violet)),
                          const SizedBox(height: 4),
                          Text('${idx + 1}. ${q.questionText}',
                              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.navy)),
                          const SizedBox(height: 8),

                          if (q.qType == 'mcq') ...[
                            Text(
                              'Correct: ${q.options != null && q.correctIndex != null && q.correctIndex! < q.options!.length ? q.options![q.correctIndex!].text : ''}',
                              style: GoogleFonts.inter(fontSize: 13, color: AppColors.slate700),
                            ),
                            if (userAnsMap['selected_index'] != null && !isCorrect) ...[
                              const SizedBox(height: 2),
                              Text(
                                'Your answer: ${q.options != null && userAnsMap['selected_index'] < q.options!.length ? q.options![userAnsMap['selected_index']].text : ''}',
                                style: GoogleFonts.inter(fontSize: 13, color: AppColors.error),
                              ),
                            ],
                          ] else ...[
                            Text('Correct: ${q.correctAnswerText ?? ''}',
                                style: GoogleFonts.inter(fontSize: 13, color: AppColors.slate700)),
                            if (userAnsMap['typed_answer'] != null && !isCorrect) ...[
                              const SizedBox(height: 2),
                              Text('Your answer: ${userAnsMap['typed_answer']}',
                                  style: GoogleFonts.inter(fontSize: 13, color: AppColors.error)),
                            ],
                          ],

                          if (q.explanation != null && q.explanation!.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text('Explanation: ${q.explanation}',
                                style: GoogleFonts.inter(fontSize: 12, color: AppColors.slate500)),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),

            const SizedBox(height: 24),
            // Leaderboard snippet
            if (_leaderboard.isNotEmpty) ...[
              Text('TEST LEADERBOARD',
                  style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 2, color: AppColors.navy)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.slate200),
                ),
                child: Column(
                  children: _leaderboard.take(5).map((row) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Text('#${row['rank']}', style: GoogleFonts.jetBrainsMono(fontSize: 12, color: AppColors.slate500)),
                          const SizedBox(width: 12),
                          Expanded(child: Text('${row['name']}', style: GoogleFonts.inter(fontSize: 13, color: AppColors.navy))),
                          Text('${row['percent']}%', style: GoogleFonts.jetBrainsMono(fontSize: 13, color: AppColors.blue, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],

            const SizedBox(height: 24),
            PrimaryButton(
              text: 'Back to tests',
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/tests');
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
