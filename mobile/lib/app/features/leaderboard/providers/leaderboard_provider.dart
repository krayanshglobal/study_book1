import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_endpoints.dart';
import '../../auth/providers/auth_provider.dart';

class LeaderboardItem {
  final int rank;
  final String userId;
  final String name;
  final String? classLevel;
  final int totalPoints;

  LeaderboardItem({
    required this.rank,
    required this.userId,
    required this.name,
    this.classLevel,
    required this.totalPoints,
  });

  factory LeaderboardItem.fromJson(Map<String, dynamic> json) {
    return LeaderboardItem(
      rank: (json['rank'] as num?)?.toInt() ?? 1,
      userId: json['user_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      classLevel: json['class_level']?.toString(),
      totalPoints: (json['total_points'] as num?)?.toInt() ?? 0,
    );
  }
}

class LeaderboardState {
  final List<LeaderboardItem> items;
  final bool isLoading;
  final String? error;

  LeaderboardState({this.items = const [], this.isLoading = false, this.error});
}

class LeaderboardNotifier extends StateNotifier<LeaderboardState> {
  final Ref ref;

  LeaderboardNotifier(this.ref) : super(LeaderboardState(isLoading: true)) {
    loadLeaderboard();
  }

  Future<void> loadLeaderboard({String? classLevel}) async {
    state = LeaderboardState(isLoading: true);
    try {
      final dio = ref.read(dioClientProvider);
      final query = <String, dynamic>{};
      if (classLevel != null && classLevel.isNotEmpty) {
        query['class_level'] = classLevel;
      }
      final res = await dio.get(ApiEndpoints.leaderboard, queryParameters: query);
      final list = (res.data['items'] as List? ?? [])
          .map((e) => LeaderboardItem.fromJson(e))
          .toList();
      state = LeaderboardState(items: list, isLoading: false);
    } catch (e) {
      state = LeaderboardState(isLoading: false, error: e.toString());
    }
  }
}

final leaderboardProvider = StateNotifierProvider<LeaderboardNotifier, LeaderboardState>((ref) {
  return LeaderboardNotifier(ref);
});
