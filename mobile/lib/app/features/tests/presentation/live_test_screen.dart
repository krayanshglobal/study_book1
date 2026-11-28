import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/api/api_endpoints.dart';
import '../../../core/api/dio_client.dart';
import '../../../core/config/app_config.dart';
import '../../../core/models/question_model.dart';
import '../../../core/models/test_model.dart';
import '../../../core/theme/app_colors.dart';
import '../../common/widgets/app_logo.dart';
import '../../common/widgets/shared_widgets.dart';
import '../providers/test_provider.dart';

String _fmtDuration(Duration d) {
  if (d.isNegative) d = Duration.zero;
  final h = d.inHours.toString().padLeft(2, '0');
  final m = (d.inMinutes % 60).toString().padLeft(2, '0');
  final s = (d.inSeconds % 60).toString().padLeft(2, '0');
  return '$h:$m:$s';
}

String _questionImageUrl(String value) {
  final url = value.trim();
  if (url.startsWith('http://') || url.startsWith('https://')) return url;
  if (url.startsWith('/')) return '${AppConfig.baseUrl}$url';
  return '${AppConfig.baseUrl}/$url';
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
  final Map<String, Map<String, dynamic>> _answers =
      {}; // qid -> {selected_index, typed_answer}
  final ScrollController _scrollController = ScrollController();
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
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _startTest() async {
    try {
      final r = await dioClient.post(ApiEndpoints.startTest(widget.testId));
      final test = TestModel.fromJson(r.data['test']);
      final questions = (r.data['questions'] as List)
          .map((e) => QuestionModel.fromJson(e))
          .toList();
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
        'answers': _questions
            .map((q) => {
                  'question_id': q.id,
                  'selected_index': _answers[q.id]?['selected_index'],
                  'typed_answer': _answers[q.id]?['typed_answer'],
                })
            .toList(),
      };
      final r = await dioClient.post(ApiEndpoints.submitTest(widget.testId),
          data: payload);
      if (!mounted) return;
      showToast(
        context,
        auto
            ? 'Time up — submitted.'
            : 'Submitted. Score ${r.data['score']}/${r.data['total_marks']}',
      );
      ref.read(completedTestIdsProvider.notifier).update(
            (completed) => {...completed, widget.testId},
          );
      context.go('/tests/${widget.testId}/result');
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        showToast(context, formatApiError(e), isError: true);
      }
    }
  }

  bool _isAnswered(QuestionModel question) {
    final answer = _answers[question.id];
    if (answer == null) return false;

    final typedAnswer = answer['typed_answer'];
    return answer['selected_index'] != null ||
        (typedAnswer is String && typedAnswer.trim().isNotEmpty);
  }

  int get _answeredCount => _questions.where(_isAnswered).length;

  void _goToNextQuestion() {
    if (_idx >= _questions.length - 1 || !_isAnswered(_questions[_idx])) {
      return;
    }

    setState(() => _idx++);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
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
    final hasCurrentAnswer = _isAnswered(q);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text('Quit Test?',
                style: GoogleFonts.fraunces(
                    fontSize: 20, fontWeight: FontWeight.w600)),
            content: Text(
                'Are you sure you want to exit the test? Unsubmitted answers will be lost.',
                style:
                    GoogleFonts.inter(fontSize: 14, color: AppColors.slate700)),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Resume Test')),
              ElevatedButton(
                style:
                    ElevatedButton.styleFrom(backgroundColor: AppColors.error),
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
                  style: GoogleFonts.inter(
                      fontSize: 12, color: AppColors.slate500),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.navy,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.access_time,
                        size: 14, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(_fmtDuration(_remaining),
                        style: GoogleFonts.jetBrainsMono(
                            fontSize: 13,
                            color: Colors.white,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _submitting ? null : () => _submit(auto: false),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.violet,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(99)),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : Text('Submit',
                        style: GoogleFonts.inter(
                            fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          bottom: const PreferredSize(
              preferredSize: Size.fromHeight(1),
              child: Divider(height: 1, color: AppColors.slate200)),
        ),
        body: SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_test!.title.toUpperCase(),
                  style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                      color: AppColors.blue)),
              const SizedBox(height: 4),
              Text('Question ${_idx + 1} of ${_questions.length}',
                  style: GoogleFonts.fraunces(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: AppColors.navy)),
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
                        style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5,
                            color: AppColors.violet)),
                    const SizedBox(height: 8),
                    Text(q.questionText,
                        style: GoogleFonts.fraunces(
                            fontSize: 18, color: AppColors.navy, height: 1.3)),
                    if (q.imageUrls.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      ...q.imageUrls.map((imageUrl) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                _questionImageUrl(imageUrl),
                                width: double.infinity,
                                height: 200,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) =>
                                    const SizedBox.shrink(),
                              ),
                            ),
                          )),
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
                              color: chosen
                                  ? AppColors.blue.withAlpha(15)
                                  : AppColors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: chosen
                                    ? AppColors.blue
                                    : AppColors.slate200,
                                width: chosen ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Text('${opt.label}.',
                                    style: GoogleFonts.jetBrainsMono(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.violet)),
                                const SizedBox(width: 10),
                                Expanded(
                                    child: Text(opt.text,
                                        style: GoogleFonts.inter(
                                            fontSize: 14,
                                            color: AppColors.navy))),
                              ],
                            ),
                          ),
                        );
                      }),
                    ] else ...[
                      // Typed answer input
                      Text('YOUR ANSWER',
                          style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.5,
                              color: AppColors.slate500)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: TextEditingController(
                            text: currentAnswer?['typed_answer'] ?? '')
                          ..selection = TextSelection.collapsed(
                              offset:
                                  (currentAnswer?['typed_answer'] as String? ??
                                          '')
                                      .length),
                        onChanged: (val) {
                          setState(() {
                            _answers[q.id] = {
                              ...?_answers[q.id],
                              'typed_answer': val,
                            };
                          });
                        },
                        style: GoogleFonts.jetBrainsMono(fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Type your answer here...',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),
                    if (hasCurrentAnswer)
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton(
                          onPressed: _idx < _questions.length - 1
                              ? _goToNextQuestion
                              : (_submitting
                                  ? null
                                  : () => _submit(auto: false)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _idx < _questions.length - 1
                                ? AppColors.navy
                                : AppColors.violet,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(99)),
                          ),
                          child: Text(_idx < _questions.length - 1
                              ? 'Next Question'
                              : 'Submit Test'),
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
