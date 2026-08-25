import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class VideoSkeletonLoader extends StatefulWidget {
  const VideoSkeletonLoader({super.key});

  @override
  State<VideoSkeletonLoader> createState() => _VideoSkeletonLoaderState();
}

class _VideoSkeletonLoaderState extends State<VideoSkeletonLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final alpha = (60 + (_controller.value * 90)).round();
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: 4,
          itemBuilder: (ctx, i) {
            return Container(
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.slate200),
              ),
              child: Row(
                children: [
                  // Skeleton Thumbnail
                  Container(
                    width: 155,
                    height: 98,
                    decoration: BoxDecoration(
                      color: AppColors.slate200.withAlpha(alpha),
                      borderRadius: const BorderRadius.horizontal(left: Radius.circular(15)),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title line 1
                          Container(
                            height: 14,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: AppColors.slate200.withAlpha(alpha),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(height: 6),
                          // Title line 2
                          Container(
                            height: 14,
                            width: 120,
                            decoration: BoxDecoration(
                              color: AppColors.slate200.withAlpha(alpha),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(height: 10),
                          // Meta line 1
                          Container(
                            height: 10,
                            width: 90,
                            decoration: BoxDecoration(
                              color: AppColors.slate200.withAlpha(alpha),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(height: 6),
                          // Meta line 2
                          Container(
                            height: 10,
                            width: 70,
                            decoration: BoxDecoration(
                              color: AppColors.slate200.withAlpha(alpha),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
