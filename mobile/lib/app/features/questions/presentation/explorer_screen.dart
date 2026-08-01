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

class ExplorerScreen extends ConsumerStatefulWidget {
  const ExplorerScreen({super.key});

  @override
  ConsumerState<ExplorerScreen> createState() => _ExplorerScreenState();
}

class _ExplorerScreenState extends ConsumerState<ExplorerScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Filters
  final String _subject = 'maths';
  final _topicController = TextEditingController(text: 'Algebra');

  // Content
  List _notes = [];
  List _videos = [];
  List _tests = [];
  List _discussions = [];
  List _flashcards = [];
  bool _flashcardsLocked = false;

  // Flashcard state
  int _activeCardIndex = 0;
  bool _isFlipped = false;

  // Discussion thread
  Map? _activeThread;
  List _threadReplies = [];
  final _replyController = TextEditingController();

  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _fetchData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _topicController.dispose();
    _replyController.dispose();
    super.dispose();
  }

  String get _classLevel =>
      ref.read(authProvider).user?.classLevel ?? '10';

  bool get _isAdmin {
    final role = ref.read(authProvider).user?.role ?? '';
    return role == 'admin' || role == 'superadmin';
  }

  bool get _isPremium {
    final user = ref.read(authProvider).user;
    return _isAdmin || (user?.subscriptionActive ?? false);
  }

  Future<void> _fetchData() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final cl = _classLevel;
      final sub = _subject;
      final top = _topicController.text.trim();

      final results = await Future.wait([
        dioClient.get(ApiEndpoints.notes,
            queryParameters: {'class_level': cl, 'subject': sub, 'topic': top}),
        dioClient.get(ApiEndpoints.videos, queryParameters: {'class_level': cl}),
        dioClient.get(ApiEndpoints.tests, queryParameters: {'class_level': cl}),
        dioClient.get(ApiEndpoints.discussions,
            queryParameters: {'class_level': cl, 'subject': sub, 'topic': top}),
        dioClient.get(ApiEndpoints.flashcards,
            queryParameters: {'class_level': cl, 'subject': sub, 'topic': top}),
      ]);

      final allVideos = (results[1].data['items'] as List? ?? []);
      final filteredVideos = allVideos.where((v) {
        final vSub = (v['subject'] as String? ?? '').toLowerCase();
        final vTop = (v['topic'] as String? ?? '').toLowerCase();
        return vSub == sub.toLowerCase() && (top.isEmpty || vTop == top.toLowerCase());
      }).toList();

      final allTests = (results[2].data['items'] as List? ?? []);
      final filteredTests = allTests.where((t) {
        final tSub = (t['subject'] as String? ?? '').toLowerCase();
        return tSub == sub.toLowerCase() && (t['is_published'] == true);
      }).toList();

      if (!mounted) return;
      setState(() {
        _notes = results[0].data['items'] ?? [];
        _videos = filteredVideos;
        _tests = filteredTests;
        _discussions = results[3].data['items'] ?? [];
        _flashcardsLocked = results[4].data['locked'] == true;
        _flashcards = results[4].data['items'] ?? [];
        _activeCardIndex = 0;
        _isFlipped = false;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
      if (mounted) showToast(context, 'Failed to load study explorer contents.', isError: true);
    }
  }

  Future<void> _viewThread(String threadId) async {
    try {
      final res = await dioClient.get(ApiEndpoints.discussionDetail(threadId));
      if (!mounted) return;
      setState(() {
        _activeThread = res.data as Map;
        _threadReplies = (res.data['replies'] as List? ?? []);
      });
      _showThreadDialog();
    } catch (_) {
      if (mounted) showToast(context, 'Failed to load thread replies.', isError: true);
    }
  }

  Future<void> _submitReply() async {
    final body = _replyController.text.trim();
    if (body.isEmpty || _activeThread == null) return;
    try {
      final res = await dioClient.post(
        ApiEndpoints.discussionReply(_activeThread!['_id'].toString()),
        data: {'body': body},
      );
      if (!mounted) return;
      setState(() {
        _threadReplies = [..._threadReplies, res.data];
        _replyController.clear();
      });
      if (mounted) showToast(context, 'Reply posted!');
    } catch (e) {
      if (mounted) showToast(context, formatApiError(e), isError: true);
    }
  }

  Future<void> _deleteThread(String tid) async {
    final ok = await _confirm('Delete this thread?');
    if (!ok) return;
    try {
      await dioClient.delete(ApiEndpoints.discussionDetail(tid));
      if (!mounted) return;
      if (_activeThread?['_id']?.toString() == tid) setState(() => _activeThread = null);
      showToast(context, 'Thread deleted.');
      _fetchData();
    } catch (e) {
      if (mounted) showToast(context, formatApiError(e), isError: true);
    }
  }

  Future<void> _deleteReply(String rid) async {
    final ok = await _confirm('Delete this reply?');
    if (!ok || _activeThread == null) return;
    try {
      await dioClient.delete(
          ApiEndpoints.deleteDiscussionReply(_activeThread!['_id'].toString(), rid));
      if (!mounted) return;
      setState(() {
        _threadReplies = _threadReplies.where((r) => r['reply_id']?.toString() != rid).toList();
      });
      showToast(context, 'Reply deleted.');
    } catch (e) {
      if (mounted) showToast(context, formatApiError(e), isError: true);
    }
  }

  Future<void> _deleteFlashcard(String fid) async {
    final ok = await _confirm('Delete this flashcard?');
    if (!ok) return;
    try {
      await dioClient.delete(ApiEndpoints.flashcardDetail(fid));
      if (!mounted) return;
      showToast(context, 'Flashcard deleted.');
      _fetchData();
    } catch (e) {
      if (mounted) showToast(context, formatApiError(e), isError: true);
    }
  }

  Future<bool> _confirm(String msg) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('Confirm', style: GoogleFonts.fraunces(color: AppColors.navy)),
            content: Text(msg, style: GoogleFonts.inter()),
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
  }

  void _showCreateThreadDialog() {
    final titleCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Ask a Doubt', style: GoogleFonts.fraunces(fontSize: 20, color: AppColors.navy)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Doubt Title', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.slate500)),
              const SizedBox(height: 6),
              TextField(
                controller: titleCtrl,
                decoration: _inputDec('Briefly state your question…'),
              ),
              const SizedBox(height: 12),
              Text('Detailed Description', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.slate500)),
              const SizedBox(height: 6),
              TextField(
                controller: bodyCtrl,
                maxLines: 4,
                decoration: _inputDec('Explain what you need help with…'),
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
              if (titleCtrl.text.trim().isEmpty || bodyCtrl.text.trim().isEmpty) {
                showToast(ctx, 'Please fill in all fields.', isError: true);
                return;
              }
              try {
                await dioClient.post(ApiEndpoints.discussions, data: {
                  'title': titleCtrl.text.trim(),
                  'body': bodyCtrl.text.trim(),
                  'class_level': _classLevel,
                  'subject': _subject,
                  'topic': _topicController.text.trim(),
                });
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) showToast(context, 'Doubt posted successfully!');
                _fetchData();
              } catch (e) {
                if (ctx.mounted) showToast(ctx, formatApiError(e), isError: true);
              }
            },
            child: Text('Post Doubt', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _showAddFlashcardDialog() {
    final frontCtrl = TextEditingController();
    final backCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Create New Flashcard', style: GoogleFonts.fraunces(fontSize: 18, color: AppColors.navy)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Question / Term (Front)', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.slate500)),
              const SizedBox(height: 6),
              TextField(controller: frontCtrl, decoration: _inputDec('e.g. What is sin(45)?')),
              const SizedBox(height: 12),
              Text('Definition / Answer (Back)', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.slate500)),
              const SizedBox(height: 6),
              TextField(controller: backCtrl, maxLines: 3, decoration: _inputDec('e.g. 1/√2')),
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
              if (frontCtrl.text.trim().isEmpty || backCtrl.text.trim().isEmpty) {
                showToast(ctx, 'Please fill in front and back.', isError: true);
                return;
              }
              try {
                await dioClient.post(ApiEndpoints.flashcards, data: {
                  'subject': _subject,
                  'class_level': _classLevel,
                  'topic': _topicController.text.trim(),
                  'front': frontCtrl.text.trim(),
                  'back': backCtrl.text.trim(),
                });
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) showToast(context, 'Flashcard added successfully!');
                _fetchData();
              } catch (e) {
                if (ctx.mounted) showToast(ctx, formatApiError(e), isError: true);
              }
            },
            child: Text('Save Flashcard', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _showNoteDialog(Map note) {
    final isPremiumNote = note['premium_only'] == true;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(note['title'] ?? '',
                  style: GoogleFonts.fraunces(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.navy)),
              const SizedBox(height: 6),
              Text(
                '${note['subject'] ?? ''} · Class ${note['class_level'] ?? ''} · ${note['topic'] ?? ''}',
                style: GoogleFonts.inter(fontSize: 12, color: AppColors.slate500),
              ),
              const Divider(height: 24),
              if (isPremiumNote && !_isPremium)
                _PremiumLock(onUpgrade: () {
                  Navigator.pop(ctx);
                  context.push('/pricing');
                })
              else
                Text(
                  _stripHtml(note['content'] ?? ''),
                  style: GoogleFonts.inter(fontSize: 14, color: AppColors.slate700, height: 1.6),
                ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showThreadDialog() {
    if (_activeThread == null) return;
    final userId = ref.read(authProvider).user?.id ?? '';
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocalState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_activeThread!['title'] ?? '',
                    style: GoogleFonts.fraunces(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.navy)),
                Text(
                  'Posted by ${_activeThread!['user_name'] ?? ''} (${_activeThread!['user_role'] ?? ''})',
                  style: GoogleFonts.inter(fontSize: 11, color: AppColors.slate400),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.slate50, borderRadius: BorderRadius.circular(10)),
                  child: Text(_activeThread!['body'] ?? '',
                      style: GoogleFonts.inter(fontSize: 13, color: AppColors.slate700)),
                ),
                const SizedBox(height: 10),
                Text('ANSWERS & DISCUSSION',
                    style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: AppColors.slate400)),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: _threadReplies.isEmpty
                      ? Center(child: Text('No replies yet. Help solve this doubt!',
                          style: GoogleFonts.inter(fontSize: 12, color: AppColors.slate400)))
                      : ListView.builder(
                          itemCount: _threadReplies.length,
                          itemBuilder: (_, i) {
                            final r = _threadReplies[i];
                            final isOwn = r['user_id']?.toString() == userId;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.slate50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.slate100),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${r['user_name'] ?? ''} (${r['role'] ?? ''})',
                                          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.navy),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(r['body'] ?? '',
                                            style: GoogleFonts.inter(fontSize: 12, color: AppColors.slate700)),
                                      ],
                                    ),
                                  ),
                                  if (isOwn || _isAdmin)
                                    GestureDetector(
                                      onTap: () async {
                                        Navigator.pop(ctx);
                                        await _deleteReply(r['reply_id']?.toString() ?? '');
                                      },
                                      child: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _replyController,
                        decoration: _inputDec('Type your answer…'),
                        style: GoogleFonts.inter(fontSize: 13),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () async {
                        await _submitReply();
                        setLocalState(() {});
                      },
                      child: Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(color: AppColors.navy, borderRadius: BorderRadius.circular(99)),
                        child: const Icon(Icons.send, size: 18, color: Colors.white),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDec(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(fontSize: 13, color: AppColors.slate400),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.slate200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.slate200),
        ),
      );

  String _stripHtml(String html) =>
      html.replaceAll(RegExp(r'<[^>]*>'), '').replaceAll('&amp;', '&').replaceAll('&lt;', '<').replaceAll('&gt;', '>').trim();

  @override
  Widget build(BuildContext context) {
    return MainScaffold(
      title: 'Study Explorer',
      body: Column(
        children: [
          // Filter bar
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            color: AppColors.white,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: AppColors.navy,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text('Mathematics',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _topicController,
                    style: GoogleFonts.inter(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Topic/Chapter…',
                      hintStyle: GoogleFonts.inter(fontSize: 13, color: AppColors.slate400),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(99),
                        borderSide: const BorderSide(color: AppColors.slate200),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(99),
                        borderSide: const BorderSide(color: AppColors.slate200),
                      ),
                    ),
                    onSubmitted: (_) => _fetchData(),
                    textInputAction: TextInputAction.search,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.search, color: AppColors.navy),
                  onPressed: _fetchData,
                ),
              ],
            ),
          ),
          // Tabs
          Container(
            color: AppColors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: AppColors.navy,
              unselectedLabelColor: AppColors.slate400,
              indicatorColor: AppColors.navy,
              labelStyle: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600),
              unselectedLabelStyle: GoogleFonts.inter(fontSize: 11),
              tabs: const [
                Tab(icon: Icon(Icons.article_outlined, size: 16), text: 'Notes'),
                Tab(icon: Icon(Icons.style_outlined, size: 16), text: 'Cards'),
                Tab(icon: Icon(Icons.play_circle_outline, size: 16), text: 'Videos'),
                Tab(icon: Icon(Icons.menu_book_outlined, size: 16), text: 'Tests'),
                Tab(icon: Icon(Icons.forum_outlined, size: 16), text: 'Doubts'),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.slate200),
          Expanded(
            child: _loading
                ? const LoadingIndicator()
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _NotesTab(notes: _notes, onTap: _showNoteDialog),
                      _FlashcardsTab(
                        flashcards: _flashcards,
                        locked: _flashcardsLocked,
                        isPremium: _isPremium,
                        isAdmin: _isAdmin,
                        activeIndex: _activeCardIndex,
                        isFlipped: _isFlipped,
                        onFlip: () => setState(() => _isFlipped = !_isFlipped),
                        onPrev: () => setState(() {
                          _isFlipped = false;
                          _activeCardIndex = (_activeCardIndex - 1 + _flashcards.length) % _flashcards.length;
                        }),
                        onNext: () => setState(() {
                          _isFlipped = false;
                          _activeCardIndex = (_activeCardIndex + 1) % _flashcards.length;
                        }),
                        onDelete: (fid) => _deleteFlashcard(fid),
                        onAddCard: _isAdmin ? _showAddFlashcardDialog : null,
                        onUpgrade: () => context.push('/pricing'),
                      ),
                      _VideosTab(videos: _videos),
                      _TestsTab(tests: _tests, isPremium: _isPremium),
                      _DoubtsTab(
                        discussions: _discussions,
                        userId: ref.watch(authProvider).user?.id ?? '',
                        isAdmin: _isAdmin,
                        onViewThread: (tid) => _viewThread(tid),
                        onDeleteThread: (tid) => _deleteThread(tid),
                        onAskDoubt: _showCreateThreadDialog,
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

// Notes Tab
class _NotesTab extends StatelessWidget {
  final List notes;
  final Function(Map) onTap;
  const _NotesTab({required this.notes, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (notes.isEmpty) {
      return const _Empty('No study notes available for this topic.');
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: notes.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) {
        final n = notes[i];
        return GestureDetector(
          onTap: () => onTap(n),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.slate100),
              boxShadow: [
                BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 6, offset: const Offset(0, 2)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.violet.withAlpha(20),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text('NOTE',
                          style: GoogleFonts.inter(
                              fontSize: 9, fontWeight: FontWeight.w800,
                              letterSpacing: 1.2, color: AppColors.violet)),
                    ),
                    if (n['premium_only'] == true) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.lock, size: 10, color: Colors.white),
                            const SizedBox(width: 2),
                            Text('Premium',
                                style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white)),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                Text(n['title'] ?? '',
                    style: GoogleFonts.fraunces(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.navy)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      n['created_at'] != null
                          ? _formatDate(n['created_at'])
                          : '',
                      style: GoogleFonts.inter(fontSize: 11, color: AppColors.slate400),
                    ),
                    Row(
                      children: [
                        Text('Read Note',
                            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.blue)),
                        const SizedBox(width: 2),
                        const Icon(Icons.arrow_forward, size: 12, color: AppColors.blue),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static String _formatDate(String s) {
    try {
      final d = DateTime.parse(s).toLocal();
      return '${d.day}/${d.month}/${d.year}';
    } catch (_) {
      return '';
    }
  }
}

// Flashcards Tab
class _FlashcardsTab extends StatelessWidget {
  final List flashcards;
  final bool locked;
  final bool isPremium;
  final bool isAdmin;
  final int activeIndex;
  final bool isFlipped;
  final VoidCallback onFlip;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final Function(String) onDelete;
  final VoidCallback? onAddCard;
  final VoidCallback onUpgrade;

  const _FlashcardsTab({
    required this.flashcards,
    required this.locked,
    required this.isPremium,
    required this.isAdmin,
    required this.activeIndex,
    required this.isFlipped,
    required this.onFlip,
    required this.onPrev,
    required this.onNext,
    required this.onDelete,
    this.onAddCard,
    required this.onUpgrade,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          if (isAdmin && onAddCard != null)
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.add, size: 16),
                label: Text('Add Card', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.violet,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
                ),
                onPressed: onAddCard,
              ),
            ),
          const SizedBox(height: 12),
          if (locked)
            _PremiumLock(onUpgrade: onUpgrade)
          else if (flashcards.isEmpty)
            const _Empty('No flashcards created for this topic yet.')
          else ...[
            GestureDetector(
              onTap: onFlip,
              child: Container(
                width: double.infinity,
                height: 220,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.slate200),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withAlpha(15), blurRadius: 12, offset: const Offset(0, 4)),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isFlipped ? 'ANSWER (BACK)' : 'QUESTION (FRONT)',
                          style: GoogleFonts.inter(
                              fontSize: 10, fontWeight: FontWeight.w700,
                              letterSpacing: 1.2, color: AppColors.slate400),
                        ),
                        const Icon(Icons.refresh, size: 14, color: AppColors.slate400),
                      ],
                    ),
                    Text(
                      isFlipped
                          ? flashcards[activeIndex]['back']?.toString() ?? ''
                          : flashcards[activeIndex]['front']?.toString() ?? '',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.fraunces(
                          fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.navy),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Tap to flip', style: GoogleFonts.inter(fontSize: 11, color: AppColors.slate400)),
                        if (isAdmin)
                          GestureDetector(
                            onTap: () => onDelete(flashcards[activeIndex]['_id']?.toString() ?? ''),
                            child: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton(
                  onPressed: onPrev,
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
                  ),
                  child: Text('Prev', style: GoogleFonts.inter()),
                ),
                const SizedBox(width: 16),
                Text(
                  '${activeIndex + 1} of ${flashcards.length}',
                  style: GoogleFonts.jetBrainsMono(fontSize: 13, color: AppColors.navy),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: onNext,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.navy,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
                  ),
                  child: Text('Next', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// Videos Tab
class _VideosTab extends StatelessWidget {
  final List videos;
  const _VideosTab({required this.videos});

  @override
  Widget build(BuildContext context) {
    if (videos.isEmpty) return const _Empty('No video lessons available for this topic.');
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: videos.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) {
        final v = videos[i];
        return Container(
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.slate100),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 140,
                decoration: const BoxDecoration(
                  color: AppColors.navy,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Icon(Icons.play_circle_outline, size: 48, color: Colors.white),
                    if (v['premium_only'] == true)
                      Positioned(
                        top: 8, right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.lock, size: 10, color: Colors.white),
                              const SizedBox(width: 2),
                              Text('Premium', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white)),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(v['title'] ?? '',
                        style: GoogleFonts.fraunces(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.navy),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    if ((v['description'] as String?)?.isNotEmpty == true) ...[
                      const SizedBox(height: 4),
                      Text(v['description'] ?? '',
                          style: GoogleFonts.inter(fontSize: 12, color: AppColors.slate500),
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// Tests Tab
class _TestsTab extends StatelessWidget {
  final List tests;
  final bool isPremium;
  const _TestsTab({required this.tests, required this.isPremium});

  @override
  Widget build(BuildContext context) {
    if (tests.isEmpty) return const _Empty('No mock tests published for this subject.');
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: tests.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) {
        final t = tests[i];
        final isPremiumTest = t['premium_only'] == true;
        final locked = isPremiumTest && !isPremium;
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.slate100),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.blue.withAlpha(20),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      '${t['test_type'] ?? ''} Test'.toUpperCase(),
                      style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1, color: AppColors.blue),
                    ),
                  ),
                  if (isPremiumTest) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text('Premium',
                          style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white)),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Text(t['title'] ?? '',
                  style: GoogleFonts.fraunces(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.navy)),
              if ((t['description'] as String?)?.isNotEmpty == true) ...[
                const SizedBox(height: 4),
                Text(t['description'] ?? '',
                    style: GoogleFonts.inter(fontSize: 12, color: AppColors.slate500),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Text('Duration: ${t['duration_minutes'] ?? '—'}m',
                      style: GoogleFonts.inter(fontSize: 11, color: AppColors.slate400)),
                  const SizedBox(width: 16),
                  Text('Questions: ${(t['question_ids'] as List?)?.length ?? 0}',
                      style: GoogleFonts.inter(fontSize: 11, color: AppColors.slate400)),
                ],
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: locked
                      ? () => showToast(context, 'Premium upgrade required to unlock tests.', isError: true)
                      : () => context.push('/tests/${t['_id']}/live'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: locked ? const Color(0xFFF59E0B) : AppColors.navy,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  child: locked
                      ? Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.lock, size: 12),
                          const SizedBox(width: 4),
                          Text('Locked', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                        ])
                      : Text('Start Test', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// Doubts Tab
class _DoubtsTab extends StatelessWidget {
  final List discussions;
  final String userId;
  final bool isAdmin;
  final Function(String) onViewThread;
  final Function(String) onDeleteThread;
  final VoidCallback onAskDoubt;

  const _DoubtsTab({
    required this.discussions,
    required this.userId,
    required this.isAdmin,
    required this.onViewThread,
    required this.onDeleteThread,
    required this.onAskDoubt,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Doubts Discussion Board',
                  style: GoogleFonts.fraunces(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.navy)),
              ElevatedButton.icon(
                icon: const Icon(Icons.add, size: 14),
                label: Text('Ask', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.violet,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
                onPressed: onAskDoubt,
              ),
            ],
          ),
        ),
        Expanded(
          child: discussions.isEmpty
              ? const _Empty('No doubts posted yet. Be the first to ask!')
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: discussions.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final t = discussions[i];
                    final isOwn = t['user_id']?.toString() == userId;
                    return GestureDetector(
                      onTap: () => onViewThread(t['_id']?.toString() ?? ''),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.slate100),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(t['title'] ?? '',
                                      style: GoogleFonts.fraunces(
                                          fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.navy)),
                                  const SizedBox(height: 4),
                                  Text(t['body'] ?? '',
                                      style: GoogleFonts.inter(fontSize: 12, color: AppColors.slate600),
                                      maxLines: 2, overflow: TextOverflow.ellipsis),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Text('${t['user_name'] ?? ''} (${t['user_role'] ?? ''})',
                                          style: GoogleFonts.inter(fontSize: 10, color: AppColors.slate400)),
                                      const SizedBox(width: 8),
                                      Text('Replies: ${t['replies_count'] ?? 0}',
                                          style: GoogleFonts.inter(fontSize: 10, color: AppColors.slate400)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            if (isOwn || isAdmin)
                              GestureDetector(
                                onTap: () => onDeleteThread(t['_id']?.toString() ?? ''),
                                child: const Padding(
                                  padding: EdgeInsets.only(left: 8),
                                  child: Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _Empty extends StatelessWidget {
  final String msg;
  const _Empty(this.msg);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.slate50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.slate200),
        ),
        child: Text(msg,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 14, color: AppColors.slate500)),
      ),
    );
  }
}

class _PremiumLock extends StatelessWidget {
  final VoidCallback onUpgrade;
  const _PremiumLock({required this.onUpgrade});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.slate50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.slate200),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48, height: 48,
            decoration: const BoxDecoration(
              color: Color(0xFFFEF3C7),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.lock_outline, size: 22, color: Color(0xFFF59E0B)),
          ),
          const SizedBox(height: 12),
          Text('Premium Content Locked',
              style: GoogleFonts.fraunces(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.navy)),
          const SizedBox(height: 8),
          Text(
            'This content is exclusively available for premium members. Upgrade to StudyBook Premium to access it.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 13, color: AppColors.slate500),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onUpgrade,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.navy,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            ),
            child: Text('View Premium Plans',
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
