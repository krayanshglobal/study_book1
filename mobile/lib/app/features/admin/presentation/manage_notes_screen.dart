import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/api/api_endpoints.dart';
import '../../../core/api/dio_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../common/widgets/app_drawer.dart';
import '../../common/widgets/shared_widgets.dart';

class ManageNotesScreen extends ConsumerStatefulWidget {
  const ManageNotesScreen({super.key});

  @override
  ConsumerState<ManageNotesScreen> createState() => _ManageNotesScreenState();
}

class _ManageNotesScreenState extends ConsumerState<ManageNotesScreen> {
  List _items = [];
  bool _loading = true;

  // Form fields
  String? _editingId;
  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  final _topicCtrl = TextEditingController();
  String _subject = 'maths';
  String _classLevel = '10';
  bool _premiumOnly = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    _topicCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = await dioClient.get(ApiEndpoints.notes,
          queryParameters: {'class_level': _classLevel});
      if (!mounted) return;
      setState(() {
        _items = r.data['items'] ?? [];
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        showToast(context, 'Failed to load study notes.', isError: true);
      }
    }
  }

  void _startAdd() {
    _editingId = null;
    _titleCtrl.clear();
    _contentCtrl.clear();
    _topicCtrl.clear();
    _subject = 'maths';
    _premiumOnly = false;
    _showFormDialog();
  }

  void _startEdit(Map note) {
    _editingId = note['_id']?.toString();
    _titleCtrl.text = note['title'] ?? '';
    _contentCtrl.text = note['content'] ?? '';
    _topicCtrl.text = note['topic'] ?? '';
    _subject = note['subject'] ?? 'maths';
    _classLevel = note['class_level'] ?? '10';
    _premiumOnly = note['premium_only'] == true;
    _showFormDialog();
  }

  void _showFormDialog() {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            _editingId == null ? 'Create Study Note' : 'Edit Study Note',
            style: GoogleFonts.fraunces(fontSize: 20, color: AppColors.navy),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _label('Title'),
                _textField(_titleCtrl, 'e.g. Fundamental Theorem of Algebra'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label('Class Level'),
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
                          DropdownButtonFormField<String>(
                            initialValue: _subject,
                            decoration: _dropDec(),
                            items: const [
                              DropdownMenuItem(value: 'maths', child: Text('Mathematics')),
                              DropdownMenuItem(value: 'science', child: Text('Science')),
                            ],
                            onChanged: (v) => setSt(() => _subject = v!),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _label('Topic'),
                _textField(_topicCtrl, 'e.g. Trigonometry'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Switch(
                      value: _premiumOnly,
                      onChanged: (v) => setSt(() => _premiumOnly = v),
                      activeThumbColor: AppColors.violet,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('Premium only (lock for non-paying users)',
                          style: GoogleFonts.inter(fontSize: 13)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _label('Content'),
                TextField(
                  controller: _contentCtrl,
                  maxLines: 6,
                  decoration: InputDecoration(
                    hintText: 'Write note content…',
                    hintStyle: GoogleFonts.inter(fontSize: 13, color: AppColors.slate400),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.slate200),
                    ),
                    contentPadding: const EdgeInsets.all(12),
                  ),
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
                if (_titleCtrl.text.trim().isEmpty || _contentCtrl.text.trim().isEmpty) {
                  showToast(ctx, 'Please fill in title and content.', isError: true);
                  return;
                }
                final payload = {
                  'title': _titleCtrl.text.trim(),
                  'content': _contentCtrl.text.trim(),
                  'subject': _subject,
                  'class_level': _classLevel,
                  'topic': _topicCtrl.text.trim(),
                  'premium_only': _premiumOnly,
                };
                try {
                  if (_editingId != null) {
                    await dioClient.put(ApiEndpoints.noteDetail(_editingId!), data: payload);
                    if (ctx.mounted) showToast(ctx, 'Study note updated successfully');
                  } else {
                    await dioClient.post(ApiEndpoints.notes, data: payload);
                    if (ctx.mounted) showToast(ctx, 'Study note published successfully');
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                  _load();
                } catch (e) {
                  if (ctx.mounted) showToast(ctx, formatApiError(e), isError: true);
                }
              },
              child: Text(
                _editingId == null ? 'Publish Note' : 'Save Changes',
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
            title: Text('Delete Note?', style: GoogleFonts.fraunces(color: AppColors.navy)),
            content: Text('Are you sure you want to delete this study note?', style: GoogleFonts.inter()),
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
      await dioClient.delete(ApiEndpoints.noteDetail(id));
      if (mounted) showToast(context, 'Note deleted successfully');
      _load();
    } catch (e) {
      if (mounted) showToast(context, formatApiError(e), isError: true);
    }
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(t, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.slate500)),
      );

  Widget _textField(TextEditingController ctrl, String hint) => TextField(
        controller: ctrl,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.inter(fontSize: 13, color: AppColors.slate400),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.slate200),
          ),
        ),
        style: GoogleFonts.inter(fontSize: 13),
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
      title: 'Study Notes',
      showBack: true,
      parentRoute: '/admin',
      floatingActionButton: FloatingActionButton(
        onPressed: _startAdd,
        backgroundColor: AppColors.violet,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _loading
          ? const LoadingIndicator()
          : RefreshIndicator(
              onRefresh: _load,
              child: _items.isEmpty
                  ? const _EmptyState('No study notes published yet.')
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      itemCount: _items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (_, i) {
                        final n = _items[i];
                        return Container(
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.slate100),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Class ${n['class_level']} · ${n['subject']} · ${n['topic']}'.toUpperCase(),
                                      style: GoogleFonts.inter(
                                          fontSize: 10, fontWeight: FontWeight.w700,
                                          letterSpacing: 1.2, color: AppColors.violet),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(n['title'] ?? '',
                                        style: GoogleFonts.fraunces(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.navy)),
                                    const SizedBox(height: 6),
                                    Text(
                                      _stripHtml(n['content'] ?? '').length > 120
                                          ? '${_stripHtml(n['content'] ?? '').substring(0, 120)}…'
                                          : _stripHtml(n['content'] ?? ''),
                                      style: GoogleFonts.inter(fontSize: 12, color: AppColors.slate500),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                decoration: const BoxDecoration(
                                  color: AppColors.slate50,
                                  border: Border(top: BorderSide(color: AppColors.slate100)),
                                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
                                ),
                                child: Row(
                                  children: [
                                    if (n['premium_only'] == true)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF59E0B),
                                          borderRadius: BorderRadius.circular(99),
                                        ),
                                        child: Text('PREMIUM',
                                            style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white)),
                                      ),
                                    const Spacer(),
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.slate500),
                                      onPressed: () => _startEdit(n),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                      onPressed: () => _delete(n['_id']?.toString() ?? ''),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
    );
  }

  String _stripHtml(String html) =>
      html.replaceAll(RegExp(r'<[^>]*>'), '').replaceAll('&amp;', '&').trim();
}

class _EmptyState extends StatelessWidget {
  final String msg;
  const _EmptyState(this.msg);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(msg,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 14, color: AppColors.slate500)),
      ),
    );
  }
}
