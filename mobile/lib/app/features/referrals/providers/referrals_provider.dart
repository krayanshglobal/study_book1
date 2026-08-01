import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_endpoints.dart';
import '../../auth/providers/auth_provider.dart';

class ReferralInfo {
  final String? referralCode;
  final int count;
  final List<dynamic> referrals;

  ReferralInfo({this.referralCode, this.count = 0, this.referrals = const []});

  factory ReferralInfo.fromJson(Map<String, dynamic> json) {
    return ReferralInfo(
      referralCode: json['referral_code']?.toString(),
      count: (json['count'] as num?)?.toInt() ?? 0,
      referrals: json['referrals'] as List? ?? [],
    );
  }
}

class ReferralsState {
  final ReferralInfo? info;
  final bool isLoading;
  final String? error;

  ReferralsState({this.info, this.isLoading = false, this.error});
}

class ReferralsNotifier extends StateNotifier<ReferralsState> {
  final Ref ref;

  ReferralsNotifier(this.ref) : super(ReferralsState(isLoading: true)) {
    loadReferrals();
  }

  Future<void> loadReferrals() async {
    state = ReferralsState(isLoading: true);
    try {
      final dio = ref.read(dioClientProvider);
      final res = await dio.get(ApiEndpoints.myReferrals);
      final data = ReferralInfo.fromJson(res.data);
      state = ReferralsState(info: data, isLoading: false);
    } catch (e) {
      state = ReferralsState(isLoading: false, error: e.toString());
    }
  }
}

final referralsProvider = StateNotifierProvider<ReferralsNotifier, ReferralsState>((ref) {
  return ReferralsNotifier(ref);
});
