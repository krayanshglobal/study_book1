import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import '../../../core/api/api_endpoints.dart';
import '../../../core/api/dio_client.dart';
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
  String? _pendingOrderId;
  String? _paymentStatusMessage;
  bool _paymentStatusIsError = false;
  late final Razorpay _razorpay;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
    _load();
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
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
    setState(() {
      _subscribingId = plan['_id'];
      _paymentStatusMessage = null;
      _paymentStatusIsError = false;
    });
    try {
      final r = await dioClient.post(ApiEndpoints.checkout, data: {
        'plan_id': plan['_id'],
      });
      final checkout = Map<String, dynamic>.from(r.data as Map);
      _pendingOrderId = checkout['order_id']?.toString();
      _razorpay.open({
        'key': checkout['key_id'],
        'amount': checkout['amount'],
        'currency': checkout['currency'],
        'name': checkout['name'] ?? 'C Maths',
        'description': checkout['description'],
        'order_id': checkout['order_id'],
        'prefill': checkout['prefill'] ?? const {},
        'theme': {'color': '#2563EB'},
        'retry': {'enabled': true, 'max_count': 2},
      });
    } catch (e) {
      if (mounted) showToast(context, formatApiError(e), isError: true);
      if (mounted) setState(() => _subscribingId = null);
    }
  }

  Future<void> _handlePaymentSuccess(PaymentSuccessResponse response) async {
    final orderId = response.orderId ?? _pendingOrderId;
    if (orderId == null ||
        response.paymentId == null ||
        response.signature == null) {
      _finishWithError('Razorpay returned incomplete payment details.');
      return;
    }
    try {
      await dioClient.post(ApiEndpoints.paymentVerify, data: {
        'razorpay_order_id': orderId,
        'razorpay_payment_id': response.paymentId,
        'razorpay_signature': response.signature,
      });
      await ref.read(authProvider.notifier).refresh();
      if (!mounted) return;
      setState(() => _subscribingId = null);
      context.go(
          '/payment/success?session_id=${Uri.encodeQueryComponent(orderId)}');
    } catch (e) {
      _finishWithError(formatApiError(e));
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    if (response.code == Razorpay.PAYMENT_CANCELLED) {
      _finishPaymentStatus(
        'Payment cancelled. No payment was made and no amount was charged.',
        isError: false,
      );
      return;
    }
    final message = response.code == Razorpay.NETWORK_ERROR
        ? 'Payment could not continue because of a network problem. Please try again.'
        : (response.message ?? 'Payment failed. Please try again.');
    _finishPaymentStatus(message, isError: true);
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    if (mounted) {
      showToast(context,
          'External wallet selected: ${response.walletName ?? 'wallet'}');
    }
  }

  void _finishWithError(String message) {
    _finishPaymentStatus(message, isError: true);
  }

  void _finishPaymentStatus(String message, {required bool isError}) {
    if (!mounted) return;
    setState(() {
      _subscribingId = null;
      _pendingOrderId = null;
      _paymentStatusMessage = message;
      _paymentStatusIsError = isError;
    });
    showToast(context, message, isError: isError);
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
                      style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2,
                          color: AppColors.violet)),
                  const SizedBox(height: 4),
                  Text('Choose your plan',
                      style: GoogleFonts.fraunces(
                          fontSize: 28,
                          fontWeight: FontWeight.w600,
                          color: AppColors.navy)),
                  const SizedBox(height: 4),
                  Text(
                      'Your admin sets what\'s free and what\'s premium. Upgrade anytime.',
                      style: GoogleFonts.inter(
                          fontSize: 13, color: AppColors.slate500)),
                  if (_paymentStatusMessage != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: (_paymentStatusIsError
                                ? AppColors.error
                                : AppColors.success)
                            .withAlpha(18),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: (_paymentStatusIsError
                                  ? AppColors.error
                                  : AppColors.success)
                              .withAlpha(55),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _paymentStatusIsError
                                ? Icons.error_outline_rounded
                                : Icons.info_outline_rounded,
                            size: 18,
                            color: _paymentStatusIsError
                                ? AppColors.error
                                : AppColors.success,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _paymentStatusMessage!,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _paymentStatusIsError
                                    ? AppColors.error
                                    : AppColors.success,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (user?.subscriptionActive == true) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.success.withAlpha(20),
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: AppColors.success.withAlpha(60)),
                      ),
                      child: Text(
                        'You are premium! Expires ${user?.subscriptionExpiresAt?.substring(0, 10) ?? 'soon'}.',
                        style: GoogleFonts.inter(
                            fontSize: 13,
                            color: AppColors.success,
                            fontWeight: FontWeight.w500),
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
                          color:
                              isPopular ? AppColors.violet : AppColors.slate200,
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
                                  style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.5,
                                      color: AppColors.blue)),
                              if (isPopular)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.violet,
                                    borderRadius: BorderRadius.circular(99),
                                  ),
                                  child: Text('POPULAR',
                                      style: GoogleFonts.inter(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white)),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(p['name'] ?? '',
                              style: GoogleFonts.fraunces(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.navy)),
                          const SizedBox(height: 8),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text('₹${p['price']}',
                                  style: GoogleFonts.fraunces(
                                      fontSize: 32,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.navy)),
                              Text('/plan',
                                  style: GoogleFonts.inter(
                                      fontSize: 13, color: AppColors.slate500)),
                            ],
                          ),
                          if (p['description'] != null &&
                              (p['description'] as String).isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(p['description'],
                                style: GoogleFonts.inter(
                                    fontSize: 13, color: AppColors.slate500)),
                          ],
                          const SizedBox(height: 16),
                          const Divider(height: 1, color: AppColors.slate200),
                          const SizedBox(height: 12),
                          ...((p['features'] as List?) ?? [])
                              .map((f) => Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.check,
                                            size: 16, color: AppColors.blue),
                                        const SizedBox(width: 8),
                                        Expanded(
                                            child: Text(f.toString(),
                                                style: GoogleFonts.inter(
                                                    fontSize: 13,
                                                    color:
                                                        AppColors.slate700))),
                                      ],
                                    ),
                                  )),
                          const SizedBox(height: 16),
                          PrimaryButton(
                            text: user?.subscriptionActive == true
                                ? 'Already premium'
                                : isBusy
                                    ? 'Opening payment...'
                                    : 'Subscribe',
                            onPressed:
                                (user?.subscriptionActive == true || isBusy)
                                    ? null
                                    : () => _subscribe(p),
                            color:
                                isPopular ? AppColors.violet : AppColors.navy,
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
