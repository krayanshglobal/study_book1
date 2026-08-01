import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/api/api_endpoints.dart';
import '../../../core/api/dio_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../../common/widgets/app_drawer.dart';
import '../../common/widgets/shared_widgets.dart';

class PaymentSuccessScreen extends ConsumerStatefulWidget {
  final String? sessionId;
  const PaymentSuccessScreen({super.key, this.sessionId});

  @override
  ConsumerState<PaymentSuccessScreen> createState() => _PaymentSuccessScreenState();
}

class _PaymentSuccessScreenState extends ConsumerState<PaymentSuccessScreen> {
  String _status = 'pending'; // pending, paid, failed
  int _attempts = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.sessionId == null || widget.sessionId!.isEmpty) {
      _status = 'failed';
    } else {
      _pollStatus();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _pollStatus() {
    _timer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      _attempts++;
      try {
        final r = await dioClient.get(ApiEndpoints.paymentStatus(widget.sessionId!));
        final paymentStatus = r.data['payment_status'];
        final statusStr = r.data['status'];

        if (paymentStatus == 'paid') {
          timer.cancel();
          await ref.read(authProvider.notifier).refresh();
          if (mounted) setState(() => _status = 'paid');
          return;
        }

        if (statusStr == 'expired' || _attempts >= 8) {
          timer.cancel();
          if (mounted) setState(() => _status = 'failed');
          return;
        }
      } catch (_) {
        if (_attempts >= 8) {
          timer.cancel();
          if (mounted) setState(() => _status = 'failed');
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MainScaffold(
      title: 'Payment Status',
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_status == 'pending') ...[
                const CircularProgressIndicator(color: AppColors.blue),
                const SizedBox(height: 20),
                Text('Confirming payment...',
                    style: GoogleFonts.fraunces(fontSize: 24, fontWeight: FontWeight.w600, color: AppColors.navy)),
                const SizedBox(height: 8),
                Text('Hold on while we verify with Stripe.', style: GoogleFonts.inter(fontSize: 14, color: AppColors.slate500)),
              ] else if (_status == 'paid') ...[
                const Icon(Icons.check_circle_outline, size: 64, color: AppColors.success),
                const SizedBox(height: 20),
                Text('You\'re premium!',
                    style: GoogleFonts.fraunces(fontSize: 26, fontWeight: FontWeight.w600, color: AppColors.navy)),
                const SizedBox(height: 8),
                Text('All premium content is now unlocked.', style: GoogleFonts.inter(fontSize: 14, color: AppColors.slate500)),
                const SizedBox(height: 24),
                PrimaryButton(
                  text: 'Go to dashboard',
                  onPressed: () => context.go('/dashboard'),
                ),
              ] else ...[
                const Icon(Icons.cancel_outlined, size: 64, color: AppColors.error),
                const SizedBox(height: 20),
                Text('Something went wrong',
                    style: GoogleFonts.fraunces(fontSize: 26, fontWeight: FontWeight.w600, color: AppColors.navy)),
                const SizedBox(height: 8),
                Text('Please try again or contact support.', style: GoogleFonts.inter(fontSize: 14, color: AppColors.slate500)),
                const SizedBox(height: 24),
                PrimaryButton(
                  text: 'Back to pricing',
                  onPressed: () => context.go('/pricing'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
