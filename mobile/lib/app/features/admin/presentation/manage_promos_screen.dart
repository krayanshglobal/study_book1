import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/api/api_endpoints.dart';
import '../../../core/api/dio_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../common/widgets/app_drawer.dart';
import '../../common/widgets/shared_widgets.dart';

class ManagePromosScreen extends ConsumerStatefulWidget {
  const ManagePromosScreen({super.key});

  @override
  ConsumerState<ManagePromosScreen> createState() => _ManagePromosScreenState();
}

class _ManagePromosScreenState extends ConsumerState<ManagePromosScreen> {
  List _items = [];
  bool _loading = true;

  // Form fields
  final _titleCtrl = TextEditingController();
  final _subtitleCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  int _countdownHours = 24;
  bool _isActive = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _subtitleCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = await dioClient.get(ApiEndpoints.promos);
      if (!mounted) return;
      setState(() {
        _items = r.data['items'] ?? [];
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        showToast(context, 'Failed to load promo banners.', isError: true);
      }
    }
  }

  void _showAddDialog() {
    _titleCtrl.clear();
    _subtitleCtrl.clear();
    _codeCtrl.clear();
    _countdownHours = 24;
    _isActive = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('New Promo Offer', style: GoogleFonts.fraunces(fontSize: 20, color: AppColors.navy)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _label('Offer Banner Title'),
                _tf(_titleCtrl, 'e.g. ₹200 off for New Users'),
                const SizedBox(height: 12),
                _label('Subtitle / Description'),
                _tf(_subtitleCtrl, 'e.g. Join StudyBook Premium today'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label('Promo Code'),
                          _tf(_codeCtrl, 'FIRST200'),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label('Countdown (Hours)'),
                          TextField(
                            keyboardType: TextInputType.number,
                            decoration: _inputDec('24'),
                            style: GoogleFonts.inter(fontSize: 13),
                            onChanged: (v) => setSt(() => _countdownHours = int.tryParse(v) ?? 24),
                            controller: TextEditingController(text: '$_countdownHours'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Switch(
                      value: _isActive,
                      onChanged: (v) => setSt(() => _isActive = v),
                      activeThumbColor: AppColors.violet,
                    ),
                    const SizedBox(width: 8),
                    Text('Activate Banner Immediately', style: GoogleFonts.inter(fontSize: 13)),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.navy,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
              ),
              onPressed: () async {
                if (_titleCtrl.text.trim().isEmpty ||
                    _subtitleCtrl.text.trim().isEmpty ||
                    _codeCtrl.text.trim().isEmpty) {
                  showToast(ctx, 'Please fill in all fields.', isError: true);
                  return;
                }
                try {
                  await dioClient.post(ApiEndpoints.promos, data: {
                    'title': _titleCtrl.text.trim(),
                    'subtitle': _subtitleCtrl.text.trim(),
                    'code': _codeCtrl.text.trim().toUpperCase(),
                    'countdown_hours': _countdownHours,
                    'is_active': _isActive,
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) showToast(context, 'Promo offer published successfully!');
                  _load();
                } catch (e) {
                  if (ctx.mounted) showToast(ctx, formatApiError(e), isError: true);
                }
              },
              child: Text('Publish Banner', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _delete(String id) async {
    final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('Delete Offer?', style: GoogleFonts.fraunces(color: AppColors.navy)),
            content: Text('Are you sure you want to delete this offer?', style: GoogleFonts.inter()),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Delete', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ) ??
        false;
    if (!ok) return;
    try {
      await dioClient.delete(ApiEndpoints.promoDetail(id));
      if (mounted) showToast(context, 'Offer deleted.');
      _load();
    } catch (e) {
      if (mounted) showToast(context, formatApiError(e), isError: true);
    }
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(t, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.slate500)),
      );

  Widget _tf(TextEditingController ctrl, String hint) => TextField(
        controller: ctrl,
        decoration: _inputDec(hint),
        style: GoogleFonts.inter(fontSize: 13),
      );

  InputDecoration _inputDec(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(fontSize: 13, color: AppColors.slate400),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.slate200),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return MainScaffold(
      title: 'Offers & Promo Banners',
      showBack: true,
      parentRoute: '/admin',
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        backgroundColor: AppColors.violet,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _loading
          ? const LoadingIndicator()
          : RefreshIndicator(
              onRefresh: _load,
              child: _items.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text('No promo banners published yet.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(fontSize: 14, color: AppColors.slate500)),
                      ),
                    )
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      itemCount: _items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 14),
                      itemBuilder: (_, i) {
                        final p = _items[i];
                        return Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: AppColors.slate50,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.slate200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: AppColors.violet.withAlpha(20),
                                            borderRadius: BorderRadius.circular(99),
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(Icons.label_outline, size: 12, color: AppColors.violet),
                                              const SizedBox(width: 4),
                                              Text('Code: ${p['code'] ?? ''}',
                                                  style: GoogleFonts.jetBrainsMono(
                                                      fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.violet)),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Row(
                                          children: [
                                            const Icon(Icons.calendar_today_outlined, size: 12, color: AppColors.slate400),
                                            const SizedBox(width: 4),
                                            Text('${p['countdown_hours'] ?? 24} hrs countdown',
                                                style: GoogleFonts.inter(fontSize: 11, color: AppColors.slate400)),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                    onPressed: () => _delete(p['_id']?.toString() ?? ''),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(p['title'] ?? '',
                                  style: GoogleFonts.fraunces(
                                      fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.navy)),
                              const SizedBox(height: 4),
                              Text(p['subtitle'] ?? '',
                                  style: GoogleFonts.inter(fontSize: 13, color: AppColors.slate600)),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFD1FAE5),
                                      borderRadius: BorderRadius.circular(99),
                                    ),
                                    child: Text('ACTIVE',
                                        style: GoogleFonts.inter(
                                            fontSize: 9, fontWeight: FontWeight.w800,
                                            color: const Color(0xFF059669))),
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
