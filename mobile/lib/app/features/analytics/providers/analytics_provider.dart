import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/models/analytics_model.dart';
import '../../auth/providers/auth_provider.dart';

class AnalyticsState {
  final StudentAnalyticsModel? analytics;
  final bool isLoading;
  final String? error;

  AnalyticsState({this.analytics, this.isLoading = false, this.error});
}

class AnalyticsNotifier extends StateNotifier<AnalyticsState> {
  final Ref ref;

  AnalyticsNotifier(this.ref) : super(AnalyticsState(isLoading: true)) {
    loadAnalytics();
  }

  Future<void> loadAnalytics() async {
    state = AnalyticsState(isLoading: true);
    try {
      final dio = ref.read(dioClientProvider);
      final res = await dio.get(ApiEndpoints.studentAnalytics);
      final data = StudentAnalyticsModel.fromJson(res.data);
      state = AnalyticsState(analytics: data, isLoading: false);
    } catch (e) {
      state = AnalyticsState(isLoading: false, error: e.toString());
    }
  }
}

final analyticsProvider = StateNotifierProvider<AnalyticsNotifier, AnalyticsState>((ref) {
  return AnalyticsNotifier(ref);
});
