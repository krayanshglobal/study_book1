import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api/api_endpoints.dart';
import '../../../core/api/dio_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../../common/widgets/app_drawer.dart';
import '../../common/widgets/shared_widgets.dart';

class VideosScreen extends ConsumerStatefulWidget {
  const VideosScreen({super.key});

  @override
  ConsumerState<VideosScreen> createState() => _VideosScreenState();
}

class _VideosScreenState extends ConsumerState<VideosScreen> {
  List _items = [];
  bool _loading = true;
  String _classLevel = 'all';

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).user;
    // Auto-filter to student's assigned class
    if (user != null && !user.isAdmin && user.classLevel != null) {
      _classLevel = user.classLevel!;
    }
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final params = <String, dynamic>{};
      if (_classLevel != 'all') params['class_level'] = _classLevel;
      final r = await dioClient.get(ApiEndpoints.videos, queryParameters: params);
      if (mounted) {
        setState(() {
          _items = r.data['items'] ?? [];
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

  void _openVideo(Map v) async {
    final urlStr = v['url'] as String? ?? '';
    final uri = Uri.parse(urlStr);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) showToast(context, 'Could not launch video URL', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;

    return MainScaffold(
      title: 'Video Lessons',
      body: Column(
        children: [
          // Class selector — read-only pill for students, dropdown for admins
          Builder(builder: (context) {
            final isStudent = user != null && !user.isAdmin;
            if (isStudent) {
              return Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                color: AppColors.white,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                            _classLevel == 'all' ? 'All Classes' : 'Class $_classLevel',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.blue,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }
            return Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              color: AppColors.white,
              child: Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _classLevel,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        isDense: true,
                      ),
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('All classes')),
                        DropdownMenuItem(value: '8', child: Text('Class 8')),
                        DropdownMenuItem(value: '9', child: Text('Class 9')),
                        DropdownMenuItem(value: '10', child: Text('Class 10')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _classLevel = val);
                          _load();
                        }
                      },
                    ),
                  ),
                ],
              ),
            );
          }),
          const Divider(height: 1, color: AppColors.slate200),
          Expanded(
            child: _loading
                ? const LoadingIndicator()
                : _items.isEmpty
                    ? const EmptyState(message: 'No videos yet. Admin will drop lessons soon.', icon: Icons.play_circle_outline)
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _items.length,
                          itemBuilder: (ctx, i) {
                            final v = _items[i] as Map;
                            final bool premiumOnly = v['premium_only'] == true;
                            final bool isLocked = premiumOnly && !(user?.subscriptionActive ?? false);
                            final thumbUrl = v['thumbnail_url'] ?? 'https://images.unsplash.com/photo-1509228468518-180dd4864904';

                            return GestureDetector(
                              onTap: () {
                                if (isLocked) {
                                  showToast(context, 'Premium subscription required to unlock this video', isError: true);
                                } else {
                                  _openVideo(v);
                                }
                              },
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                  color: AppColors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: AppColors.slate200),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Stack(
                                      children: [
                                        AspectRatio(
                                          aspectRatio: 16 / 9,
                                          child: Image.network(
                                            thumbUrl,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => Container(color: AppColors.slate100),
                                          ),
                                        ),
                                        Positioned.fill(
                                          child: Container(
                                            color: Colors.black26,
                                            child: Center(
                                              child: Icon(
                                                isLocked ? Icons.lock_outlined : Icons.play_circle_fill,
                                                size: 54,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ),
                                        if (premiumOnly)
                                          Positioned(
                                            top: 12,
                                            left: 12,
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: AppColors.warning,
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text('PREMIUM',
                                                  style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
                                            ),
                                          ),
                                      ],
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Class ${v['class_level']} · ${v['topic'] ?? 'General'}'.toUpperCase(),
                                            style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: AppColors.violet),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            v['title'] ?? '',
                                            style: GoogleFonts.fraunces(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.navy),
                                          ),
                                          if (v['description'] != null && (v['description'] as String).isNotEmpty) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              v['description'],
                                              style: GoogleFonts.inter(fontSize: 13, color: AppColors.slate500),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
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
