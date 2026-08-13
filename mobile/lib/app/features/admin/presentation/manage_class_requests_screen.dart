import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/api/api_endpoints.dart';
import '../../../core/api/dio_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../common/widgets/app_drawer.dart';
import '../../common/widgets/shared_widgets.dart';

class ManageClassRequestsScreen extends ConsumerStatefulWidget {
  const ManageClassRequestsScreen({super.key});

  @override
  ConsumerState<ManageClassRequestsScreen> createState() =>
      _ManageClassRequestsScreenState();
}

class _ManageClassRequestsScreenState
    extends ConsumerState<ManageClassRequestsScreen> {
  List _requests = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await dioClient.get(
        ApiEndpoints.adminClassChangeRequests,
        queryParameters: {'status': 'pending'},
      );
      if (!mounted) return;
      setState(() {
        _requests = r.data['items'] ?? [];
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
        showToast(context, 'Failed to load class change requests.', isError: true);
      }
    }
  }

  Future<void> _handleAction(String id, String action) async {
    try {
      await dioClient.post(ApiEndpoints.adminClassChangeRequestAction(id, action));
      if (!mounted) return;
      showToast(
        context,
        action == 'approve'
            ? 'Request approved successfully'
            : 'Request rejected successfully',
      );
      _load();
    } catch (_) {
      if (mounted) showToast(context, 'Failed to $action request.', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MainScaffold(
      title: 'Class Change Requests',
      showBack: true,
      parentRoute: '/admin',
      body: _loading
          ? const LoadingIndicator()
          : RefreshIndicator(
              onRefresh: _load,
              child: _requests.isEmpty
                  ? const _EmptyState()
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      itemCount: _requests.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (_, i) {
                        final r = _requests[i];
                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.slate100),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(r['user_name'] ?? '',
                                  style: GoogleFonts.inter(
                                      fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.navy)),
                              const SizedBox(height: 2),
                              Text(r['user_email'] ?? '',
                                  style: GoogleFonts.jetBrainsMono(
                                      fontSize: 11, color: AppColors.slate400)),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: AppColors.slate100,
                                      borderRadius: BorderRadius.circular(99),
                                      border: Border.all(color: AppColors.slate200),
                                    ),
                                    child: Text('Class ${r['current_class'] ?? ''}',
                                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.slate700)),
                                  ),
                                  const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 8),
                                    child: Icon(Icons.arrow_forward, size: 14, color: AppColors.slate400),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: AppColors.violet.withAlpha(20),
                                      borderRadius: BorderRadius.circular(99),
                                      border: Border.all(color: AppColors.violet.withAlpha(60)),
                                    ),
                                    child: Text('Class ${r['requested_class'] ?? ''}',
                                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.violet)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      icon: const Icon(Icons.check, size: 14),
                                      label: Text('Approve',
                                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF059669),
                                        shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(99)),
                                        padding: const EdgeInsets.symmetric(vertical: 10),
                                      ),
                                      onPressed: () => _handleAction(r['_id']?.toString() ?? '', 'approve'),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      icon: const Icon(Icons.close, size: 14, color: Colors.red),
                                      label: Text('Reject',
                                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.red)),
                                      style: OutlinedButton.styleFrom(
                                        side: const BorderSide(color: Color(0xFFFECACA)),
                                        shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(99)),
                                        padding: const EdgeInsets.symmetric(vertical: 10),
                                      ),
                                      onPressed: () => _handleAction(r['_id']?.toString() ?? '', 'reject'),
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
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(32),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.slate100),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48, height: 48,
              decoration: const BoxDecoration(color: AppColors.slate50, shape: BoxShape.circle),
              child: const Icon(Icons.schedule_outlined, size: 20, color: AppColors.slate400),
            ),
            const SizedBox(height: 12),
            Text('No Pending Requests',
                style: GoogleFonts.fraunces(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.navy)),
            const SizedBox(height: 6),
            Text(
              'All student class change requests have been processed.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.slate500),
            ),
          ],
        ),
      ),
    );
  }
}
