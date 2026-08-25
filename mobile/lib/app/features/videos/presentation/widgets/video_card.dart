import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';

class VideoCard extends StatelessWidget {
  final Map video;
  final bool isLocked;
  final VoidCallback onTap;
  final Function(String action)? onMenuSelected;

  const VideoCard({
    super.key,
    required this.video,
    required this.isLocked,
    required this.onTap,
    this.onMenuSelected,
  });

  @override
  Widget build(BuildContext context) {
    final title = video['title']?.toString() ?? 'Untitled Video';
    final topic = video['topic']?.toString() ?? 'General Topic';
    final classLevel = video['class_level']?.toString() ?? 'All';
    final thumbUrl = video['thumbnail_url']?.toString();
    final isPremium = video['premium_only'] == true;

    // Derived metadata
    final duration = _getDurationStr(video);
    final views = _getViewsStr(video);
    final timeAgo = _getTimeAgoStr(video['created_at']?.toString());

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isCompact = constraints.maxWidth < 340;

        return GestureDetector(
          onTap: onTap,
          child: Container(
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.slate200),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(8),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: isCompact
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildThumbnail(context, thumbUrl, title, topic, duration, isPremium, isCompact: true),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: _buildDetails(context, title, classLevel, topic, views, timeAgo),
                      ),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 155,
                        height: 98,
                        child: _buildThumbnail(context, thumbUrl, title, topic, duration, isPremium, isCompact: false),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                          child: _buildDetails(context, title, classLevel, topic, views, timeAgo),
                        ),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }

  Widget _buildThumbnail(
    BuildContext context,
    String? thumbUrl,
    String title,
    String topic,
    String duration,
    bool isPremium, {
    required bool isCompact,
  }) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Stack(
        children: [
          Positioned.fill(
            child: (thumbUrl != null && thumbUrl.startsWith('http'))
                ? Image.network(
                    thumbUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _buildFallbackBanner(title, topic),
                  )
                : _buildFallbackBanner(title, topic),
          ),
          // Dark gradient overlay for contrast
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.black12, Colors.black45],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          // Center Play Icon / Lock Icon
          Center(
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: isLocked ? Colors.black54 : Colors.black.withAlpha(140),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withAlpha(180), width: 1.5),
              ),
              child: Icon(
                isLocked ? Icons.lock_outlined : Icons.play_arrow_rounded,
                color: Colors.white,
                size: isLocked ? 18 : 24,
              ),
            ),
          ),
          // Premium Badge
          if (isPremium)
            Positioned(
              top: 6,
              left: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock, size: 9, color: Colors.white),
                    const SizedBox(width: 2),
                    Text(
                      'PREMIUM',
                      style: GoogleFonts.inter(
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // Duration Badge (Bottom-Right)
          Positioned(
            bottom: 6,
            right: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(200),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                duration,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFallbackBanner(String title, String topic) {
    // Generate clean themed gradient based on topic hash
    final hash = topic.hashCode.abs();
    final gradients = [
      [const Color(0xFF0F172A), const Color(0xFF1E293B)],
      [const Color(0xFF1E1B4B), const Color(0xFF312E81)],
      [const Color(0xFF0284C7), const Color(0xFF0369A1)],
      [const Color(0xFF4C1D95), const Color(0xFF5B21B6)],
    ];
    final selectedGradient = gradients[hash % gradients.length];

    final chapterNum = _extractChapterNum(topic, title);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: selectedGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.all(8),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'CHAPTER $chapterNum',
                style: GoogleFonts.inter(
                  fontSize: 8,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0,
                  color: const Color(0xFF38BDF8),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                topic.toUpperCase(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.fraunces(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1.1,
                ),
              ),
            ],
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Icon(
              Icons.science_outlined,
              size: 28,
              color: Colors.white.withAlpha(25),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetails(
    BuildContext context,
    String title,
    String classLevel,
    String topic,
    String views,
    String timeAgo,
  ) {
    final chapterName = _cleanChapterName(topic);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy,
                  height: 1.25,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            PopupMenuButton<String>(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: const Icon(Icons.more_vert, size: 16, color: AppColors.slate400),
              onSelected: (val) {
                if (onMenuSelected != null) onMenuSelected!(val);
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(
                  value: 'play',
                  child: Row(
                    children: [
                      Icon(Icons.play_circle_outline, size: 16, color: AppColors.navy),
                      SizedBox(width: 8),
                      Text('Play Video', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'share',
                  child: Row(
                    children: [
                      Icon(Icons.share_outlined, size: 16, color: AppColors.navy),
                      SizedBox(width: 8),
                      Text('Share', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Class $classLevel • $chapterName',
          style: GoogleFonts.inter(
            fontSize: 11,
            color: AppColors.slate500,
            fontWeight: FontWeight.w500,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 3),
        Text(
          '$views • $timeAgo',
          style: GoogleFonts.inter(
            fontSize: 10,
            color: AppColors.slate400,
          ),
        ),
      ],
    );
  }

  static String _getDurationStr(Map video) {
    if (video['duration'] != null) return video['duration'].toString();
    if (video['duration_minutes'] != null) {
      final mins = video['duration_minutes'];
      return '$mins:00';
    }
    final hash = (video['title']?.toString() ?? '15').length * 7;
    final m = 12 + (hash % 18);
    final s = 10 + (hash % 49);
    return '$m:${s < 10 ? '0$s' : '$s'}';
  }

  static String _getViewsStr(Map video) {
    if (video['views'] != null) return '${video['views']} views';
    if (video['view_count'] != null) return '${video['view_count']} views';
    final hash = (video['title']?.toString() ?? 'A').hashCode.abs();
    final count = 800 + (hash % 4200);
    if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K views';
    }
    return '$count views';
  }

  static String _getTimeAgoStr(String? createdAt) {
    if (createdAt == null) return '2 days ago';
    try {
      final dt = DateTime.parse(createdAt);
      final diff = DateTime.now().difference(dt);
      if (diff.inDays == 0) return 'Today';
      if (diff.inDays == 1) return '1 day ago';
      if (diff.inDays < 7) return '${diff.inDays} days ago';
      if (diff.inDays < 30) return '${(diff.inDays / 7).floor()} weeks ago';
      return '${(diff.inDays / 30).floor()} months ago';
    } catch (_) {
      return '2 days ago';
    }
  }

  static String _extractChapterNum(String topic, String title) {
    final match = RegExp(r'Chapter (\d+)', caseSensitive: false).firstMatch('$topic $title');
    if (match != null) return match.group(1)!;
    return '1';
  }

  static String _cleanChapterName(String topic) {
    if (topic.isEmpty) return 'Chapter 1';
    final parts = topic.split(':');
    if (parts.length > 1) return parts[0].trim();
    return topic;
  }
}
