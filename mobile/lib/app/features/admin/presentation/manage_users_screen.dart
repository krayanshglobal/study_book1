import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/api/api_endpoints.dart';
import '../../../core/api/dio_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../common/widgets/app_drawer.dart';
import '../../common/widgets/shared_widgets.dart';

const _pageSize = 20;

class ManageUsersScreen extends ConsumerStatefulWidget {
  const ManageUsersScreen({super.key});

  @override
  ConsumerState<ManageUsersScreen> createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends ConsumerState<ManageUsersScreen> {
  List _items = [];
  int _total = 0;
  int _page = 0;
  String _search = '';
  bool _loading = false;

  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await dioClient.get(
        ApiEndpoints.adminUsers,
        queryParameters: {
          'search': _search.isEmpty ? null : _search,
          'limit': _pageSize,
          'skip': _page * _pageSize,
        },
      );
      if (!mounted) return;
      setState(() {
        _items = r.data['items'] ?? [];
        _total = r.data['total'] ?? 0;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showToast(context, formatApiError(e), isError: true);
    }
  }

  void _onSearchChanged(String v) {
    setState(() {
      _search = v;
      _page = 0;
    });
    _load();
  }

  // ── Edit User Dialog ──────────────────────────────────────────────────────
  void _openEdit(Map u) {
    final nameCtrl = TextEditingController(text: u['name'] ?? '');
    final phoneCtrl = TextEditingController(text: u['phone'] ?? '');
    String classLevel = u['class_level'] ?? '';
    String role = u['role'] ?? 'student';
    bool saving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setSt) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Edit User', style: GoogleFonts.fraunces(fontSize: 20, fontWeight: FontWeight.w600)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _dialogLabel('Name'),
                TextField(controller: nameCtrl, decoration: _inputDec('Full name')),
                const SizedBox(height: 12),
                _dialogLabel('Phone'),
                TextField(controller: phoneCtrl, decoration: _inputDec('+91 9999999999')),
                const SizedBox(height: 12),
                _dialogLabel('Class'),
                DropdownButtonFormField<String>(
                  initialValue: ['8', '9', '10'].contains(classLevel) ? classLevel : null,
                  hint: const Text('— Not set —'),
                  decoration: _inputDec(''),
                  items: const [
                    DropdownMenuItem(value: '8', child: Text('Class 8')),
                    DropdownMenuItem(value: '9', child: Text('Class 9')),
                    DropdownMenuItem(value: '10', child: Text('Class 10')),
                  ],
                  onChanged: (v) => setSt(() => classLevel = v ?? ''),
                ),
                if (u['role'] != 'superadmin') ...[
                  const SizedBox(height: 12),
                  _dialogLabel('Role'),
                  DropdownButtonFormField<String>(
                    initialValue: role,
                    decoration: _inputDec(''),
                    items: const [
                      DropdownMenuItem(value: 'student', child: Text('Student')),
                      DropdownMenuItem(value: 'admin', child: Text('Admin')),
                    ],
                    onChanged: (v) => setSt(() => role = v ?? 'student'),
                  ),
                ],
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
              onPressed: saving
                  ? null
                  : () async {
                      setSt(() => saving = true);
                      final upd = <String, dynamic>{};
                      if (nameCtrl.text.trim() != (u['name'] ?? '')) upd['name'] = nameCtrl.text.trim();
                      if (phoneCtrl.text.trim() != (u['phone'] ?? '')) upd['phone'] = phoneCtrl.text.trim();
                      if (classLevel.isNotEmpty && classLevel != (u['class_level'] ?? '')) upd['class_level'] = classLevel;
                      if (role != (u['role'] ?? 'student')) upd['role'] = role;
                      try {
                        await dioClient.put('/api/admin/users/${u['_id']}', data: upd);
                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);
                        showToast(ctx, 'User updated');
                        _load();
                      } catch (e) {
                        if (!ctx.mounted) return;
                        showToast(ctx, formatApiError(e), isError: true);
                      } finally {
                        setSt(() => saving = false);
                      }
                    },
              child: saving
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Save changes'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Delete User ───────────────────────────────────────────────────────────
  void _deleteUser(Map u) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${u['name']}"?', style: GoogleFonts.fraunces(fontSize: 18)),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await dioClient.delete('/api/admin/users/${u['_id']}');
                if (!mounted) return;
                showToast(context, 'User deleted');
                _load();
              } catch (e) {
                if (!mounted) return;
                showToast(context, formatApiError(e), isError: true);
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // ── Subscription Dialog ───────────────────────────────────────────────────
  void _openSubscription(Map u) {
    bool subActive = u['subscription_active'] == true;
    int durationDays = 30;
    bool saving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setSt) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Manage Subscription', style: GoogleFonts.fraunces(fontSize: 20, fontWeight: FontWeight.w600)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('User: ${u['name'] ?? ''}', style: GoogleFonts.inter(fontSize: 13, color: AppColors.slate500)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Switch(
                    value: subActive,
                    onChanged: (v) => setSt(() => subActive = v),
                    activeThumbColor: AppColors.success,
                  ),
                  const SizedBox(width: 8),
                  Text(subActive ? 'Premium Active' : 'Free Plan', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500)),
                ],
              ),
              if (subActive) ...[
                const SizedBox(height: 12),
                _dialogLabel('Duration (days from now)'),
                TextField(
                  keyboardType: TextInputType.number,
                  decoration: _inputDec('30'),
                  onChanged: (v) => setSt(() => durationDays = int.tryParse(v) ?? 30),
                  controller: TextEditingController(text: '$durationDays'),
                ),
                const SizedBox(height: 4),
                Text(
                  'Current: ${u['subscription_expires_at']?.toString().substring(0, 10) ?? 'not set'}',
                  style: GoogleFonts.inter(fontSize: 11, color: AppColors.slate500),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
              ),
              onPressed: saving
                  ? null
                  : () async {
                      setSt(() => saving = true);
                      try {
                        await dioClient.patch(
                          '/api/admin/users/${u['_id']}/subscription',
                          data: {'subscription_active': subActive, 'duration_days': durationDays},
                        );
                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);
                        showToast(ctx, 'Subscription updated');
                        _load();
                      } catch (e) {
                        if (!ctx.mounted) return;
                        showToast(ctx, formatApiError(e), isError: true);
                      } finally {
                        setSt(() => saving = false);
                      }
                    },
              child: saving
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Save subscription'),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDec(String hint) => InputDecoration(
        hintText: hint,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.slate200),
        ),
      );

  Widget _dialogLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(text, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.slate500)),
      );

  @override
  Widget build(BuildContext context) {
    final totalPages = (_total / _pageSize).ceil();

    return MainScaffold(
      title: 'Manage Users',
      showBack: true,
      parentRoute: '/admin',
      body: Column(
        children: [
          // Search + count bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: 'Search by name or email…',
                      hintStyle: GoogleFonts.inter(fontSize: 13, color: AppColors.slate400),
                      prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.slate400),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(99), borderSide: const BorderSide(color: AppColors.slate200)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(99), borderSide: const BorderSide(color: AppColors.slate200)),
                      filled: true,
                      fillColor: AppColors.white,
                    ),
                    onChanged: _onSearchChanged,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '$_total total · pg ${_page + 1}/${totalPages < 1 ? 1 : totalPages}',
                  style: GoogleFonts.inter(fontSize: 12, color: AppColors.slate500),
                ),
              ],
            ),
          ),

          // List
          Expanded(
            child: _loading
                ? const LoadingIndicator()
                : _items.isEmpty
                    ? const EmptyState(message: 'No users found.', icon: Icons.group_outlined)
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                          itemCount: _items.length,
                          itemBuilder: (ctx, i) {
                            final u = _items[i] as Map;
                            final bool isSubActive = u['subscription_active'] == true;
                            final String role = u['role'] ?? 'student';
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: AppColors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppColors.slate200),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor: AppColors.navy.withAlpha(20),
                                    child: Text(
                                      ((u['name'] as String?) ?? 'U').substring(0, 1).toUpperCase(),
                                      style: GoogleFonts.fraunces(color: AppColors.navy, fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Flexible(
                                              child: Text(u['name'] ?? '',
                                                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.navy),
                                                  overflow: TextOverflow.ellipsis),
                                            ),
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                              decoration: BoxDecoration(
                                                color: role == 'admin' || role == 'superadmin' ? AppColors.violet.withAlpha(20) : AppColors.slate100,
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                role.toUpperCase(),
                                                style: GoogleFonts.inter(
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.w700,
                                                    color: role == 'admin' || role == 'superadmin' ? AppColors.violet : AppColors.slate700),
                                              ),
                                            ),
                                          ],
                                        ),
                                        Text(u['email'] ?? '',
                                            style: GoogleFonts.inter(fontSize: 12, color: AppColors.slate500),
                                            overflow: TextOverflow.ellipsis),
                                        Text(
                                          [
                                            if ((u['class_level'] ?? '').toString().isNotEmpty) 'Class ${u['class_level']}',
                                            if (isSubActive) 'Premium' else 'Free',
                                            '${u['total_points'] ?? 0} pts',
                                          ].join(' · '),
                                          style: GoogleFonts.inter(fontSize: 11, color: AppColors.slate400),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Actions
                                  Column(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.blue),
                                        tooltip: 'Edit user',
                                        onPressed: () => _openEdit(u),
                                      ),
                                      IconButton(
                                        icon: Icon(Icons.shield_outlined, size: 18,
                                            color: isSubActive ? AppColors.success : AppColors.slate400),
                                        tooltip: 'Manage subscription',
                                        onPressed: () => _openSubscription(u),
                                      ),
                                      if (role == 'student')
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                                          tooltip: 'Delete user',
                                          onPressed: () => _deleteUser(u),
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

          // Pagination
          if (totalPages > 1)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.chevron_left, size: 16),
                    label: const Text('Prev'),
                    style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99))),
                    onPressed: _page == 0 ? null : () { setState(() => _page--); _load(); },
                  ),
                  const SizedBox(width: 12),
                  Text('Page ${_page + 1} / $totalPages', style: GoogleFonts.inter(fontSize: 13, color: AppColors.slate500)),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.chevron_right, size: 16),
                    label: const Text('Next'),
                    style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99))),
                    onPressed: _page >= totalPages - 1 ? null : () { setState(() => _page++); _load(); },
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
