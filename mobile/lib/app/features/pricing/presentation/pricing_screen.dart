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

class PricingScreen extends ConsumerStatefulWidget {
  const PricingScreen({super.key});

  @override
  ConsumerState<PricingScreen> createState() => _PricingScreenState();
}

class _PricingScreenState extends ConsumerState<PricingScreen> {
  List _plans = [];
  bool _loading = true;
  String? _subscribingId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await dioClient.get(ApiEndpoints.plans);
      if (mounted) {
        setState(() {
          _plans = r.data['items'] ?? [];
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

  Future<void> _subscribe(Map plan) async {
    setState(() => _subscribingId = plan['_id']);
    try {
      final r = await dioClient.post(ApiEndpoints.checkout, data: {
        'plan_id': plan['_id'],
        'origin_url': AppConfig.baseUrl,
      });
      final checkoutUrl = r.data['url'] as String;
      final uri = Uri.parse(checkoutUrl);

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) showToast(context, 'Could not launch payment URL', isError: true);
      }
    } catch (e) {
      if (mounted) showToast(context, formatApiError(e), isError: true);
    } finally {
      if (mounted) setState(() => _subscribingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;

    return MainScaffold(
      title: 'Choose Plan',
      showBack: true,
      parentRoute: '/dashboard',
      body: _loading
          ? const LoadingIndicator()
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('MEMBERSHIP',
                      style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 2, color: AppColors.violet)),
                  const SizedBox(height: 4),
                  Text('Choose your plan',
                      style: GoogleFonts.fraunces(fontSize: 28, fontWeight: FontWeight.w600, color: AppColors.navy)),
                  const SizedBox(height: 4),
                  Text('Your admin sets what\'s free and what\'s premium. Upgrade anytime.',
                      style: GoogleFonts.inter(fontSize: 13, color: AppColors.slate500)),
                  const SizedBox(height: 16),

                  if (user?.subscriptionActive == true) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.success.withAlpha(20),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.success.withAlpha(60)),
                      ),
                      child: Text(
                        'You are premium! Expires ${user?.subscriptionExpiresAt?.substring(0, 10) ?? 'soon'}.',
                        style: GoogleFonts.inter(fontSize: 13, color: AppColors.success, fontWeight: FontWeight.w500),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  ..._plans.asMap().entries.map((entry) {
                    final i = entry.key;
                    final p = entry.value as Map;
                    final bool isPopular = i == 1;
                    final bool isBusy = _subscribingId == p['_id'];

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isPopular ? AppColors.violet : AppColors.slate200,
                          width: isPopular ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('${p['duration_days']} DAYS',
                                  style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: AppColors.blue)),
                              if (isPopular)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.violet,
                                    borderRadius: BorderRadius.circular(99),
                                  ),
                                  child: Text('POPULAR',
                                      style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(p['name'] ?? '',
                              style: GoogleFonts.fraunces(fontSize: 22, fontWeight: FontWeight.w600, color: AppColors.navy)),
                          const SizedBox(height: 8),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text('₹${p['price']}',
                                  style: GoogleFonts.fraunces(fontSize: 32, fontWeight: FontWeight.w700, color: AppColors.navy)),
                              Text('/plan', style: GoogleFonts.inter(fontSize: 13, color: AppColors.slate500)),
                            ],
                          ),
                          if (p['description'] != null && (p['description'] as String).isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(p['description'], style: GoogleFonts.inter(fontSize: 13, color: AppColors.slate500)),
                          ],
                          const SizedBox(height: 16),
                          const Divider(height: 1, color: AppColors.slate200),
                          const SizedBox(height: 12),

                          ...((p['features'] as List?) ?? []).map((f) => Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Row(
                                  children: [
                                    const Icon(Icons.check, size: 16, color: AppColors.blue),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text(f.toString(), style: GoogleFonts.inter(fontSize: 13, color: AppColors.slate700))),
                                  ],
                                ),
                              )),

                          const SizedBox(height: 16),
                          PrimaryButton(
                            text: user?.subscriptionActive == true ? 'Already premium' : isBusy ? 'Redirecting...' : 'Subscribe',
                            onPressed: (user?.subscriptionActive == true || isBusy) ? null : () => _subscribe(p),
                            color: isPopular ? AppColors.violet : AppColors.navy,
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
    );
  }
}
