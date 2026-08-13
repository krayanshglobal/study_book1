import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/models/announcement_model.dart';
import '../../../core/models/test_model.dart';
import '../../auth/providers/auth_provider.dart';

class DashboardData {
  final List<AnnouncementModel> announcements;
  final List<TestModel> upcomingTests;
  final bool isLoading;
  final String? error;

  DashboardData({
    this.announcements = const [],
    this.upcomingTests = const [],
    this.isLoading = false,
    this.error,
  });

  DashboardData copyWith({
    List<AnnouncementModel>? announcements,
    List<TestModel>? upcomingTests,
    bool? isLoading,
    String? error,
  }) {
    return DashboardData(
      announcements: announcements ?? this.announcements,
      upcomingTests: upcomingTests ?? this.upcomingTests,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class DashboardNotifier extends StateNotifier<DashboardData> {
  final Ref ref;

  DashboardNotifier(this.ref) : super(DashboardData(isLoading: true)) {
    loadDashboard();
  }

  Future<void> loadDashboard() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final dio = ref.read(dioClientProvider);

      // Fetch active announcements
      final annRes = await dio.get('/api/announcements/active');
      final annList = (annRes.data['items'] as List? ?? [])
          .map((e) => AnnouncementModel.fromJson(e))
          .toList();

      // Fetch upcoming tests
      final testRes = await dio.get(ApiEndpoints.upcomingTests);
      final testList = (testRes.data['items'] as List? ?? [])
          .map((e) => TestModel.fromJson(e))
          .toList();

      state = DashboardData(
        announcements: annList,
        upcomingTests: testList,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final dashboardProvider = StateNotifierProvider<DashboardNotifier, DashboardData>((ref) {
  return DashboardNotifier(ref);
});
