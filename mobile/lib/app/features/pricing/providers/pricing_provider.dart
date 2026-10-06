import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/models/plan_model.dart';
import '../../auth/providers/auth_provider.dart';

class PricingState {
  final List<PlanModel> plans;
  final bool isLoading;
  final bool isCheckingOut;
  final Map<String, dynamic>? checkoutData;
  final String? error;

  PricingState({
    this.plans = const [],
    this.isLoading = false,
    this.isCheckingOut = false,
    this.checkoutData,
    this.error,
  });

  PricingState copyWith({
    List<PlanModel>? plans,
    bool? isLoading,
    bool? isCheckingOut,
    Map<String, dynamic>? checkoutData,
    String? error,
  }) {
    return PricingState(
      plans: plans ?? this.plans,
      isLoading: isLoading ?? this.isLoading,
      isCheckingOut: isCheckingOut ?? this.isCheckingOut,
      checkoutData: checkoutData ?? this.checkoutData,
      error: error,
    );
  }
}

class PricingNotifier extends StateNotifier<PricingState> {
  final Ref ref;

  PricingNotifier(this.ref) : super(PricingState(isLoading: true)) {
    loadPlans();
  }

  Future<void> loadPlans() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final dio = ref.read(dioClientProvider);
      final res = await dio.get(ApiEndpoints.plans);
      final items = (res.data['items'] as List? ?? [])
          .map((e) => PlanModel.fromJson(e))
          .toList();
      state = state.copyWith(plans: items, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<Map<String, dynamic>?> checkout(String planId) async {
    state = state.copyWith(isCheckingOut: true, error: null);
    try {
      final dio = ref.read(dioClientProvider);
      final res = await dio.post(
        ApiEndpoints.checkout,
        data: {'plan_id': planId},
      );
      final data = Map<String, dynamic>.from(res.data as Map);
      state = state.copyWith(isCheckingOut: false, checkoutData: data);
      return data;
    } catch (e) {
      state = state.copyWith(isCheckingOut: false, error: e.toString());
      return null;
    }
  }
}

final pricingProvider =
    StateNotifierProvider<PricingNotifier, PricingState>((ref) {
  return PricingNotifier(ref);
});
