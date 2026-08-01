import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/api/api_endpoints.dart';
import '../../../core/api/dio_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../common/widgets/app_drawer.dart';
import '../../common/widgets/shared_widgets.dart';

class ManagePlansScreen extends ConsumerStatefulWidget {
  const ManagePlansScreen({super.key});

  @override
  ConsumerState<ManagePlansScreen> createState() => _ManagePlansScreenState();
}

class _ManagePlansScreenState extends ConsumerState<ManagePlansScreen> {
  List _plans = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await dioClient.get(ApiEndpoints.adminPlans);
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

  Future<void> _deletePlan(String id) async {
    try {
      await dioClient.delete(ApiEndpoints.adminPlanDetail(id));
      if (!mounted) return;
      showToast(context, 'Plan deleted');
      _load();
    } catch (e) {
      if (!mounted) return;
      showToast(context, formatApiError(e), isError: true);
    }
  }

  void _showCreateDialog() {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final durationCtrl = TextEditingController(text: '30');
    final descCtrl = TextEditingController();
    final featuresCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Create Plan', style: GoogleFonts.fraunces(fontSize: 20, fontWeight: FontWeight.w600)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Plan Name')),
              const SizedBox(height: 8),
              TextField(controller: priceCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Price (INR)')),
              const SizedBox(height: 8),
              TextField(controller: durationCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Duration (Days)')),
              const SizedBox(height: 8),
              TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Description')),
              const SizedBox(height: 8),
              TextField(controller: featuresCtrl, decoration: const InputDecoration(labelText: 'Features (comma separated)')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty || priceCtrl.text.trim().isEmpty) {
                showToast(context, 'Name and Price required', isError: true);
                return;
              }
              Navigator.pop(ctx);
              try {
                final features = featuresCtrl.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
                final body = {
                  'name': nameCtrl.text.trim(),
                  'price': double.tryParse(priceCtrl.text.trim()) ?? 0.0,
                  'currency': 'inr',
                  'duration_days': int.tryParse(durationCtrl.text.trim()) ?? 30,
                  'description': descCtrl.text.trim(),
                  'features': features,
                  'is_active': true,
                };
                await dioClient.post(ApiEndpoints.adminPlans, data: body);
                if (!mounted) return;
                showToast(context, 'Plan created!');
                _load();
              } catch (e) {
                if (!mounted) return;
                showToast(context, formatApiError(e), isError: true);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MainScaffold(
      title: 'Manage Plans',
      showBack: true,
      parentRoute: '/admin',
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateDialog,
        backgroundColor: AppColors.navy,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _loading
          ? const LoadingIndicator()
          : _plans.isEmpty
              ? const EmptyState(message: 'No plans created yet.', icon: Icons.card_membership_outlined)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _plans.length,
                    itemBuilder: (ctx, i) {
                      final p = _plans[i] as Map;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.slate200),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(p['name'] ?? '', style: GoogleFonts.fraunces(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.navy)),
                                  const SizedBox(height: 2),
                                  Text('₹${p['price']} / ${p['duration_days']} days', style: GoogleFonts.jetBrainsMono(fontSize: 13, color: AppColors.blue, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: AppColors.error),
                              onPressed: () => _deletePlan(p['_id']),
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
