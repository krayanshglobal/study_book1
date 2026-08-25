import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/api/api_endpoints.dart';
import '../../../core/api/dio_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../common/widgets/app_drawer.dart';
import '../../common/widgets/shared_widgets.dart';

class ManageFlashcardsScreen extends ConsumerStatefulWidget {
  const ManageFlashcardsScreen({super.key});

  @override
  ConsumerState<ManageFlashcardsScreen> createState() =>
      _ManageFlashcardsScreenState();
}

class _ManageFlashcardsScreenState
    extends ConsumerState<ManageFlashcardsScreen> {
  List _items = [];
  bool _loading = true;

  // Filter state
  String _filterClass = '10';
  final _filterTopicCtrl = TextEditingController();

  // Form state
  String? _editingId;
  final _frontCtrl = TextEditingController();
  final _backCtrl = TextEditingController();
  final _topicCtrl = TextEditingController();
  String _subject = 'maths';
  String _classLevel = '10';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _filterTopicCtrl.dispose();
    _frontCtrl.dispose();
    _backCtrl.dispose();
    _topicCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final params = <String, dynamic>{};
      if (_filterClass != 'all') params['class_level'] = _filterClass;
      final topic = _filterTopicCtrl.text.trim();
      if (topic.isNotEmpty) params['topic'] = topic;

      final r = await dioClient.get(ApiEndpoints.flashcards, queryParameters: params);
      if (!mounted) return;
      setState(() {
        _items = r.data['items'] ?? [];
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        showToast(context, formatApiError(e), isError: true);
      }
    }
  }

  void _openNew() {
    _editingId = null;
    _frontCtrl.clear();
    _backCtrl.clear();
    _topicCtrl.clear();
    _subject = 'maths';
    _classLevel = _filterClass == 'all' ? '10' : _filterClass;
    _showDialog();
  }

  void _openEdit(Map fc) {
    _editingId = fc['_id']?.toString();
    _frontCtrl.text = fc['front'] ?? '';
    _backCtrl.text = fc['back'] ?? '';
    _topicCtrl.text = fc['topic'] ?? '';
    _subject = fc['subject'] ?? 'maths';
    _classLevel = fc['class_level'] ?? '10';
    _showDialog();
  }

  void _showDialog() {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            _editingId == null ? 'New Flashcard' : 'Edit Flashcard',
            style: GoogleFonts.fraunces(fontSize: 20, color: AppColors.navy),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label('Class'),
                          DropdownButtonFormField<String>(
                            initialValue: _classLevel,
                            decoration: _dropDec(),
                            items: ['8', '9', '10']
                                .map((c) => DropdownMenuItem(value: c, child: Text('Class $c')))
                                .toList(),
                            onChanged: (v) => setSt(() => _classLevel = v!),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label('Subject'),
                          TextField(
                            controller: TextEditingController(text: _subject),
                            decoration: _inputDec('maths'),
                            style: GoogleFonts.inter(fontSize: 13),
                            onChanged: (v) => _subject = v,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label('Topic'),
                          TextField(
                            controller: _topicCtrl,
                            decoration: _inputDec('e.g. Algebra'),
                            style: GoogleFonts.inter(fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _label('Front (question / term)'),
                TextField(
                  controller: _frontCtrl,
                  maxLines: 3,
                  decoration: _inputDec('e.g. What is sin(30°)?'),
                  style: GoogleFonts.inter(fontSize: 13),
                ),
                const SizedBox(height: 12),
                _label('Back (answer)'),
                TextField(
                  controller: _backCtrl,
                  maxLines: 3,
                  decoration: _inputDec('e.g. 1/2'),
                  style: GoogleFonts.inter(fontSize: 13),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.navy,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
              ),
              onPressed: () async {
                if (_frontCtrl.text.trim().isEmpty || _backCtrl.text.trim().isEmpty) {
                  showToast(ctx, 'Front and back are required', isError: true);
                  return;
                }
                final payload = {
                  'subject': _subject,
                  'class_level': _classLevel,
                  'topic': _topicCtrl.text.trim(),
                  'front': _frontCtrl.text.trim(),
                  'back': _backCtrl.text.trim(),
                };
                try {
                  if (_editingId != null) {
                    await dioClient.put(ApiEndpoints.flashcardDetail(_editingId!), data: payload);
                    if (ctx.mounted) showToast(ctx, 'Flashcard updated');
                  } else {
                    await dioClient.post(ApiEndpoints.flashcards, data: payload);
                    if (ctx.mounted) showToast(ctx, 'Flashcard created');
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                  _load();
                } catch (e) {
                  if (ctx.mounted) showToast(ctx, formatApiError(e), isError: true);
                }
              },
              child: Text(
                _editingId == null ? 'Create' : 'Update',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _delete(String id) async {
    final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('Delete Flashcard?', style: GoogleFonts.fraunces(color: AppColors.navy)),
            content: Text('Are you sure?', style: GoogleFonts.inter()),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Delete', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ) ??
        false;
    if (!ok) return;
    try {
      await dioClient.delete(ApiEndpoints.flashcardDetail(id));
      if (mounted) showToast(context, 'Deleted');
      _load();
    } catch (e) {
      if (mounted) showToast(context, formatApiError(e), isError: true);
    }
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(t, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.slate500)),
      );

  InputDecoration _inputDec(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(fontSize: 13, color: AppColors.slate400),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.slate200),
        ),
      );

  InputDecoration _dropDec() => InputDecoration(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.slate200),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return MainScaffold(
      title: 'Flashcards',
      showBack: true,
      parentRoute: '/admin',
      floatingActionButton: FloatingActionButton(
        onPressed: _openNew,
        backgroundColor: AppColors.violet,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        children: [
          // Filters
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                DropdownButton<String>(
                  value: _filterClass,
                  underline: const SizedBox(),
                  style: GoogleFonts.inter(fontSize: 13, color: AppColors.navy),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All classes')),
                    DropdownMenuItem(value: '8', child: Text('Class 8')),
                    DropdownMenuItem(value: '9', child: Text('Class 9')),
                    DropdownMenuItem(value: '10', child: Text('Class 10')),
                  ],
                  onChanged: (v) {
                    setState(() => _filterClass = v!);
                    _load();
                  },
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _filterTopicCtrl,
                    decoration: InputDecoration(
                      hintText: 'Filter by topic…',
                      hintStyle: GoogleFonts.inter(fontSize: 12, color: AppColors.slate400),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(99)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(99),
                        borderSide: const BorderSide(color: AppColors.slate200),
                      ),
                    ),
                    onSubmitted: (_) => _load(),
                    textInputAction: TextInputAction.search,
                    style: GoogleFonts.inter(fontSize: 12),
                  ),
                ),
                const SizedBox(width: 8),
                Text('${_items.length} cards',
                    style: GoogleFonts.inter(fontSize: 12, color: AppColors.slate400)),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.slate200),
          Expanded(
            child: _loading
                ? const LoadingIndicator()
                : _items.isEmpty
                    ? Center(
                        child: Text('No flashcards yet. Create one.',
                            style: GoogleFonts.inter(fontSize: 14, color: AppColors.slate500)),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) {
                          final fc = _items[i];
                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.slate100),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${fc['topic'] ?? ''} · Class ${fc['class_level'] ?? ''}'.toUpperCase(),
                                        style: GoogleFonts.inter(
                                            fontSize: 10, fontWeight: FontWeight.w700,
                                            letterSpacing: 1, color: AppColors.violet),
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () => _openEdit(fc),
                                      child: const Icon(Icons.edit_outlined, size: 16, color: AppColors.slate400),
                                    ),
                                    const SizedBox(width: 8),
                                    GestureDetector(
                                      onTap: () => _delete(fc['_id']?.toString() ?? ''),
                                      child: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                                    ),
                                  ],
                                ),
                                const Divider(height: 14),
                                Text('FRONT', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: AppColors.slate400)),
                                const SizedBox(height: 2),
                                Text(fc['front'] ?? '', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.navy)),
                                const Divider(height: 14),
                                Text('BACK', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: AppColors.slate400)),
                                const SizedBox(height: 2),
                                Text(fc['back'] ?? '', style: GoogleFonts.inter(fontSize: 13, color: AppColors.slate700)),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
