import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/models/video_model.dart';
import '../../auth/providers/auth_provider.dart';

class VideoState {
  final List<VideoModel> videos;
  final bool isLoading;
  final String? error;

  VideoState({this.videos = const [], this.isLoading = false, this.error});
}

class VideoNotifier extends StateNotifier<VideoState> {
  final Ref ref;

  VideoNotifier(this.ref) : super(VideoState(isLoading: true)) {
    loadVideos();
  }

  Future<void> loadVideos({String? classLevel}) async {
    state = VideoState(isLoading: true);
    try {
      final dio = ref.read(dioClientProvider);
      final query = <String, dynamic>{};
      if (classLevel != null && classLevel.isNotEmpty) {
        query['class_level'] = classLevel;
      }
      final res = await dio.get(ApiEndpoints.videos, queryParameters: query);
      final items = (res.data['items'] as List? ?? [])
          .map((e) => VideoModel.fromJson(e))
          .toList();
      state = VideoState(videos: items, isLoading: false);
    } catch (e) {
      state = VideoState(isLoading: false, error: e.toString());
    }
  }
}

final videoProvider = StateNotifierProvider<VideoNotifier, VideoState>((ref) {
  return VideoNotifier(ref);
});
