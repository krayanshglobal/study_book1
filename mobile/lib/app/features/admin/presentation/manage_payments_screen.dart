import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/api/api_endpoints.dart';
import '../../../core/api/dio_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../common/widgets/app_drawer.dart';
import '../../common/widgets/shared_widgets.dart';

class ManagePaymentsScreen extends ConsumerStatefulWidget {
  const ManagePaymentsScreen({super.key});

  @override
  ConsumerState<ManagePaymentsScreen> createState() =>
      _ManagePaymentsScreenState();
}

class _ManagePaymentsScreenState
    extends ConsumerState<ManagePaymentsScreen> {
  List _items = [];
  int _total = 0;
  int _page = 0;
  String _statusFilter = 'all';
  bool _loading = true;
  static const int _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final params = <String, dynamic>{
        'limit': _pageSize,
        'skip': _page * _pageSize,
      };
      if (_statusFilter != 'all') {
        params['payment_status'] = _statusFilter;
      }
      final r = await dioClient.get(ApiEndpoints.adminPayments, queryParameters: params);
      if (!mounted) return;
      setState(() {
        _items = r.data['items'] ?? [];
        _total = r.data['total'] ?? 0;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        showToast(context, formatApiError(e), isError: true);
      }
    }
  }

  Color _statusColor(String st) {
    switch (st.toLowerCase()) {
      case 'paid':
        return const Color(0xFF059669);
      case 'pending':
        return const Color(0xFFD97706);
      case 'failed':
        return const Color(0xFFDC2626);
      default:
        return AppColors.slate500;
    }
  }

  Color _statusBg(String st) {
    switch (st.toLowerCase()) {
      case 'paid':
        return const Color(0xFFD1FAE5);
      case 'pending':
        return const Color(0xFFFEF3C7);
      case 'failed':
        return const Color(0xFFFEE2E2);
      default:
        return AppColors.slate100;
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalPages = (_total / _pageSize).ceil();

    return MainScaffold(
      title: 'Payment Transactions',
      showBack: true,
      parentRoute: '/admin',
      body: Column(
        children: [
          // Filter bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                DropdownButton<String>(
                  value: _statusFilter,
                  underline: const SizedBox(),
                  style: GoogleFonts.inter(fontSize: 13, color: AppColors.navy),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All statuses')),
                    DropdownMenuItem(value: 'paid', child: Text('Paid')),
                    DropdownMenuItem(value: 'pending', child: Text('Pending')),
                    DropdownMenuItem(value: 'initiated', child: Text('Initiated')),
                    DropdownMenuItem(value: 'failed', child: Text('Failed')),
                  ],
                  onChanged: (v) {
                    setState(() {
                      _statusFilter = v!;
                      _page = 0;
                    });
                    _load();
                  },
                ),
                const Spacer(),
                Text('$_total total',
                    style: GoogleFonts.inter(fontSize: 12, color: AppColors.slate500)),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.slate200),
          Expanded(
            child: _loading
                ? const LoadingIndicator()
                : RefreshIndicator(
                    onRefresh: _load,
                    child: _items.isEmpty
                        ? Center(
                            child: Text('No transactions found.',
                                style: GoogleFonts.inter(fontSize: 14, color: AppColors.slate500)),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: _items.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (_, i) {
                              final tx = _items[i];
                              final st = (tx['payment_status'] as String? ?? 'initiated');
                              final cur = (tx['currency'] as String? ?? 'INR').toUpperCase();
                              final symbol = cur == 'INR' ? '₹' : '\$';
                              final amt = (tx['amount'] as num?)?.toDouble() ?? 0.0;
                              return Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: AppColors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: AppColors.slate100),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(tx['user_name'] ?? '—',
                                                  style: GoogleFonts.inter(
                                                      fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.navy)),
                                              Text(tx['user_email'] ?? '',
                                                  style: GoogleFonts.jetBrainsMono(
                                                      fontSize: 11, color: AppColors.slate400)),
                                            ],
                                          ),
                                        ),
                                        Text('$symbol${amt.toStringAsFixed(2)}',
                                            style: GoogleFonts.jetBrainsMono(
                                                fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.navy)),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Plan: ${tx['metadata']?['plan_name'] ?? '—'}',
                                          style: GoogleFonts.inter(fontSize: 12, color: AppColors.slate600),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: _statusBg(st),
                                            borderRadius: BorderRadius.circular(99),
                                          ),
                                          child: Text(
                                            st.toUpperCase(),
                                            style: GoogleFonts.inter(
                                                fontSize: 9, fontWeight: FontWeight.w800, color: _statusColor(st)),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
          ),
          if (totalPages > 1)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppColors.white,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton(
                    onPressed: _page > 0 ? () { setState(() => _page--); _load(); } : null,
                    style: OutlinedButton.styleFrom(shape: const CircleBorder()),
                    child: const Icon(Icons.chevron_left, size: 18),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text('Page ${_page + 1} of $totalPages',
                        style: GoogleFonts.inter(fontSize: 12, color: AppColors.slate600)),
                  ),
                  OutlinedButton(
                    onPressed: _page < totalPages - 1 ? () { setState(() => _page++); _load(); } : null,
                    style: OutlinedButton.styleFrom(shape: const CircleBorder()),
                    child: const Icon(Icons.chevron_right, size: 18),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
