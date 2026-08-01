import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/api/api_endpoints.dart';
import '../../../core/api/dio_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../common/widgets/app_drawer.dart';
import '../../common/widgets/shared_widgets.dart';

class ManageVideosScreen extends ConsumerStatefulWidget {
  const ManageVideosScreen({super.key});

  @override
  ConsumerState<ManageVideosScreen> createState() => _ManageVideosScreenState();
}

class _ManageVideosScreenState extends ConsumerState<ManageVideosScreen> {
  List _videos = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await dioClient.get(ApiEndpoints.videos);
      if (mounted) {
        setState(() {
          _videos = r.data['items'] ?? [];
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        showToast(context, formatApiError(e), isError: true);
      }
    }
  }

  Future<void> _deleteVideo(String id) async {
    try {
      await dioClient.delete(ApiEndpoints.videoDetail(id));
      if (!mounted) return;
      showToast(context, 'Video deleted');
      _load();
    } catch (e) {
      if (!mounted) return;
      showToast(context, formatApiError(e), isError: true);
    }
  }

  void _showCreateDialog() {
    final titleCtrl = TextEditingController();
    final urlCtrl = TextEditingController();
    final topicCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String classLevel = '10';
    bool premiumOnly = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Add Video Lesson', style: GoogleFonts.fraunces(fontSize: 20, fontWeight: FontWeight.w600)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Title')),
                const SizedBox(height: 8),
                TextField(controller: urlCtrl, decoration: const InputDecoration(labelText: 'Video URL (YouTube)')),
                const SizedBox(height: 8),
                TextField(controller: topicCtrl, decoration: const InputDecoration(labelText: 'Topic (e.g. Algebra)')),
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
                  onChanged: (v) => setDialogState(() => classLevel = v!),
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  title: const Text('Premium Members Only'),
                  value: premiumOnly,
                  onChanged: (v) => setDialogState(() => premiumOnly = v ?? false),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (titleCtrl.text.trim().isEmpty || urlCtrl.text.trim().isEmpty) {
                  showToast(context, 'Title and URL are required', isError: true);
                  return;
                }
                Navigator.pop(ctx);
                try {
                  final body = {
                    'title': titleCtrl.text.trim(),
                    'url': urlCtrl.text.trim(),
                    'topic': topicCtrl.text.trim(),
                    'description': descCtrl.text.trim(),
                    'subject': 'maths',
                    'class_level': classLevel,
                    'premium_only': premiumOnly,
                  };
                  await dioClient.post(ApiEndpoints.videos, data: body);
                  if (!mounted) return;
                  showToast(context, 'Video published!');
                  _load();
                } catch (e) {
                  if (!mounted) return;
                  showToast(context, formatApiError(e), isError: true);
                }
              },
              child: const Text('Publish'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MainScaffold(
      title: 'Manage Videos',
      showBack: true,
      parentRoute: '/admin',
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateDialog,
        backgroundColor: AppColors.navy,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _loading
          ? const LoadingIndicator()
          : _videos.isEmpty
              ? const EmptyState(message: 'No videos created yet.', icon: Icons.play_circle_outline)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _videos.length,
                    itemBuilder: (ctx, i) {
                      final v = _videos[i] as Map;
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
                                    color: AppColors.navy.withAlpha(20),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text('Class ${v['class_level']}', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.navy)),
                                ),
                                if (v['premium_only'] == true) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.warning,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text('PREMIUM', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
                                  ),
                                ],
                                const Spacer(),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                                  onPressed: () => _deleteVideo(v['_id']),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(v['title'] ?? '', style: GoogleFonts.fraunces(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.navy)),
                            if (v['description'] != null)
                              Text(v['description'], style: GoogleFonts.inter(fontSize: 12, color: AppColors.slate500)),
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
