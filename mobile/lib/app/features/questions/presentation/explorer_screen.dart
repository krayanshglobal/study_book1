import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:url_launcher/url_launcher.dart';

import '../../../core/api/api_endpoints.dart';
import '../../../core/api/dio_client.dart';
import '../../../core/config/app_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../../common/widgets/app_drawer.dart';
import '../../common/widgets/shared_widgets.dart';
import '../../videos/presentation/widgets/video_card.dart';

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
  String? _selectedTopic; // null = "All Topics"
  DateTime? _selectedDate; // null = "Select Date"
  final _searchController = TextEditingController();
  String _searchQuery = '';
  List<Map> _topics = [];

  // Raw Content
  List _rawNotes = [];
  List _rawVideos = [];
  List _rawTests = [];
  List _rawDiscussions = [];
  List _rawFlashcards = [];
  bool _flashcardsLocked = false;

  // Filtered Content
  List _filteredNotes = [];
  List _filteredVideos = [];
  List _filteredTests = [];
  List _filteredDiscussions = [];
  List _filteredFlashcards = [];

  // Flashcard state
  int _activeCardIndex = 0;
  bool _isFlipped = false;

  // Discussion thread
  Map? _activeThread;
  List _threadReplies = [];
  final _replyController = TextEditingController();

  bool _loading = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadTopics();
    _fetchData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
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

  Future<void> _loadTopics() async {
    try {
      final r = await dioClient.get(
        ApiEndpoints.topics,
        queryParameters: {'class_level': _classLevel},
      );
      if (mounted) {
        final topicList = List<Map>.from(r.data['topics'] ?? []);
        setState(() {
          _topics = topicList;
        });
      }
    } catch (e) {
      debugPrint('Study Explorer: Failed to load topics: $e');
    }
  }

  Future<void> _fetchData() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _hasError = false;
    });

    final cl = _classLevel;
    debugPrint('==================================================');
    debugPrint('=== STUDY EXPLORER DEBUG LOG ===');
    debugPrint('Logged-in User Class: $cl');
    debugPrint('Selected Topic: $_selectedTopic');
    debugPrint('Selected Date: $_selectedDate');
    debugPrint('Search Query: "$_searchQuery"');

    try {
      final results = await Future.wait([
        dioClient.get(ApiEndpoints.notes, queryParameters: {'class_level': cl}),
        dioClient.get(ApiEndpoints.videos, queryParameters: {'class_level': cl}),
        dioClient.get(ApiEndpoints.tests, queryParameters: {'class_level': cl}),
        dioClient.get(ApiEndpoints.discussions, queryParameters: {'class_level': cl}),
        dioClient.get(ApiEndpoints.flashcards, queryParameters: {'class_level': cl}),
        dioClient.get(ApiEndpoints.questions, queryParameters: {'class_level': cl, 'limit': 100}),
      ]);

      debugPrint('GET ${ApiEndpoints.notes} Status: ${results[0].statusCode}, Records: ${(results[0].data['items'] as List?)?.length}');
      debugPrint('GET ${ApiEndpoints.videos} Status: ${results[1].statusCode}, Records: ${(results[1].data['items'] as List?)?.length}');
      debugPrint('GET ${ApiEndpoints.tests} Status: ${results[2].statusCode}, Records: ${(results[2].data['items'] as List?)?.length}');
      debugPrint('GET ${ApiEndpoints.discussions} Status: ${results[3].statusCode}, Records: ${(results[3].data['items'] as List?)?.length}');
      debugPrint('GET ${ApiEndpoints.flashcards} Status: ${results[4].statusCode}, Records: ${(results[4].data['items'] as List?)?.length}');
      debugPrint('GET ${ApiEndpoints.questions} Status: ${results[5].statusCode}, Records: ${(results[5].data['items'] as List?)?.length}');
      debugPrint('==================================================');

      final fetchedNotes = List<Map>.from(results[0].data['items'] ?? []);
      final fetchedVideos = List<Map>.from(results[1].data['items'] ?? []);
      final fetchedTests = List<Map>.from(results[2].data['items'] ?? []);
      final fetchedDiscussions = List<Map>.from(results[3].data['items'] ?? []);
      final fetchedFlashcards = List<Map>.from(results[4].data['items'] ?? []);
      final fetchedQuestions = List<Map>.from(results[5].data['items'] ?? []);

      // Requirement 3: If notes or flashcards are empty, derive content from fetched Question Bank questions
      if (fetchedNotes.isEmpty && fetchedQuestions.isNotEmpty) {
        for (var q in fetchedQuestions) {
          final topic = q['topic']?.toString().trim() ?? 'General';
          final subject = q['subject']?.toString().trim() ?? 'maths';
          final qText = q['question_text']?.toString() ?? '';
          final exp = q['explanation']?.toString() ?? '';
          fetchedNotes.add({
            '_id': q['_id'] ?? q['id'] ?? '',
            'title': topic.isNotEmpty ? topic : 'Practice Note',
            'content': '<b>Question:</b><br/>$qText${exp.isNotEmpty ? '<br/><br/><b>Explanation:</b><br/>$exp' : ''}',
            'subject': subject,
            'class_level': q['class_level'] ?? cl,
            'topic': topic,
            'created_at': q['created_at'] ?? q['published_at'],
            'premium_only': false,
          });
        }
      }

      if (fetchedFlashcards.isEmpty && fetchedQuestions.isNotEmpty) {
        for (var q in fetchedQuestions) {
          final topic = q['topic']?.toString().trim() ?? 'General';
          final qText = q['question_text']?.toString() ?? '';
          final ans = q['correct_answer_text']?.toString() ?? q['explanation']?.toString() ?? 'Refer to study notes';
          fetchedFlashcards.add({
            '_id': q['_id'] ?? q['id'] ?? '',
            'front': qText,
            'back': ans,
            'subject': q['subject'] ?? 'maths',
            'class_level': q['class_level'] ?? cl,
            'topic': topic,
            'created_at': q['created_at'],
          });
        }
      }

      if (!mounted) return;
      setState(() {
        _rawNotes = fetchedNotes;
        _rawVideos = fetchedVideos;
        _rawTests = fetchedTests;
        _rawDiscussions = fetchedDiscussions;
        _flashcardsLocked = results[4].data['locked'] == true;
        _rawFlashcards = fetchedFlashcards;
        _loading = false;
      });
      _applyFilters();
    } catch (e) {
      debugPrint('Study Explorer: API Fetch Error: $e');
      if (mounted) {
        setState(() {
          _loading = false;
          _hasError = true;
        });
        showToast(context, 'Unable to load content.', isError: true);
      }
    }
  }

  void _applyFilters() {
    final sub = _subject.toLowerCase();
    final top = _selectedTopic?.trim().toLowerCase();
    final search = _searchQuery.trim().toLowerCase();
    final dateStr = _selectedDate != null ? DateFormat('yyyy-MM-dd').format(_selectedDate!) : null;

    bool matchTopic(dynamic item) {
      if (top == null || top.isEmpty || top == 'all topics') return true;
      final itemTopic = (item['topic'] as String? ?? '').toLowerCase().trim();
      return itemTopic == top;
    }

    bool matchDate(dynamic item) {
      if (dateStr == null) return true;
      final rawDate = item['scheduled_date'] ?? item['created_at'] ?? item['published_at'] ?? item['date'];
      if (rawDate == null) return false;
      return rawDate.toString().startsWith(dateStr);
    }

    bool matchSearch(dynamic item, List<String> fields) {
      if (search.isEmpty) return true;
      for (final f in fields) {
        final val = (item[f] as String? ?? '').toLowerCase();
        if (val.contains(search)) return true;
      }
      return false;
    }

    setState(() {
      _filteredNotes = _rawNotes.where((n) {
        final nSub = (n['subject'] as String? ?? '').toLowerCase();
        return (nSub.isEmpty || nSub == sub) &&
            matchTopic(n) &&
            matchDate(n) &&
            matchSearch(n, ['title', 'content', 'topic', 'subject', 'chapter', 'description', 'question_text']);
      }).toList();

      _filteredVideos = _rawVideos.where((v) {
        final vSub = (v['subject'] as String? ?? '').toLowerCase();
        return (vSub.isEmpty || vSub == sub) &&
            matchTopic(v) &&
            matchDate(v) &&
            matchSearch(v, ['title', 'description', 'subject', 'topic']);
      }).toList();

      _filteredTests = _rawTests.where((t) {
        final tSub = (t['subject'] as String? ?? '').toLowerCase();
        final isPub = t['is_published'] == true;
        return isPub &&
            (tSub.isEmpty || tSub == sub) &&
            matchTopic(t) &&
            matchDate(t) &&
            matchSearch(t, ['title', 'description', 'test_type', 'subject']);
      }).toList();

      _filteredDiscussions = _rawDiscussions.where((d) {
        final dSub = (d['subject'] as String? ?? '').toLowerCase();
        return (dSub.isEmpty || dSub == sub) &&
            matchTopic(d) &&
            matchDate(d) &&
            matchSearch(d, ['title', 'body', 'user_name', 'topic']);
      }).toList();

      _filteredFlashcards = _rawFlashcards.where((f) {
        final fSub = (f['subject'] as String? ?? '').toLowerCase();
        return (fSub.isEmpty || fSub == sub) &&
            matchTopic(f) &&
            matchDate(f) &&
            matchSearch(f, ['front', 'back', 'topic']);
      }).toList();

      _activeCardIndex = 0;
      _isFlipped = false;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      _applyFilters();
    }
  }

  void _openVideo(Map v) async {
    final bool isLocked = (v['premium_only'] == true) && !_isPremium;
    if (isLocked) {
      showToast(context, 'Premium subscription required to unlock this video', isError: true);
      return;
    }

    String rawUrl = (v['url'] ?? v['video_url'] ?? v['videoUrl'] ?? v['youtube_url'] ?? v['videoLink'] ?? '').toString().trim();

    debugPrint('==================================================');
    debugPrint('=== VIDEO LAUNCH DEBUG LOG ===');
    debugPrint('VIDEO TITLE: ${v['title']}');
    debugPrint('RAW VIDEO URL: "$rawUrl"');

    if (rawUrl.isEmpty) {
      debugPrint('ERROR: Video URL is null or empty');
      showToast(context, 'Video is currently unavailable.', isError: true);
      return;
    }

    if (rawUrl.startsWith('/')) {
      rawUrl = '${AppConfig.baseUrl}$rawUrl';
      debugPrint('RESOLVED RELATIVE URL: "$rawUrl"');
    }

    final uri = Uri.tryParse(rawUrl);
    debugPrint('PARSED URI: $uri');

    if (uri == null || !uri.hasScheme || !(uri.scheme == 'http' || uri.scheme == 'https')) {
      debugPrint('ERROR: Invalid URI or scheme: ${uri?.scheme}');
      showToast(context, 'Video link is invalid.', isError: true);
      return;
    }

    try {
      bool launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        debugPrint('LaunchMode.externalApplication returned false, trying LaunchMode.platformDefault...');
        launched = await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
      if (!launched) {
        if (mounted) showToast(context, 'Unable to open this video. Please try again.', isError: true);
      }
    } catch (e) {
      debugPrint('Video Launch Exception: $e');
      try {
        final fallbackLaunched = await launchUrl(uri, mode: LaunchMode.platformDefault);
        if (!fallbackLaunched && mounted) {
          showToast(context, 'Unable to open this video. Please try again.', isError: true);
        }
      } catch (_) {
        if (mounted) showToast(context, 'Unable to open this video. Please try again.', isError: true);
      }
    }
  }

  void _resetFilters() {
    setState(() {
      _selectedTopic = null;
      _selectedDate = null;
      _searchController.clear();
      _searchQuery = '';
    });
    _applyFilters();
  }

  String _getEmptyMessage(String contentType) {
    if (_searchQuery.trim().isNotEmpty) {
      return "No results found for '${_searchController.text.trim()}'.";
    }
    if (_selectedTopic != null && _selectedTopic!.isNotEmpty && _selectedTopic != 'All Topics') {
      return "No $contentType found for $_selectedTopic.";
    }
    if (_selectedDate != null) {
      final formattedDate = DateFormat('dd MMM yyyy').format(_selectedDate!);
      return "No $contentType found for $formattedDate.";
    }
    switch (contentType) {
      case 'notes':
        return 'No study notes available.';
      case 'flashcards':
        return 'No flashcards created for this topic yet.';
      case 'video lessons':
        return 'No video lessons available for this topic.';
      case 'mock tests':
        return 'No mock tests published for this subject.';
      case 'doubts':
        return 'No doubts posted yet. Be the first to ask!';
      default:
        return 'No content available.';
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
                  'topic': _selectedTopic ?? '',
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
                  'topic': _selectedTopic ?? '',
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
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            color: AppColors.white,
            child: Column(
              children: [
                Row(
                  children: [
                    // Date selector button
                    Expanded(
                      flex: 4,
                      child: InkWell(
                        onTap: _pickDate,
                        borderRadius: BorderRadius.circular(99),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(99),
                            border: Border.all(
                              color: _selectedDate != null ? AppColors.blue : AppColors.slate200,
                              width: _selectedDate != null ? 1.5 : 1.0,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.calendar_today,
                                  size: 14,
                                  color: _selectedDate != null ? AppColors.blue : AppColors.slate400),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  _selectedDate != null
                                      ? DateFormat('dd MMM yyyy').format(_selectedDate!)
                                      : 'Select Date',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: _selectedDate != null ? AppColors.navy : AppColors.slate500,
                                    fontWeight: _selectedDate != null ? FontWeight.w600 : FontWeight.normal,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (_selectedDate != null)
                                GestureDetector(
                                  onTap: () {
                                    setState(() => _selectedDate = null);
                                    _applyFilters();
                                  },
                                  child: const Icon(Icons.close, size: 14, color: AppColors.slate500),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Topic selector dropdown
                    Expanded(
                      flex: 5,
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedTopic,
                        isExpanded: true,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(99),
                            borderSide: const BorderSide(color: AppColors.slate200),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(99),
                            borderSide: const BorderSide(color: AppColors.slate200),
                          ),
                          isDense: true,
                        ),
                        hint: Text('All Topics',
                            style: GoogleFonts.inter(fontSize: 12, color: AppColors.slate500)),
                        items: [
                          DropdownMenuItem<String>(
                            value: null,
                            child: Text('All Topics',
                                style: GoogleFonts.inter(fontSize: 12, color: AppColors.navy)),
                          ),
                          ..._topics.map((t) {
                            final topicName = t['topic'] as String;
                            return DropdownMenuItem<String>(
                              value: topicName,
                              child: Text(topicName,
                                  style: GoogleFonts.inter(fontSize: 12, color: AppColors.navy),
                                  overflow: TextOverflow.ellipsis),
                            );
                          }),
                        ],
                        onChanged: (v) {
                          setState(() => _selectedTopic = v);
                          _applyFilters();
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        style: GoogleFonts.inter(fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Search topic, title or keyword…',
                          hintStyle: GoogleFonts.inter(fontSize: 12, color: AppColors.slate400),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.navy),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 16, color: AppColors.slate400),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                    _applyFilters();
                                  },
                                )
                              : null,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(99),
                            borderSide: const BorderSide(color: AppColors.slate200),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(99),
                            borderSide: const BorderSide(color: AppColors.slate200),
                          ),
                        ),
                        onChanged: (val) {
                          setState(() => _searchQuery = val);
                          _applyFilters();
                        },
                        onSubmitted: (val) {
                          setState(() => _searchQuery = val);
                          _applyFilters();
                        },
                        textInputAction: TextInputAction.search,
                      ),
                    ),
                    if (_selectedTopic != null || _selectedDate != null || _searchQuery.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: _resetFilters,
                        icon: const Icon(Icons.restart_alt, size: 16, color: AppColors.slate600),
                        label: Text('Clear', style: GoogleFonts.inter(fontSize: 12, color: AppColors.slate600)),
                      ),
                    ],
                  ],
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
                : _hasError
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline, size: 44, color: AppColors.error),
                            const SizedBox(height: 12),
                            Text('Unable to load content.',
                                style: GoogleFonts.inter(fontSize: 14, color: AppColors.slate700)),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () {
                                _loadTopics();
                                _fetchData();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.navy,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
                              ),
                              child: Text('Retry', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                      )
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _NotesTab(notes: _filteredNotes, emptyMessage: _getEmptyMessage('notes'), onTap: _showNoteDialog),
                          _FlashcardsTab(
                            flashcards: _filteredFlashcards,
                            emptyMessage: _getEmptyMessage('flashcards'),
                            locked: _flashcardsLocked,
                            isPremium: _isPremium,
                            isAdmin: _isAdmin,
                            activeIndex: _activeCardIndex,
                            isFlipped: _isFlipped,
                            onFlip: () => setState(() => _isFlipped = !_isFlipped),
                            onPrev: () => setState(() {
                              _isFlipped = false;
                              _activeCardIndex = (_activeCardIndex - 1 + _filteredFlashcards.length) % _filteredFlashcards.length;
                            }),
                            onNext: () => setState(() {
                              _isFlipped = false;
                              _activeCardIndex = (_activeCardIndex + 1) % _filteredFlashcards.length;
                            }),
                            onDelete: (fid) => _deleteFlashcard(fid),
                            onAddCard: _isAdmin ? _showAddFlashcardDialog : null,
                            onUpgrade: () => context.push('/pricing'),
                          ),
                          _VideosTab(
                            videos: _filteredVideos,
                            emptyMessage: _getEmptyMessage('video lessons'),
                            isPremium: _isPremium,
                            isAdmin: _isAdmin,
                            userClass: _classLevel,
                            onOpenVideo: (v) => _openVideo(v),
                            onResetFilters: _resetFilters,
                          ),
                          _TestsTab(tests: _filteredTests, emptyMessage: _getEmptyMessage('mock tests'), isPremium: _isPremium),
                          _DoubtsTab(
                            discussions: _filteredDiscussions,
                            emptyMessage: _getEmptyMessage('doubts'),
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
  final String emptyMessage;
  final Function(Map) onTap;
  const _NotesTab({required this.notes, required this.emptyMessage, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (notes.isEmpty) {
      return _Empty(emptyMessage);
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
  final String emptyMessage;
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
    required this.emptyMessage,
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
            _Empty(emptyMessage)
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
class _VideosTab extends StatefulWidget {
  final List videos;
  final String emptyMessage;
  final bool isPremium;
  final bool isAdmin;
  final String userClass;
  final Function(Map) onOpenVideo;
  final VoidCallback onResetFilters;

  const _VideosTab({
    required this.videos,
    required this.emptyMessage,
    required this.isPremium,
    required this.isAdmin,
    required this.userClass,
    required this.onOpenVideo,
    required this.onResetFilters,
  });

  @override
  State<_VideosTab> createState() => _VideosTabState();
}

class _VideosTabState extends State<_VideosTab> {
  String? _selectedChapter;
  String _sortOption = 'Latest';

  @override
  Widget build(BuildContext context) {
    // Collect distinct chapters from videos
    final chapters = <String>{};
    for (var v in widget.videos) {
      final topic = v['topic']?.toString().trim();
      if (topic != null && topic.isNotEmpty) {
        chapters.add(topic);
      }
    }

    // Apply secondary chapter filter
    List filtered = widget.videos.where((v) {
      if (_selectedChapter != null && _selectedChapter!.isNotEmpty && _selectedChapter != 'All Chapters') {
        final top = v['topic']?.toString().trim() ?? '';
        if (top != _selectedChapter) return false;
      }
      return true;
    }).toList();

    // Sorting
    filtered.sort((a, b) {
      if (_sortOption == 'Oldest') {
        final dA = a['created_at']?.toString() ?? '';
        final dB = b['created_at']?.toString() ?? '';
        return dA.compareTo(dB);
      } else if (_sortOption == 'Alphabetical') {
        final tA = a['title']?.toString() ?? '';
        final tB = b['title']?.toString() ?? '';
        return tA.compareTo(tB);
      } else if (_sortOption == 'Most Viewed') {
        final vA = (a['views'] ?? a['view_count'] ?? 0) as num;
        final vB = (b['views'] ?? b['view_count'] ?? 0) as num;
        return vB.compareTo(vA);
      } else {
        // Latest (Default)
        final dA = a['created_at']?.toString() ?? '';
        final dB = b['created_at']?.toString() ?? '';
        return dB.compareTo(dA);
      }
    });

    return Column(
      children: [
        // Secondary Filter Bar matching reference image
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: AppColors.white,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Class selector pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.blue.withAlpha(12),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: AppColors.blue.withAlpha(50)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.school_outlined, size: 14, color: AppColors.blue),
                      const SizedBox(width: 4),
                      Text(
                        'Class ${widget.userClass}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.blue,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Chapter selector dropdown pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(
                      color: _selectedChapter != null ? AppColors.blue : AppColors.slate300,
                      width: _selectedChapter != null ? 1.5 : 1.0,
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedChapter,
                      hint: Text(
                        'All Chapters',
                        style: GoogleFonts.inter(fontSize: 12, color: AppColors.navy, fontWeight: FontWeight.w600),
                      ),
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppColors.navy),
                      isDense: true,
                      style: GoogleFonts.inter(fontSize: 12, color: AppColors.navy),
                      items: [
                        DropdownMenuItem<String>(
                          value: null,
                          child: Text('All Chapters', style: GoogleFonts.inter(fontSize: 12, color: AppColors.navy)),
                        ),
                        ...chapters.map((ch) {
                          return DropdownMenuItem<String>(
                            value: ch,
                            child: Text(
                              ch,
                              style: GoogleFonts.inter(fontSize: 12, color: AppColors.navy),
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }),
                      ],
                      onChanged: (val) {
                        setState(() => _selectedChapter = val);
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Sort option pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: AppColors.slate300),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _sortOption,
                      icon: const Icon(Icons.tune_rounded, size: 14, color: AppColors.navy),
                      isDense: true,
                      style: GoogleFonts.inter(fontSize: 12, color: AppColors.navy, fontWeight: FontWeight.w600),
                      items: const [
                        DropdownMenuItem(value: 'Latest', child: Text('Sort: Latest')),
                        DropdownMenuItem(value: 'Oldest', child: Text('Sort: Oldest')),
                        DropdownMenuItem(value: 'Most Viewed', child: Text('Sort: Most Viewed')),
                        DropdownMenuItem(value: 'Alphabetical', child: Text('Sort: A-Z')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _sortOption = val);
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 1, color: AppColors.slate200),

        // Video list or Empty state
        Expanded(
          child: filtered.isEmpty
              ? _EmptyVideos(
                  message: widget.emptyMessage,
                  onClear: () {
                    setState(() {
                      _selectedChapter = null;
                      _sortOption = 'Latest';
                    });
                    widget.onResetFilters();
                  },
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, i) {
                    final v = filtered[i];
                    final bool isLocked = (v['premium_only'] == true) && !widget.isPremium;
                    return VideoCard(
                      video: v,
                      isLocked: isLocked,
                      onTap: () => widget.onOpenVideo(v),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _EmptyVideos extends StatelessWidget {
  final String message;
  final VoidCallback onClear;

  const _EmptyVideos({
    required this.message,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.slate50,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.slate200),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.blue.withAlpha(20),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.play_circle_outline, size: 28, color: AppColors.blue),
            ),
            const SizedBox(height: 12),
            Text(
              'No Videos Found',
              style: GoogleFonts.fraunces(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.navy),
            ),
            const SizedBox(height: 6),
            Text(
              message.isNotEmpty ? message : 'Try changing your filters or search keyword.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.slate500),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onClear,
              icon: const Icon(Icons.restart_alt, size: 16),
              label: Text('Clear Filters', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.navy,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Tests Tab
class _TestsTab extends StatelessWidget {
  final List tests;
  final String emptyMessage;
  final bool isPremium;
  const _TestsTab({required this.tests, required this.emptyMessage, required this.isPremium});

  @override
  Widget build(BuildContext context) {
    if (tests.isEmpty) return _Empty(emptyMessage);
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
  final String emptyMessage;
  final String userId;
  final bool isAdmin;
  final Function(String) onViewThread;
  final Function(String) onDeleteThread;
  final VoidCallback onAskDoubt;

  const _DoubtsTab({
    required this.discussions,
    required this.emptyMessage,
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
              ? _Empty(emptyMessage)
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
