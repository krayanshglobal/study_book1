import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/api/api_endpoints.dart';
import '../../../core/api/dio_client.dart';
import '../../../core/models/test_model.dart';
import '../../../core/theme/app_colors.dart';
import '../../common/widgets/app_drawer.dart';
import '../../common/widgets/shared_widgets.dart';

class ManageTestsScreen extends ConsumerStatefulWidget {
  const ManageTestsScreen({super.key});

  @override
  ConsumerState<ManageTestsScreen> createState() => _ManageTestsScreenState();
}

class _ManageTestsScreenState extends ConsumerState<ManageTestsScreen> {
  List<TestModel> _tests = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await dioClient.get(ApiEndpoints.tests);
      final list = (r.data['items'] as List).map((e) => TestModel.fromJson(e)).toList();
      if (mounted) setState(() { _tests = list; _loading = false; });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        showToast(context, formatApiError(e), isError: true);
      }
    }
  }

  Future<void> _togglePublish(TestModel t) async {
    try {
      await dioClient.put(ApiEndpoints.testDetail(t.id), data: {'is_published': !t.isPublished});
      if (!mounted) return;
      showToast(context, t.isPublished ? 'Test unpublished' : 'Test published!');
      _load();
    } catch (e) {
      if (!mounted) return;
      showToast(context, formatApiError(e), isError: true);
    }
  }

  Future<void> _deleteTest(String id) async {
    try {
      await dioClient.delete(ApiEndpoints.testDetail(id));
      if (!mounted) return;
      showToast(context, 'Test deleted');
      _load();
    } catch (e) {
      if (!mounted) return;
      showToast(context, formatApiError(e), isError: true);
    }
  }

  void _showCreateDialog() {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final dateCtrl = TextEditingController(text: DateTime.now().toIso8601String().substring(0, 10));
    final startTimeCtrl = TextEditingController(text: '20:00');
    final endTimeCtrl = TextEditingController(text: '21:00');
    String classLevel = '10';
    String testType = 'mock';
    bool premiumOnly = false;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Schedule Test', style: GoogleFonts.fraunces(fontSize: 20, fontWeight: FontWeight.w600)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Title')),
              const SizedBox(height: 8),
              TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Description')),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: classLevel,
                decoration: const InputDecoration(labelText: 'Class Level'),
                items: const [
                  DropdownMenuItem(value: '8', child: Text('Class 8')),
                  DropdownMenuItem(value: '9', child: Text('Class 9')),
                  DropdownMenuItem(value: '10', child: Text('Class 10')),
                ],
                onChanged: (v) => classLevel = v!,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: testType,
                decoration: const InputDecoration(labelText: 'Type'),
                items: const [
                  DropdownMenuItem(value: 'mock', child: Text('Mock Test')),
                  DropdownMenuItem(value: 'final', child: Text('Final Test')),
                ],
                onChanged: (v) => testType = v!,
              ),
              const SizedBox(height: 8),
              TextField(controller: dateCtrl, decoration: const InputDecoration(labelText: 'Date (YYYY-MM-DD)')),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: TextField(controller: startTimeCtrl, decoration: const InputDecoration(labelText: 'Start Time (UTC)'))),
                  const SizedBox(width: 8),
                  Expanded(child: TextField(controller: endTimeCtrl, decoration: const InputDecoration(labelText: 'End Time (UTC)'))),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (titleCtrl.text.trim().isEmpty) {
                showToast(context, 'Title is required', isError: true);
                return;
              }
              Navigator.pop(ctx);
              try {
                if (!context.mounted) return;
                final body = {
                  'title': titleCtrl.text.trim(),
                  'description': descCtrl.text.trim(),
                  'class_level': classLevel,
                  'test_type': testType,
                  'scheduled_date': dateCtrl.text.trim(),
                  'start_time': startTimeCtrl.text.trim(),
                  'end_time': endTimeCtrl.text.trim(),
                  'duration_minutes': 60,
                  'negative_marking': true,
                  'is_published': true,
                  'premium_only': premiumOnly,
                  'question_ids': <String>[],
                };
                await dioClient.post(ApiEndpoints.tests, data: body);
                if (!mounted) return;
                showToast(context, 'Test scheduled!');
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return MainScaffold(
      title: 'Manage Tests',
      showBack: true,
      parentRoute: '/admin',
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateDialog,
        backgroundColor: AppColors.navy,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _loading
          ? const LoadingIndicator()
          : _tests.isEmpty
              ? const EmptyState(message: 'No tests created yet.', icon: Icons.assignment_outlined)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _tests.length,
                    itemBuilder: (ctx, i) {
                      final t = _tests[i];
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
                                    color: t.testType == 'final' ? AppColors.violet : AppColors.blue.withAlpha(20),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(t.testType.toUpperCase(),
                                      style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: t.testType == 'final' ? Colors.white : AppColors.blue)),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: t.isPublished ? AppColors.success.withAlpha(20) : AppColors.slate200,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(t.isPublished ? 'PUBLISHED' : 'DRAFT',
                                      style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: t.isPublished ? AppColors.success : AppColors.slate600)),
                                ),
                                const Spacer(),
                                Switch(
                                  value: t.isPublished,
                                  onChanged: (_) => _togglePublish(t),
                                  activeThumbColor: AppColors.violet,
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                                  onPressed: () => _deleteTest(t.id),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(t.title, style: GoogleFonts.fraunces(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.navy)),
                            Text('Class ${t.classLevel} • ${t.scheduledDate} (${t.startTime}-${t.endTime} UTC)',
                                style: GoogleFonts.inter(fontSize: 12, color: AppColors.slate500)),
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
