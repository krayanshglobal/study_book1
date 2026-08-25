import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/api/api_endpoints.dart';
import '../../../core/api/dio_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../common/widgets/app_drawer.dart';
import '../../common/widgets/shared_widgets.dart';

class ReferralsScreen extends ConsumerStatefulWidget {
  const ReferralsScreen({super.key});

  @override
  ConsumerState<ReferralsScreen> createState() => _ReferralsScreenState();
}

class _ReferralsScreenState extends ConsumerState<ReferralsScreen> {
  Map? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await dioClient.get(ApiEndpoints.myReferrals);
      if (mounted) {
        setState(() {
          _data = r.data as Map;
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

  void _copy() {
    final code = _data?['referral_code'];
    if (code == null) return;
    Clipboard.setData(ClipboardData(text: code));
    showToast(context, 'Referral code copied!');
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const MainScaffold(
        title: 'Referrals',
        showBack: true,
        parentRoute: '/dashboard',
        body: LoadingIndicator(),
      );
    }

    final String code = _data?['referral_code'] ?? '—';
    final int count = _data?['count'] ?? 0;
    final List referrals = _data?['referrals'] ?? [];

    return MainScaffold(
      title: 'Referrals',
      showBack: true,
      parentRoute: '/dashboard',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('GROW TOGETHER',
                style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 2, color: AppColors.violet)),
            const SizedBox(height: 4),
            Text('Referrals',
                style: GoogleFonts.fraunces(fontSize: 28, fontWeight: FontWeight.w600, color: AppColors.navy)),
            const SizedBox(height: 4),
            Text('Every friend you bring boosts your rank and unlocks bonus features.',
                style: GoogleFonts.inter(fontSize: 13, color: AppColors.slate500)),
            const SizedBox(height: 20),

            // Referral code card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.slate200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('YOUR CODE',
                      style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: AppColors.slate500)),
                  const SizedBox(height: 8),
                  Text(code,
                      style: GoogleFonts.jetBrainsMono(fontSize: 36, fontWeight: FontWeight.w700, color: AppColors.navy)),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _copy,
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('Copy code'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.navy,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
            // Friends list
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.slate200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.group_outlined, size: 18, color: AppColors.blue),
                      const SizedBox(width: 8),
                      Text('Friends joined ($count)',
                          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.navy)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (referrals.isEmpty)
                    Text('No referrals yet. Share your code!', style: GoogleFonts.inter(fontSize: 13, color: AppColors.slate500))
                  else
                    ...referrals.map((r) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(r['name'] ?? '', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.navy)),
                              ),
                              Text(
                                (r['joined_at'] as String? ?? '').length >= 10 ? (r['joined_at'] as String).substring(0, 10) : '',
                                style: GoogleFonts.jetBrainsMono(fontSize: 12, color: AppColors.slate500),
                              ),
                            ],
                          ),
                        )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
