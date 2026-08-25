import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api/api_endpoints.dart';
import '../../../core/api/dio_client.dart';
import '../../../core/config/app_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../../common/widgets/app_drawer.dart';
import '../../common/widgets/shared_widgets.dart';
import 'widgets/video_card.dart';
import 'widgets/video_skeleton_loader.dart';

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
    final user = ref.read(authProvider).user;
    final bool isPremium = user?.isAdmin == true || (user?.subscriptionActive ?? false);
    final bool isLocked = (v['premium_only'] == true) && !isPremium;
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

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final bool isPremium = user?.isAdmin == true || (user?.subscriptionActive ?? false);

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
                        borderRadius: BorderRadius.circular(99),
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
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(99)),
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
                ? const VideoSkeletonLoader()
                : _items.isEmpty
                    ? const EmptyState(message: 'No videos yet. Admin will drop lessons soon.', icon: Icons.play_circle_outline)
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _items.length,
                          itemBuilder: (ctx, i) {
                            final v = _items[i] as Map;
                            final bool isLocked = (v['premium_only'] == true) && !isPremium;
                            return VideoCard(
                              video: v,
                              isLocked: isLocked,
                              onTap: () => _openVideo(v),
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
