import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_endpoints.dart';
import '../../../core/api/dio_client.dart';
import '../../../core/config/app_config.dart';
import '../../../core/models/question_model.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../../common/widgets/app_drawer.dart';
import '../../common/widgets/shared_widgets.dart';

String _plainTextFromHtml(Object? value) {
  var text = value?.toString() ?? '';
  if (!text.contains('<') && !text.contains('&')) return text.trim();

  text = text
      .replaceAll(RegExp(r'<\s*br\s*/?\s*>', caseSensitive: false), '\n')
      .replaceAll(
          RegExp(r'</\s*(p|div|li|h[1-6]|tr)\s*>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'<\s*li(?:\s[^>]*)?>', caseSensitive: false), '• ')
      .replaceAll(RegExp(r'<\/?[a-zA-Z][^>]*>'), '')
      .replaceAll(RegExp(r'<!--[\s\S]*?-->'), '');

  const namedEntities = {
    '&nbsp;': ' ',
    '&amp;': '&',
    '&lt;': '<',
    '&gt;': '>',
    '&quot;': '"',
    '&#39;': "'",
    '&apos;': "'",
  };
  namedEntities.forEach((entity, replacement) {
    text = text.replaceAll(entity, replacement);
  });

  text = text.replaceAllMapped(RegExp(r'&#(x[0-9a-fA-F]+|\d+);'), (match) {
    final raw = match.group(1)!;
    final code = raw.toLowerCase().startsWith('x')
        ? int.tryParse(raw.substring(1), radix: 16)
        : int.tryParse(raw);
    return code == null ? match.group(0)! : String.fromCharCode(code);
  });

  return text
      .split('\n')
      .map((line) => line.replaceAll(RegExp(r'[ \t]+'), ' ').trim())
      .where((line) => line.isNotEmpty)
      .join('\n')
      .trim();
}

enum _QuestionListFilter { total, answered, left }

class _QuestionAnswerState {
  int? selectedIndex;
  String typedAnswer;
  Map<String, dynamic>? result;
  bool submitting = false;

  _QuestionAnswerState({
    this.selectedIndex,
    this.typedAnswer = '',
    this.result,
  });

  factory _QuestionAnswerState.fromQuestion(QuestionModel question) {
    final attempt = question.attempt;
    final rawSelectedIndex = attempt?['selected_index'];
    return _QuestionAnswerState(
      selectedIndex: rawSelectedIndex is num
          ? rawSelectedIndex.toInt()
          : int.tryParse(rawSelectedIndex?.toString() ?? ''),
      typedAnswer: attempt?['typed_answer']?.toString() ?? '',
      result: attempt == null ? null : Map<String, dynamic>.from(attempt),
    );
  }

  void restoreAttempt(Map<String, dynamic> attempt) {
    final rawSelectedIndex = attempt['selected_index'];
    selectedIndex = rawSelectedIndex is num
        ? rawSelectedIndex.toInt()
        : int.tryParse(rawSelectedIndex?.toString() ?? '');
    typedAnswer = attempt['typed_answer']?.toString() ?? '';
    result = Map<String, dynamic>.from(attempt);
  }
}

class QuestionBankScreen extends ConsumerStatefulWidget {
  final bool dailyOnly;

  const QuestionBankScreen({super.key, this.dailyOnly = false});

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
  final Map<String, _QuestionAnswerState> _answerStates = {};
  _QuestionListFilter _questionListFilter = _QuestionListFilter.total;

  // ── Statistics tracking ────────────────────────────────────────────────────
  // Tracks which question IDs the student has answered in this session.
  // Updated immediately when a student submits any answer (correct or not).
  final Set<String> _answeredIds = {};

  void _markAnswered(String id) {
    if (!mounted) return;
    setState(() => _answeredIds.add(id));
    if (widget.dailyOnly) _refreshDailyStatus();
  }

  _QuestionAnswerState _answerStateFor(QuestionModel question) {
    return _answerStates.putIfAbsent(
      question.id,
      () => _QuestionAnswerState.fromQuestion(question),
    );
  }

  void _hydrateAnswerState(QuestionModel question) {
    final state = _answerStates[question.id];
    final attempt = question.attempt;
    if (state == null) {
      _answerStates[question.id] = _QuestionAnswerState.fromQuestion(question);
    } else if (attempt != null && state.result == null) {
      state.restoreAttempt(attempt);
    }
  }

  Future<void> _refreshDailyStatus() async {
    try {
      final response = await dioClient.get(ApiEndpoints.dailyPractice);
      final attemptedIds = List<String>.from(
          (response.data['attempted_ids'] ?? const []).map((id) => '$id'));
      if (!mounted) return;
      setState(() {
        _answeredIds.addAll(attemptedIds);
      });
    } catch (_) {}
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
    if (!widget.dailyOnly) _loadTopics();
    _load();
  }

  Future<void> _loadTopics() async {
    try {
      final params = <String, dynamic>{
        'category': widget.dailyOnly ? 'daily_24h' : 'question_bank',
      };
      if (_filterClass != null) params['class_level'] = _filterClass;
      final r =
          await dioClient.get(ApiEndpoints.topics, queryParameters: params);
      if (mounted) {
        setState(() => _topics = List<Map>.from(r.data['topics'] ?? []));
      }
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
      params['category'] = widget.dailyOnly ? 'daily_24h' : 'question_bank';
      if (_filterClass != null) params['class_level'] = _filterClass;
      if (_filterTopic != null) params['topic'] = _filterTopic;
      if (_filterDate != null) {
        params['date'] = DateFormat('yyyy-MM-dd').format(_filterDate!);
      }
      final r =
          await dioClient.get(ApiEndpoints.questions, queryParameters: params);
      final items = (r.data['items'] as List)
          .map((e) => QuestionModel.fromJson(e))
          .toList();
      if (!mounted) return;
      setState(() {
        for (final question in items) {
          _hydrateAnswerState(question);
        }
        if (reset) {
          _questions = items;
        } else {
          _questions.addAll(items);
        }
        _answeredIds.addAll(items
            .where((question) => _answerStates[question.id]?.result != null)
            .map((question) => question.id));
        _total = r.data['total'] ?? 0;
        _loading = false;
      });
      if (widget.dailyOnly) await _refreshDailyStatus();
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
      _questionListFilter = _QuestionListFilter.total;
    });
    _loadTopics();
    _load(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    final hasActiveFilters = !widget.dailyOnly &&
        (_filterClass != null || _filterTopic != null || _filterDate != null);

    // Compute stats from currently loaded questions
    final totalLoaded = _questions.length;
    final answered =
        _questions.where((q) => _answeredIds.contains(q.id)).length;
    final unanswered = totalLoaded - answered;
    final visibleQuestions = !widget.dailyOnly
        ? _questions
        : _questions.where((question) {
            switch (_questionListFilter) {
              case _QuestionListFilter.total:
                return true;
              case _QuestionListFilter.answered:
                return _answeredIds.contains(question.id);
              case _QuestionListFilter.left:
                return !_answeredIds.contains(question.id);
            }
          }).toList();

    return MainScaffold(
      title: widget.dailyOnly ? 'Daily Practice' : 'Question Bank',
      showBack: widget.dailyOnly,
      parentRoute: '/dashboard',
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
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.blue.withAlpha(10),
                          borderRadius: BorderRadius.circular(10),
                          border:
                              Border.all(color: AppColors.blue.withAlpha(40)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.school_rounded,
                                size: 14, color: AppColors.blue),
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
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(
                                    color: AppColors.slate200)),
                            enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(
                                    color: AppColors.slate200)),
                            isDense: true,
                          ),
                          hint: Text('Class',
                              style: GoogleFonts.inter(
                                  fontSize: 13, color: AppColors.slate400)),
                          items: [
                            const DropdownMenuItem(
                                value: null, child: Text('All classes')),
                            ..._classes.map((c) => DropdownMenuItem(
                                value: c, child: Text('Class $c'))),
                          ],
                          onChanged: (v) {
                            setState(() {
                              _filterClass = v;
                              _filterTopic = null;
                            });
                            _loadTopics();
                            _load(reset: true);
                          },
                        ),
                      ),
                    if (!widget.dailyOnly) const SizedBox(width: 10),
                    if (!widget.dailyOnly)
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _filterTopic,
                          isExpanded: true,
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(
                                    color: AppColors.slate200)),
                            enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(
                                    color: AppColors.slate200)),
                            isDense: true,
                          ),
                          hint: Text('Chapter',
                              style: GoogleFonts.inter(
                                  fontSize: 13, color: AppColors.slate400)),
                          items: [
                            const DropdownMenuItem(
                                value: null, child: Text('All chapters')),
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
                if (!widget.dailyOnly) const SizedBox(height: 10),
                if (!widget.dailyOnly)
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: _pickDate,
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppColors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _filterDate != null
                                    ? AppColors.blue
                                    : AppColors.slate200,
                                width: _filterDate != null ? 1.5 : 1.0,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.calendar_today,
                                    size: 16,
                                    color: _filterDate != null
                                        ? AppColors.blue
                                        : AppColors.slate400),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _filterDate != null
                                        ? DateFormat('dd MMM yyyy')
                                            .format(_filterDate!)
                                        : 'Date 📅',
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      color: _filterDate != null
                                          ? AppColors.navy
                                          : AppColors.slate400,
                                      fontWeight: _filterDate != null
                                          ? FontWeight.w600
                                          : FontWeight.normal,
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
                                    child: const Icon(Icons.close,
                                        size: 16, color: AppColors.slate500),
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
                          icon: const Icon(Icons.restart_alt,
                              size: 16, color: AppColors.slate600),
                          label: Text('Clear',
                              style: GoogleFonts.inter(
                                  fontSize: 13, color: AppColors.slate600)),
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
                      selected: widget.dailyOnly &&
                          _questionListFilter == _QuestionListFilter.total,
                      onTap: widget.dailyOnly
                          ? () => setState(() =>
                              _questionListFilter = _QuestionListFilter.total)
                          : null,
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
                      selected: widget.dailyOnly &&
                          _questionListFilter == _QuestionListFilter.answered,
                      onTap: widget.dailyOnly
                          ? () => setState(() => _questionListFilter =
                              _QuestionListFilter.answered)
                          : null,
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
                      selected: widget.dailyOnly &&
                          _questionListFilter == _QuestionListFilter.left,
                      onTap: widget.dailyOnly
                          ? () => setState(() =>
                              _questionListFilter = _QuestionListFilter.left)
                          : null,
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
                    ? EmptyState(
                        message: widget.dailyOnly
                            ? 'No active Daily Practice questions. New questions will appear when your admin publishes them.'
                            : 'No questions found.',
                        icon: Icons.quiz_outlined,
                      )
                    : visibleQuestions.isEmpty
                        ? EmptyState(
                            message: _questionListFilter ==
                                    _QuestionListFilter.answered
                                ? 'No answered questions yet.'
                                : 'No questions left to answer.',
                            icon: Icons.filter_list_off,
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                            itemCount: visibleQuestions.length + 1,
                            itemBuilder: (_, i) {
                              if (i == visibleQuestions.length) {
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
                                                style: GoogleFonts.inter(
                                                    color: AppColors.blue)),
                                          ),
                                        ),
                                      )
                                    : const SizedBox.shrink();
                              }
                              final question = visibleQuestions[i];
                              return _QuestionCard(
                                key: ValueKey(question.id),
                                question: question,
                                answerState: _answerStateFor(question),
                                onAnswered: () => _markAnswered(question.id),
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
class _QuestionImage extends StatelessWidget {
  final String imageUrl;

  const _QuestionImage({required this.imageUrl});

  String get _resolvedUrl {
    final value = imageUrl.trim();
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    if (value.startsWith('/')) return '${AppConfig.baseUrl}$value';
    return '${AppConfig.baseUrl}/$value';
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxHeight: 260),
        color: AppColors.slate50,
        child: Image.network(
          _resolvedUrl,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Container(
            height: 72,
            alignment: Alignment.center,
            child: Text(
              'Question image could not be loaded',
              style: GoogleFonts.inter(fontSize: 11, color: AppColors.slate700),
            ),
          ),
        ),
      ),
    );
  }
}

// Statistics Pill Widget
// ─────────────────────────────────────────────────────────────────────────────

class _StatPill extends StatelessWidget {
  final String emoji;
  final String label;
  final int count;
  final Color color;
  final Color bgColor;
  final bool selected;
  final VoidCallback? onTap;

  const _StatPill({
    required this.emoji,
    required this.label,
    required this.count,
    required this.color,
    required this.bgColor,
    this.selected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      selected: selected,
      label: onTap == null ? '$label: $count' : 'Show $label questions: $count',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? color.withAlpha(24) : bgColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? color : color.withAlpha(40),
              width: selected ? 1.5 : 1,
            ),
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
        ),
      ),
    );
  }
}

class _QuestionCard extends StatefulWidget {
  final QuestionModel question;
  final _QuestionAnswerState answerState;
  final VoidCallback onAnswered;
  const _QuestionCard({
    super.key,
    required this.question,
    required this.answerState,
    required this.onAnswered,
  });

  @override
  State<_QuestionCard> createState() => _QuestionCardState();
}

class _QuestionCardState extends State<_QuestionCard> {
  Future<void> _check() async {
    final answerState = widget.answerState;
    final question = widget.question;
    final onAnswered = widget.onAnswered;
    setState(() => answerState.submitting = true);
    try {
      final body = question.qType == 'mcq'
          ? {'selected_index': answerState.selectedIndex}
          : {'typed_answer': answerState.typedAnswer};
      final response = await dioClient
          .post(ApiEndpoints.checkQuestion(question.id), data: body);
      answerState
        ..result = Map<String, dynamic>.from(response.data as Map)
        ..submitting = false;
      // The parent owns this state, so it survives list-item recycling.
      onAnswered();
      if (mounted) setState(() {});
    } catch (_) {
      answerState.submitting = false;
      if (mounted) setState(() {});
    }
  }

  Color _difficultyColor(String d) => d == 'easy'
      ? AppColors.success
      : d == 'hard'
          ? AppColors.error
          : AppColors.warning;

  @override
  Widget build(BuildContext context) {
    final q = widget.question;
    final answerState = widget.answerState;
    final result = answerState.result;
    final questionImages = q.imageUrls;
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
                if (q.topic.trim().isNotEmpty) ...[
                  _Badge(q.topic, AppColors.blue),
                  const SizedBox(width: 6),
                ],
                const Spacer(),
                _Badge(q.difficulty, _difficultyColor(q.difficulty)),
              ],
            ),
            const SizedBox(height: 12),
            Text(_plainTextFromHtml(q.questionText),
                style: GoogleFonts.inter(fontSize: 14, color: AppColors.navy)),
            if (questionImages.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...questionImages.map((imageUrl) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _QuestionImage(imageUrl: imageUrl),
                  )),
            ],
            const SizedBox(height: 12),

            // MCQ options
            if (q.qType == 'mcq' &&
                q.options != null &&
                q.options!.isNotEmpty) ...[
              ...q.options!.asMap().entries.map((e) {
                final idx = e.key;
                final opt = e.value;
                final isSelected = answerState.selectedIndex == idx;
                Color? bg;
                if (result != null) {
                  final correctIdx = result['correct_index'];
                  if (idx == correctIdx) bg = AppColors.success.withAlpha(30);
                  if (isSelected && idx != correctIdx) {
                    bg = AppColors.error.withAlpha(30);
                  }
                }
                return GestureDetector(
                  onTap: result == null
                      ? () => setState(() => answerState.selectedIndex = idx)
                      : null,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: bg ??
                          (isSelected
                              ? AppColors.blue.withAlpha(15)
                              : AppColors.slate50),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? AppColors.blue : AppColors.slate200,
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.blue
                                : AppColors.slate200,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(opt.label,
                                style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: isSelected
                                        ? Colors.white
                                        : AppColors.slate700)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                            child: Text(_plainTextFromHtml(opt.text),
                                style: GoogleFonts.inter(
                                    fontSize: 13, color: AppColors.navy))),
                      ],
                    ),
                  ),
                );
              }),
            ],

            if (q.qType == 'mcq' && (q.options == null || q.options!.isEmpty))
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warning.withAlpha(15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.warning.withAlpha(50)),
                ),
                child: Text(
                  'Answer options are unavailable for this question. Please ask the administrator to edit and republish it.',
                  style: GoogleFonts.inter(
                      fontSize: 12, color: AppColors.slate700),
                ),
              ),

            // Typed input
            if (q.qType == 'typed') ...[
              TextFormField(
                initialValue: answerState.typedAnswer,
                enabled: result == null,
                onChanged: (v) => setState(() => answerState.typedAnswer = v),
                decoration: InputDecoration(
                  hintText: 'Type your answer here',
                  hintStyle: GoogleFonts.inter(
                      color: AppColors.slate400, fontSize: 13),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.slate200)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.slate200)),
                ),
              ),
            ],

            // Result
            if (result != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (result['correct'] == true
                          ? AppColors.success
                          : AppColors.error)
                      .withAlpha(15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(
                          result['correct'] == true
                              ? Icons.check_circle
                              : Icons.cancel,
                          size: 16,
                          color: result['correct'] == true
                              ? AppColors.success
                              : AppColors.error),
                      const SizedBox(width: 6),
                      Text(result['correct'] == true ? 'Correct!' : 'Incorrect',
                          style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: result['correct'] == true
                                  ? AppColors.success
                                  : AppColors.error)),
                    ]),
                    if (result['explanation'] != null) ...[
                      const SizedBox(height: 6),
                      Text(_plainTextFromHtml(result['explanation']),
                          style: GoogleFonts.inter(
                              fontSize: 12, color: AppColors.slate700)),
                    ],
                  ],
                ),
              ),
            ],

            const SizedBox(height: 10),
            if (result == null)
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: (q.qType == 'mcq'
                              ? answerState.selectedIndex == null
                              : answerState.typedAnswer.trim().isEmpty) ||
                          answerState.submitting
                      ? null
                      : _check,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.blue,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(99)),
                  ),
                  child: answerState.submitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : Text('Check answer',
                          style: GoogleFonts.inter(
                              fontSize: 12, fontWeight: FontWeight.w600)),
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
          style: GoogleFonts.inter(
              fontSize: 10, fontWeight: FontWeight.w600, color: color)),
    );
  }
}
