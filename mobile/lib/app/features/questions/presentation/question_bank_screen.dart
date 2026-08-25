import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_endpoints.dart';
import '../../../core/api/dio_client.dart';
import '../../../core/models/question_model.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../../common/widgets/app_drawer.dart';
import '../../common/widgets/shared_widgets.dart';

class QuestionBankScreen extends ConsumerStatefulWidget {
  const QuestionBankScreen({super.key});

  @override
  ConsumerState<QuestionBankScreen> createState() => _QuestionBankState();
}

class _QuestionBankState extends ConsumerState<QuestionBankScreen> {
  List<QuestionModel> _questions = [];
  List<Map> _topics = [];
  bool _loading = true;
  String? _filterClass;
  String? _filterTopic;
  DateTime? _filterDate;
  int _skip = 0;
  int _total = 0;
  final _classes = ['8', '9', '10'];
  bool _isStudent = false; // set in initState from auth state

  // ── Statistics tracking ────────────────────────────────────────────────────
  // Tracks which question IDs the student has answered in this session.
  // Updated immediately when a student submits any answer (correct or not).
  final Set<String> _answeredIds = {};

  void _markAnswered(String id) {
    if (!_answeredIds.contains(id)) {
      setState(() => _answeredIds.add(id));
    }
  }

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).user;
    // Students have their class locked automatically
    if (user != null && !user.isAdmin && user.classLevel != null) {
      _isStudent = true;
      _filterClass = user.classLevel;
    }
    _loadTopics();
    _load();
  }

  Future<void> _loadTopics() async {
    try {
      final r = await dioClient.get(ApiEndpoints.topics,
          queryParameters: _filterClass != null ? {'class_level': _filterClass} : null);
      if (mounted) setState(() => _topics = List<Map>.from(r.data['topics'] ?? []));
    } catch (_) {}
  }

  Future<void> _load({bool reset = false}) async {
    if (reset) {
      setState(() {
        _skip = 0;
        _questions = [];
        _answeredIds.clear(); // Reset answered counts when list reloads
      });
    }
    setState(() => _loading = true);
    try {
      final params = <String, dynamic>{'limit': 20, 'skip': _skip};
      if (_filterClass != null) params['class_level'] = _filterClass;
      if (_filterTopic != null) params['topic'] = _filterTopic;
      if (_filterDate != null) params['date'] = DateFormat('yyyy-MM-dd').format(_filterDate!);
      final r = await dioClient.get(ApiEndpoints.questions, queryParameters: params);
      final items = (r.data['items'] as List).map((e) => QuestionModel.fromJson(e)).toList();
      if (!mounted) return;
      setState(() {
        if (reset) {
          _questions = items;
        } else {
          _questions.addAll(items);
        }
        _total = r.data['total'] ?? 0;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _filterDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() => _filterDate = picked);
      _load(reset: true);
    }
  }

  void _resetFilters() {
    setState(() {
      // Students keep their class locked; only admins can reset it
      if (!_isStudent) _filterClass = null;
      _filterTopic = null;
      _filterDate = null;
      _answeredIds.clear();
    });
    _loadTopics();
    _load(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    final hasActiveFilters = _filterClass != null || _filterTopic != null || _filterDate != null;

    // Compute stats from currently loaded questions
    final totalLoaded = _questions.length;
    final answered = _questions.where((q) => _answeredIds.contains(q.id)).length;
    final unanswered = totalLoaded - answered;

    return MainScaffold(
      title: 'Question Bank',
      body: Column(
        children: [
          // Filters
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            color: AppColors.white,
            child: Column(
              children: [
                Row(
                  children: [
                // ── Class selector: read-only pill for students, dropdown for admins
                if (_isStudent)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                          'Class $_filterClass',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.blue,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _filterClass,
                      isExpanded: true,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: AppColors.slate200)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: AppColors.slate200)),
                        isDense: true,
                      ),
                      hint: Text('Class', style: GoogleFonts.inter(fontSize: 13, color: AppColors.slate400)),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('All classes')),
                        ..._classes.map((c) => DropdownMenuItem(value: c, child: Text('Class $c'))),
                      ],
                      onChanged: (v) {
                        setState(() { _filterClass = v; _filterTopic = null; });
                        _loadTopics();
                        _load(reset: true);
                      },
                    ),
                  ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _filterTopic,
                        isExpanded: true,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: AppColors.slate200)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: AppColors.slate200)),
                          isDense: true,
                        ),
                        hint: Text('Topic', style: GoogleFonts.inter(fontSize: 13, color: AppColors.slate400)),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('All topics')),
                          ..._topics.map((t) => DropdownMenuItem(
                              value: t['topic'] as String,
                              child: Text(t['topic'] as String))),
                        ],
                        onChanged: (v) {
                          setState(() => _filterTopic = v);
                          _load(reset: true);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: _pickDate,
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _filterDate != null ? AppColors.blue : AppColors.slate200,
                              width: _filterDate != null ? 1.5 : 1.0,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.calendar_today, size: 16, color: _filterDate != null ? AppColors.blue : AppColors.slate400),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _filterDate != null ? DateFormat('dd MMM yyyy').format(_filterDate!) : 'Date 📅',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: _filterDate != null ? AppColors.navy : AppColors.slate400,
                                    fontWeight: _filterDate != null ? FontWeight.w600 : FontWeight.normal,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (_filterDate != null)
                                GestureDetector(
                                  onTap: () {
                                    setState(() => _filterDate = null);
                                    _load(reset: true);
                                  },
                                  child: const Icon(Icons.close, size: 16, color: AppColors.slate500),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (hasActiveFilters) ...[
                      const SizedBox(width: 10),
                      TextButton.icon(
                        onPressed: _resetFilters,
                        icon: const Icon(Icons.restart_alt, size: 16, color: AppColors.slate600),
                        label: Text('Clear', style: GoogleFonts.inter(fontSize: 13, color: AppColors.slate600)),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // ── Statistics Row ─────────────────────────────────────────────────
          if (!_loading || _questions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: Row(
                children: [
                  Expanded(
                    child: _StatPill(
                      emoji: '📚',
                      label: 'Total',
                      count: totalLoaded,
                      color: AppColors.blue,
                      bgColor: AppColors.blue.withAlpha(14),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _StatPill(
                      emoji: '✅',
                      label: 'Answered',
                      count: answered,
                      color: AppColors.success,
                      bgColor: AppColors.success.withAlpha(14),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _StatPill(
                      emoji: '🟠',
                      label: 'Left',
                      count: unanswered,
                      color: AppColors.warning,
                      bgColor: AppColors.warning.withAlpha(14),
                    ),
                  ),
                ],
              ),
            ),

          // Questions list
          Expanded(
            child: _loading && _questions.isEmpty
                ? const LoadingIndicator()
                : _questions.isEmpty
                    ? const EmptyState(message: 'No questions found.', icon: Icons.quiz_outlined)
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        itemCount: _questions.length + 1,
                        itemBuilder: (_, i) {
                          if (i == _questions.length) {
                            return _questions.length < _total
                                ? Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: TextButton(
                                        onPressed: () {
                                          setState(() => _skip += 20);
                                          _load();
                                        },
                                        child: Text('Load more',
                                            style: GoogleFonts.inter(color: AppColors.blue)),
                                      ),
                                    ),
                                  )
                                : const SizedBox.shrink();
                          }
                          return _QuestionCard(
                            question: _questions[i],
                            onAnswered: () => _markAnswered(_questions[i].id),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Statistics Pill Widget
// ─────────────────────────────────────────────────────────────────────────────

class _StatPill extends StatelessWidget {
  final String emoji;
  final String label;
  final int count;
  final Color color;
  final Color bgColor;

  const _StatPill({
    required this.emoji,
    required this.label,
    required this.count,
    required this.color,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(40)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: color,
                    letterSpacing: 0.3,
                  ),
                ),
                Text(
                  '$count',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: color,
                    height: 1.1,
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

class _QuestionCard extends StatefulWidget {
  final QuestionModel question;
  final VoidCallback onAnswered;
  const _QuestionCard({required this.question, required this.onAnswered});

  @override
  State<_QuestionCard> createState() => _QuestionCardState();
}

class _QuestionCardState extends State<_QuestionCard> {
  int? _selectedIndex;
  String _typedAnswer = '';
  Map? _result;
  bool _submitting = false;

  Future<void> _check() async {
    setState(() => _submitting = true);
    try {
      final body = widget.question.qType == 'mcq'
          ? {'selected_index': _selectedIndex}
          : {'typed_answer': _typedAnswer};
      final r = await dioClient.post(ApiEndpoints.checkQuestion(widget.question.id), data: body);
      if (mounted) {
        setState(() { _result = r.data as Map; _submitting = false; });
        // Notify parent so statistics update immediately
        widget.onAnswered();
      }
    } catch (_) {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Color _difficultyColor(String d) => d == 'easy' ? AppColors.success : d == 'hard' ? AppColors.error : AppColors.warning;

  @override
  Widget build(BuildContext context) {
    final q = widget.question;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.slate200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header badges
            Row(
              children: [
                _Badge('Class ${q.classLevel}', AppColors.navy),
                const SizedBox(width: 6),
                _Badge(q.topic, AppColors.blue),
                const Spacer(),
                _Badge(q.difficulty, _difficultyColor(q.difficulty)),
              ],
            ),
            const SizedBox(height: 12),
            Text(q.questionText, style: GoogleFonts.inter(fontSize: 14, color: AppColors.navy)),
            const SizedBox(height: 12),

            // MCQ options
            if (q.qType == 'mcq' && q.options != null) ...[
              ...q.options!.asMap().entries.map((e) {
                final idx = e.key;
                final opt = e.value;
                final isSelected = _selectedIndex == idx;
                Color? bg;
                if (_result != null) {
                  final correctIdx = _result!['correct_index'];
                  if (idx == correctIdx) bg = AppColors.success.withAlpha(30);
                  if (isSelected && idx != correctIdx) bg = AppColors.error.withAlpha(30);
                }
                return GestureDetector(
                  onTap: _result == null ? () => setState(() => _selectedIndex = idx) : null,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: bg ?? (isSelected ? AppColors.blue.withAlpha(15) : AppColors.slate50),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? AppColors.blue : AppColors.slate200,
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 24, height: 24,
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.blue : AppColors.slate200,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(opt.label,
                                style: GoogleFonts.inter(
                                    fontSize: 11, fontWeight: FontWeight.w700,
                                    color: isSelected ? Colors.white : AppColors.slate700)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Text(opt.text,
                            style: GoogleFonts.inter(fontSize: 13, color: AppColors.navy))),
                      ],
                    ),
                  ),
                );
              }),
            ],

            // Typed input
            if (q.qType == 'typed') ...[
              TextField(
                enabled: _result == null,
                onChanged: (v) => setState(() => _typedAnswer = v),
                decoration: InputDecoration(
                  hintText: 'Type your answer here',
                  hintStyle: GoogleFonts.inter(color: AppColors.slate400, fontSize: 13),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.slate200)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.slate200)),
                ),
              ),
            ],

            // Result
            if (_result != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (_result!['correct'] == true ? AppColors.success : AppColors.error).withAlpha(15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(_result!['correct'] == true ? Icons.check_circle : Icons.cancel,
                          size: 16,
                          color: _result!['correct'] == true ? AppColors.success : AppColors.error),
                      const SizedBox(width: 6),
                      Text(_result!['correct'] == true ? 'Correct!' : 'Incorrect',
                          style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700, fontSize: 13,
                              color: _result!['correct'] == true ? AppColors.success : AppColors.error)),
                    ]),
                    if (_result!['explanation'] != null) ...[
                      const SizedBox(height: 6),
                      Text('${_result!['explanation']}',
                          style: GoogleFonts.inter(fontSize: 12, color: AppColors.slate700)),
                    ],
                  ],
                ),
              ),
            ],

            const SizedBox(height: 10),
            if (_result == null)
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: (q.qType == 'mcq' ? _selectedIndex == null : _typedAnswer.trim().isEmpty) || _submitting
                      ? null
                      : _check,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.blue,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
                  ),
                  child: _submitting
                      ? const SizedBox(width: 16, height: 16,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text('Check answer',
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;
  const _Badge(this.text, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text,
          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
    );
  }
}
