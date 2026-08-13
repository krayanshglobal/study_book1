import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_endpoints.dart';
import '../../../core/api/dio_client.dart';
import '../../../core/models/question_model.dart';
import '../../../core/theme/app_colors.dart';
import '../../common/widgets/app_drawer.dart';
import '../../common/widgets/shared_widgets.dart';

class ManageQuestionsScreen extends ConsumerStatefulWidget {
  const ManageQuestionsScreen({super.key});

  @override
  ConsumerState<ManageQuestionsScreen> createState() => _ManageQuestionsScreenState();
}

class _ManageQuestionsScreenState extends ConsumerState<ManageQuestionsScreen> {
  List<QuestionModel> _questions = [];
  bool _loading = true;
  String? _filterClass;
  String? _filterTopic;
  DateTime? _filterDate;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final params = <String, dynamic>{'limit': 100};
      if (_filterClass != null) params['class_level'] = _filterClass;
      if (_filterTopic != null && _filterTopic!.trim().isNotEmpty) params['topic'] = _filterTopic!.trim();
      if (_filterDate != null) params['date'] = DateFormat('yyyy-MM-dd').format(_filterDate!);
      final r = await dioClient.get(ApiEndpoints.questions, queryParameters: params);
      final list = (r.data['items'] as List).map((e) => QuestionModel.fromJson(e)).toList();
      if (mounted) setState(() { _questions = list; _loading = false; });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        showToast(context, formatApiError(e), isError: true);
      }
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
      _load();
    }
  }

  void _resetFilters() {
    setState(() {
      _filterClass = null;
      _filterTopic = null;
      _filterDate = null;
    });
    _load();
  }

  Future<void> _deleteQuestion(String id) async {
    try {
      await dioClient.delete(ApiEndpoints.questionDetail(id));
      if (!mounted) return;
      showToast(context, 'Question deleted');
      _load();
    } catch (e) {
      if (!mounted) return;
      showToast(context, formatApiError(e), isError: true);
    }
  }

  void _showCreateDialog() {
    final textCtrl = TextEditingController();
    final topicCtrl = TextEditingController();
    final optionACtrl = TextEditingController();
    final optionBCtrl = TextEditingController();
    final optionCCtrl = TextEditingController();
    final optionDCtrl = TextEditingController();
    final explanationCtrl = TextEditingController();
    String classLevel = '10';
    String qType = 'mcq';
    int correctIndex = 0;
    String typedAnswer = '';
    String difficulty = 'medium';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Create Question', style: GoogleFonts.fraunces(fontSize: 20, fontWeight: FontWeight.w600)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: classLevel,
                  decoration: const InputDecoration(labelText: 'Class Level'),
                  items: const [
                    DropdownMenuItem(value: '8', child: Text('Class 8')),
                    DropdownMenuItem(value: '9', child: Text('Class 9')),
                    DropdownMenuItem(value: '10', child: Text('Class 10')),
                  ],
                  onChanged: (v) => setDialogState(() => classLevel = v!),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: topicCtrl,
                  decoration: const InputDecoration(labelText: 'Topic (e.g. Algebra)'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: textCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Question Text'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: qType,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: const [
                    DropdownMenuItem(value: 'mcq', child: Text('MCQ')),
                    DropdownMenuItem(value: 'typed', child: Text('Typed Answer')),
                  ],
                  onChanged: (v) => setDialogState(() => qType = v!),
                ),
                if (qType == 'mcq') ...[
                  const SizedBox(height: 10),
                  TextField(controller: optionACtrl, decoration: const InputDecoration(labelText: 'Option A')),
                  const SizedBox(height: 6),
                  TextField(controller: optionBCtrl, decoration: const InputDecoration(labelText: 'Option B')),
                  const SizedBox(height: 6),
                  TextField(controller: optionCCtrl, decoration: const InputDecoration(labelText: 'Option C')),
                  const SizedBox(height: 6),
                  TextField(controller: optionDCtrl, decoration: const InputDecoration(labelText: 'Option D')),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<int>(
                    initialValue: correctIndex,
                    decoration: const InputDecoration(labelText: 'Correct Option'),
                    items: const [
                      DropdownMenuItem(value: 0, child: Text('Option A')),
                      DropdownMenuItem(value: 1, child: Text('Option B')),
                      DropdownMenuItem(value: 2, child: Text('Option C')),
                      DropdownMenuItem(value: 3, child: Text('Option D')),
                    ],
                    onChanged: (v) => setDialogState(() => correctIndex = v!),
                  ),
                ] else ...[
                  const SizedBox(height: 10),
                  TextField(
                    onChanged: (v) => typedAnswer = v,
                    decoration: const InputDecoration(labelText: 'Correct Answer Text'),
                  ),
                ],
                const SizedBox(height: 10),
                TextField(
                  controller: explanationCtrl,
                  decoration: const InputDecoration(labelText: 'Explanation'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (textCtrl.text.trim().isEmpty || topicCtrl.text.trim().isEmpty) {
                  showToast(context, 'Please fill in question text and topic', isError: true);
                  return;
                }
                Navigator.pop(ctx);
                try {
                  final body = <String, dynamic>{
                    'subject': 'maths',
                    'class_level': classLevel,
                    'topic': topicCtrl.text.trim(),
                    'question_text': textCtrl.text.trim(),
                    'q_type': qType,
                    'explanation': explanationCtrl.text.trim(),
                    'positive_marks': 1.0,
                    'negative_marks': 0.25,
                    'difficulty': difficulty,
                  };
                  if (qType == 'mcq') {
                    body['options'] = [
                      {'label': 'A', 'text': optionACtrl.text.trim()},
                      {'label': 'B', 'text': optionBCtrl.text.trim()},
                      {'label': 'C', 'text': optionCCtrl.text.trim()},
                      {'label': 'D', 'text': optionDCtrl.text.trim()},
                    ];
                    body['correct_index'] = correctIndex;
                    body['correct_answer_text'] = [
                      optionACtrl.text, optionBCtrl.text, optionCCtrl.text, optionDCtrl.text
                    ][correctIndex].trim();
                  } else {
                    body['correct_answer_text'] = typedAnswer.trim();
                  }
                  await dioClient.post(ApiEndpoints.questions, data: body);
                  if (!mounted) return;
                  showToast(context, 'Question created!');
                  _load();
                } catch (e) {
                  if (!mounted) return;
                  showToast(context, formatApiError(e), isError: true);
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MainScaffold(
      title: 'Manage Questions',
      showBack: true,
      parentRoute: '/admin',
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateDialog,
        backgroundColor: AppColors.navy,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            color: AppColors.white,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _filterClass,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          isDense: true,
                        ),
                        hint: const Text('All classes'),
                        items: const [
                          DropdownMenuItem(value: null, child: Text('All classes')),
                          DropdownMenuItem(value: '8', child: Text('Class 8')),
                          DropdownMenuItem(value: '9', child: Text('Class 9')),
                          DropdownMenuItem(value: '10', child: Text('Class 10')),
                        ],
                        onChanged: (val) {
                          setState(() => _filterClass = val);
                          _load();
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        onChanged: (val) {
                          setState(() => _filterTopic = val);
                          _load();
                        },
                        decoration: InputDecoration(
                          hintText: 'Topic',
                          hintStyle: GoogleFonts.inter(fontSize: 13, color: AppColors.slate400),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: AppColors.slate200)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: AppColors.slate200)),
                          isDense: true,
                        ),
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
                                    _load();
                                  },
                                  child: const Icon(Icons.close, size: 16, color: AppColors.slate500),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (_filterClass != null || (_filterTopic != null && _filterTopic!.isNotEmpty) || _filterDate != null) ...[
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
          const Divider(height: 1, color: AppColors.slate200),
          Expanded(
            child: _loading
                ? const LoadingIndicator()
                : _questions.isEmpty
                    ? const EmptyState(message: 'No questions in bank.', icon: Icons.quiz_outlined)
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _questions.length,
                          itemBuilder: (ctx, i) {
                            final q = _questions[i];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppColors.slate200),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.blue.withAlpha(20),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text('Class ${q.classLevel}', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.blue)),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(q.topic, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.violet)),
                                      const Spacer(),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                                        onPressed: () => _deleteQuestion(q.id),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(q.questionText, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.navy)),
                                  const SizedBox(height: 6),
                                  Text('Type: ${q.qType.toUpperCase()} | Correct: ${q.correctAnswerText ?? 'Option index ${q.correctIndex}'}',
                                      style: GoogleFonts.inter(fontSize: 12, color: AppColors.slate500)),
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
