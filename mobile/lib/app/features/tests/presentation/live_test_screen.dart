import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/api/api_endpoints.dart';
import '../../../core/api/dio_client.dart';
import '../../../core/models/question_model.dart';
import '../../../core/models/test_model.dart';
import '../../../core/theme/app_colors.dart';
import '../../common/widgets/app_logo.dart';
import '../../common/widgets/shared_widgets.dart';

String _fmtDuration(Duration d) {
  if (d.isNegative) d = Duration.zero;
  final h = d.inHours.toString().padLeft(2, '0');
  final m = (d.inMinutes % 60).toString().padLeft(2, '0');
  final s = (d.inSeconds % 60).toString().padLeft(2, '0');
  return '$h:$m:$s';
}

class LiveTestScreen extends ConsumerStatefulWidget {
  final String testId;
  const LiveTestScreen({super.key, required this.testId});

  @override
  ConsumerState<LiveTestScreen> createState() => _LiveTestScreenState();
}

class _LiveTestScreenState extends ConsumerState<LiveTestScreen> {
  TestModel? _test;
  List<QuestionModel> _questions = [];
  final Map<String, Map<String, dynamic>> _answers = {}; // qid -> {selected_index, typed_answer}
  int _idx = 0;
  DateTime? _deadline;
  Timer? _timer;
  Duration _remaining = Duration.zero;
  bool _loading = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _startTest();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _startTest() async {
    try {
      final r = await dioClient.post(ApiEndpoints.startTest(widget.testId));
      final test = TestModel.fromJson(r.data['test']);
      final questions = (r.data['questions'] as List).map((e) => QuestionModel.fromJson(e)).toList();
      final deadlineAt = DateTime.parse(r.data['deadline_at']);

      if (!mounted) return;
      setState(() {
        _test = test;
        _questions = questions;
        _deadline = deadlineAt;
        _loading = false;
      });

      _startTimer();
    } catch (e) {
      if (mounted) {
        showToast(context, formatApiError(e), isError: true);
        context.go('/tests');
      }
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_deadline == null) return;
      final now = DateTime.now().toUtc();
      final rem = _deadline!.difference(now);
      if (rem.isNegative || rem.inSeconds <= 0) {
        _timer?.cancel();
        _submit(auto: true);
      } else {
        setState(() => _remaining = rem);
      }
    });
  }

  Future<void> _submit({bool auto = false}) async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      final payload = {
        'answers': _questions.map((q) => {
          'question_id': q.id,
          'selected_index': _answers[q.id]?['selected_index'],
          'typed_answer': _answers[q.id]?['typed_answer'],
        }).toList(),
      };
      final r = await dioClient.post(ApiEndpoints.submitTest(widget.testId), data: payload);
      if (!mounted) return;
      showToast(
        context,
        auto ? 'Time up — submitted.' : 'Submitted. Score ${r.data['score']}/${r.data['total_marks']}',
      );
      context.go('/tests/${widget.testId}/result');
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        showToast(context, formatApiError(e), isError: true);
      }
    }
  }

  int get _answeredCount {
    return _questions.where((q) {
      final a = _answers[q.id];
      if (a == null) return false;
      return a['selected_index'] != null || (a['typed_answer'] != null && (a['typed_answer'] as String).trim().isNotEmpty);
    }).length;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _test == null) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(color: AppColors.blue)),
      );
    }

    final q = _questions[_idx];
    final currentAnswer = _answers[q.id];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text('Quit Test?', style: GoogleFonts.fraunces(fontSize: 20, fontWeight: FontWeight.w600)),
            content: Text('Are you sure you want to exit the test? Unsubmitted answers will be lost.',
                style: GoogleFonts.inter(fontSize: 14, color: AppColors.slate700)),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Resume Test')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Quit Exam'),
              ),
            ],
          ),
        );
        if (confirm == true && context.mounted) {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/tests');
          }
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            const AppLogo(size: 32),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '$_answeredCount/${_questions.length} answered',
                style: GoogleFonts.inter(fontSize: 12, color: AppColors.slate500),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.navy,
                borderRadius: BorderRadius.circular(99),
              ),
              child: Row(
                children: [
                  const Icon(Icons.access_time, size: 14, color: Colors.white),
                  const SizedBox(width: 4),
                  Text(_fmtDuration(_remaining),
                      style: GoogleFonts.jetBrainsMono(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _submitting ? null : () => _submit(auto: false),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.violet,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
              ),
              child: _submitting
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text('Submit', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        bottom: const PreferredSize(preferredSize: Size.fromHeight(1), child: Divider(height: 1, color: AppColors.slate200)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_test!.title.toUpperCase(),
                style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 2, color: AppColors.blue)),
            const SizedBox(height: 4),
            Text('Question ${_idx + 1} of ${_questions.length}',
                style: GoogleFonts.fraunces(fontSize: 24, fontWeight: FontWeight.w600, color: AppColors.navy)),
            const SizedBox(height: 16),

            // Question Card
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
                  Text(q.topic.toUpperCase(),
                      style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: AppColors.violet)),
                  const SizedBox(height: 8),
                  Text(q.questionText, style: GoogleFonts.fraunces(fontSize: 18, color: AppColors.navy, height: 1.3)),
                  if (q.imageUrl != null && q.imageUrl!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(q.imageUrl!, height: 200, fit: BoxFit.cover),
                    ),
                  ],
                  const SizedBox(height: 20),

                  // MCQ Options
                  if (q.qType == 'mcq' && q.options != null) ...[
                    ...q.options!.asMap().entries.map((e) {
                      final i = e.key;
                      final opt = e.value;
                      final chosen = currentAnswer?['selected_index'] == i;
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _answers[q.id] = {
                              ...?_answers[q.id],
                              'selected_index': i,
                            };
                          });
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: chosen ? AppColors.blue.withAlpha(15) : AppColors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: chosen ? AppColors.blue : AppColors.slate200,
                              width: chosen ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Text('${opt.label}.',
                                  style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.violet)),
                              const SizedBox(width: 10),
                              Expanded(child: Text(opt.text, style: GoogleFonts.inter(fontSize: 14, color: AppColors.navy))),
                            ],
                          ),
                        ),
                      );
                    }),
                  ] else ...[
                    // Typed answer input
                    Text('YOUR ANSWER', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: AppColors.slate500)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: TextEditingController(text: currentAnswer?['typed_answer'] ?? '')
                        ..selection = TextSelection.collapsed(offset: (currentAnswer?['typed_answer'] as String? ?? '').length),
                      onChanged: (val) {
                        _answers[q.id] = {
                          ...?_answers[q.id],
                          'typed_answer': val,
                        };
                      },
                      style: GoogleFonts.jetBrainsMono(fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Type your answer here...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      OutlinedButton(
                        onPressed: _idx == 0 ? null : () => setState(() => _idx--),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
                        ),
                        child: const Text('Previous'),
                      ),
                      if (_idx < _questions.length - 1)
                        ElevatedButton(
                          onPressed: () => setState(() => _idx++),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.navy,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
                          ),
                          child: const Text('Next'),
                        )
                      else
                        ElevatedButton(
                          onPressed: _submitting ? null : () => _submit(auto: false),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.violet,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
                          ),
                          child: const Text('Submit test'),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
            // Navigator grid
            Text('NAVIGATOR',
                style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: AppColors.slate500)),
            const SizedBox(height: 10),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 6,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: _questions.length,
              itemBuilder: (ctx, i) {
                final qId = _questions[i].id;
                final a = _answers[qId];
                final isAnswered = a != null && (a['selected_index'] != null || (a['typed_answer'] != null && (a['typed_answer'] as String).trim().isNotEmpty));
                final isCurrent = i == _idx;

                Color bg = AppColors.white;
                Color textColor = AppColors.slate600;
                Color borderColor = AppColors.slate200;

                if (isCurrent) {
                  bg = AppColors.navy;
                  textColor = Colors.white;
                  borderColor = AppColors.navy;
                } else if (isAnswered) {
                  bg = AppColors.blue.withAlpha(20);
                  textColor = AppColors.blue;
                  borderColor = AppColors.blue.withAlpha(80);
                }

                return GestureDetector(
                  onTap: () => setState(() => _idx = i),
                  child: Container(
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: borderColor),
                    ),
                    child: Center(
                      child: Text(
                        '${i + 1}',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    ),
  );
  }
}
