import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/api/dio_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../../common/widgets/app_drawer.dart';
import '../../common/widgets/shared_widgets.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _editing = false;
  bool _saving = false;
  bool _requestingClass = false;

  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  String _selectedClass = '';

  @override
  void initState() {
    super.initState();
    // Refresh the user profile from the server every time the Profile screen
    // is opened. This keeps the plan badge (Free / Premium) always in sync
    // with the latest backend state without requiring a logout or restart.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authProvider.notifier).refreshSilently();
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _openEdit() {
    final user = ref.read(authProvider).user;
    if (user != null) {
      _nameCtrl.text = user.name;
      _phoneCtrl.text = user.phone ?? '';
      _selectedClass = user.classLevel ?? '';
    }
    setState(() => _editing = true);
  }

  Future<void> _saveProfile() async {
    setState(() => _saving = true);
    try {
      await dioClient.post('/api/auth/profile', data: {
        'name': _nameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
      });
      await ref.read(authProvider.notifier).refresh();
      if (!mounted) return;
      setState(() => _editing = false);
      showToast(context, 'Profile updated');
    } catch (e) {
      if (mounted) showToast(context, formatApiError(e), isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _requestClassChange() async {
    final user = ref.read(authProvider).user;
    if (_selectedClass.isEmpty || _selectedClass == user?.classLevel) {
      showToast(context, 'Select a different class to request a change',
          isError: true);
      return;
    }
    setState(() => _requestingClass = true);
    try {
      await dioClient.post('/api/auth/profile/request-class-change', data: {
        'requested_class': _selectedClass,
      });
      if (!mounted) return;
      setState(() => _editing = false);
      showToast(
          context, 'Class change request submitted. Awaiting admin approval.');
    } catch (e) {
      if (mounted) showToast(context, formatApiError(e), isError: true);
    } finally {
      if (mounted) setState(() => _requestingClass = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;

    if (user == null) {
      return const MainScaffold(
        title: 'Profile',
        showBack: true,
        parentRoute: '/dashboard',
        body: EmptyState(message: 'User not logged in.'),
      );
    }

    final initial = user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U';
    final planLabel =
        user.subscriptionActive == true ? 'Premium Plan' : 'Free Plan';

    // Format joined date
    String memberSince = '—';
    try {
      if (user.createdAt != null) {
        final dt = DateTime.parse(user.createdAt!);
        memberSince = DateFormat('d MMM yyyy').format(dt);
      }
    } catch (_) {}

    return MainScaffold(
      title: 'Profile',
      showBack: true,
      parentRoute: '/dashboard',
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Gradient Profile Header ──────────────────────────────────
            _ProfileHeader(
              initial: initial,
              name: user.name,
              planLabel: planLabel,
              onEdit: _openEdit,
            ),

            const SizedBox(height: 20),

            if (_editing)
              // ── Edit form ────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _EditForm(
                  nameCtrl: _nameCtrl,
                  phoneCtrl: _phoneCtrl,
                  selectedClass: _selectedClass,
                  currentClass: user.classLevel,
                  saving: _saving,
                  requestingClass: _requestingClass,
                  onClassChanged: (v) =>
                      setState(() => _selectedClass = v ?? ''),
                  onSave: _saveProfile,
                  onRequestClass: _requestClassChange,
                  onCancel: () => setState(() => _editing = false),
                ),
              )
            else ...[
              // ── User Information ─────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _InfoCard(
                  rows: [
                    _InfoRow(
                        icon: Icons.person_outline_rounded,
                        label: 'Full Name',
                        value: user.name),
                    _InfoRow(
                        icon: Icons.mail_outline_rounded,
                        label: 'Email',
                        value: user.email),
                    _InfoRow(
                        icon: Icons.phone_outlined,
                        label: 'Phone',
                        value: user.phone ?? '—'),
                    _InfoRow(
                        icon: Icons.workspace_premium_outlined,
                        label: 'Plan',
                        value: planLabel),
                    _InfoRow(
                        icon: Icons.calendar_today_outlined,
                        label: 'Member Since',
                        value: memberSince),
                    _InfoRow(
                        icon: Icons.star_outline_rounded,
                        label: 'Referral Code',
                        value: user.referralCode ?? '—',
                        isMono: true,
                        isCopyable: true,
                        copyValue: user.referralCode),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ── Account section ──────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionTitle(label: 'Account'),
                    const SizedBox(height: 10),
                    _MenuCard(
                      items: [
                        _MenuItem(
                          icon: Icons.person_outline_rounded,
                          label: 'Edit Profile',
                          onTap: _openEdit,
                        ),
                        _MenuItem(
                          icon: Icons.lock_outline_rounded,
                          label: 'Change Password',
                          onTap: () => context.push('/change-password'),
                        ),
                        _MenuItem(
                          icon: Icons.notifications_none_rounded,
                          label: 'Notifications',
                          onTap: () => context.push('/notifications'),
                        ),
                        _MenuItem(
                          icon: Icons.shield_outlined,
                          label: 'Privacy & Security',
                          onTap: () {},
                        ),
                        _MenuItem(
                          icon: Icons.help_outline_rounded,
                          label: 'Help & Support',
                          onTap: () {},
                          showDivider: false,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ── App section ──────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionTitle(label: 'App'),
                    const SizedBox(height: 10),
                    _MenuCard(
                      items: [
                        _MenuItem(
                          icon: Icons.info_outline_rounded,
                          label: 'About StudyBook',
                          onTap: () {},
                        ),
                        _MenuItem(
                          icon: Icons.description_outlined,
                          label: 'Terms & Conditions',
                          onTap: () {},
                        ),
                        _MenuItem(
                          icon: Icons.logout_rounded,
                          label: 'Logout',
                          labelColor: AppColors.error,
                          iconColor: AppColors.error,
                          showDivider: false,
                          onTap: () async {
                            await ref.read(authProvider.notifier).logout();
                            if (context.mounted) context.go('/login');
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Profile Gradient Header
// ─────────────────────────────────────────────────────────────────────────────

class _ProfileHeader extends StatelessWidget {
  final String initial;
  final String name;
  final String planLabel;
  final VoidCallback onEdit;

  const _ProfileHeader({
    required this.initial,
    required this.name,
    required this.planLabel,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.navy,
            Color(0xFF1E3A8A),
            Color(0xFF4C1D95),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          // Watermark graduation cap icon
          Positioned(
            right: -12,
            bottom: -16,
            child: Icon(
              Icons.school_rounded,
              size: 90,
              color: Colors.white.withAlpha(18),
            ),
          ),

          // Content
          Row(
            children: [
              // Avatar with edit button
              Stack(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: const BoxDecoration(
                      color: AppColors.violet,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        initial,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 30,
                        ),
                      ),
                    ),
                  ),
                  // Edit pencil
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: GestureDetector(
                      onTap: onEdit,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: const BoxDecoration(
                          color: AppColors.blue,
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Icon(Icons.edit_rounded,
                              color: Colors.white, size: 13),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 20),

              // Name + plan
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 22,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.blue,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      planLabel,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Info Card (User Information section)
// ─────────────────────────────────────────────────────────────────────────────

class _InfoRow {
  final IconData icon;
  final String label;
  final String value;
  final bool isMono;
  final bool isCopyable;
  final String? copyValue;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.isMono = false,
    this.isCopyable = false,
    this.copyValue,
  });
}

class _InfoCard extends StatelessWidget {
  final List<_InfoRow> rows;
  const _InfoCard({required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.slate200),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withAlpha(8),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: rows.asMap().entries.map((entry) {
          final i = entry.key;
          final row = entry.value;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Icon(row.icon, size: 18, color: AppColors.slate400),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        row.label,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: AppColors.slate600,
                        ),
                      ),
                    ),
                    if (row.isMono)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            row.value,
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.violet,
                            ),
                          ),
                          if (row.isCopyable && row.copyValue != null) ...[
                            const SizedBox(width: 6),
                            GestureDetector(
                              onTap: () {
                                Clipboard.setData(
                                    ClipboardData(text: row.copyValue!));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Copied to clipboard'),
                                    duration: Duration(seconds: 2),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              },
                              child: const Icon(Icons.copy_rounded,
                                  size: 15, color: AppColors.slate400),
                            ),
                          ],
                        ],
                      )
                    else
                      Text(
                        row.value,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.navy,
                        ),
                      ),
                  ],
                ),
              ),
              if (i < rows.length - 1)
                const Divider(
                    height: 1, color: AppColors.slate200, indent: 46),
            ],
          );
        }).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section title
// ─────────────────────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String label;
  const _SectionTitle({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppColors.navy,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Menu card (Account / App sections)
// ─────────────────────────────────────────────────────────────────────────────

class _MenuItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? labelColor;
  final Color? iconColor;
  final bool showDivider;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.labelColor,
    this.iconColor,
    this.showDivider = true,
  });
}

class _MenuCard extends StatelessWidget {
  final List<_MenuItem> items;
  const _MenuCard({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.slate200),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withAlpha(8),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: items.asMap().entries.map((entry) {
          final i = entry.key;
          final item = entry.value;
          return Column(
            children: [
              InkWell(
                onTap: item.onTap,
                borderRadius: BorderRadius.only(
                  topLeft: i == 0
                      ? const Radius.circular(16)
                      : Radius.zero,
                  topRight: i == 0
                      ? const Radius.circular(16)
                      : Radius.zero,
                  bottomLeft: i == items.length - 1
                      ? const Radius.circular(16)
                      : Radius.zero,
                  bottomRight: i == items.length - 1
                      ? const Radius.circular(16)
                      : Radius.zero,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 15),
                  child: Row(
                    children: [
                      Icon(item.icon,
                          size: 20,
                          color: item.iconColor ?? AppColors.slate500),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          item.label,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: item.labelColor ?? AppColors.navy,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded,
                          size: 20,
                          color: item.iconColor ?? AppColors.slate400),
                    ],
                  ),
                ),
              ),
              if (item.showDivider)
                const Divider(
                    height: 1, color: AppColors.slate200, indent: 50),
            ],
          );
        }).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Edit Form
// ─────────────────────────────────────────────────────────────────────────────

class _EditForm extends StatelessWidget {
  final TextEditingController nameCtrl;
  final TextEditingController phoneCtrl;
  final String selectedClass;
  final String? currentClass;
  final bool saving;
  final bool requestingClass;
  final ValueChanged<String?> onClassChanged;
  final VoidCallback onSave;
  final VoidCallback onRequestClass;
  final VoidCallback onCancel;

  const _EditForm({
    required this.nameCtrl,
    required this.phoneCtrl,
    required this.selectedClass,
    required this.currentClass,
    required this.saving,
    required this.requestingClass,
    required this.onClassChanged,
    required this.onSave,
    required this.onRequestClass,
    required this.onCancel,
  });

  InputDecoration _inputDec(String hint) {
    return InputDecoration(
      hintText: hint,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.slate200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.blue, width: 2),
      ),
      filled: true,
      fillColor: AppColors.slate50,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.slate200),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withAlpha(8),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Edit Profile',
              style: GoogleFonts.fraunces(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.navy)),
          const SizedBox(height: 20),

          _label('Full Name'),
          TextField(
            controller: nameCtrl,
            decoration: _inputDec('Your full name'),
            style: GoogleFonts.inter(fontSize: 14),
          ),
          const SizedBox(height: 14),

          _label('Phone'),
          TextField(
            controller: phoneCtrl,
            decoration: _inputDec('+91 9999999999'),
            keyboardType: TextInputType.phone,
            style: GoogleFonts.inter(fontSize: 14),
          ),
          const SizedBox(height: 14),

          _label('Class (change requires admin approval)'),
          DropdownButtonFormField<String>(
            initialValue: selectedClass.isNotEmpty ? selectedClass : null,
            decoration: _inputDec('Select class'),
            items: const [
              DropdownMenuItem(value: '8', child: Text('Class 8')),
              DropdownMenuItem(value: '9', child: Text('Class 9')),
              DropdownMenuItem(value: '10', child: Text('Class 10')),
            ],
            onChanged: onClassChanged,
          ),
          if (selectedClass.isNotEmpty && selectedClass != currentClass)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Changing class requires admin approval.',
                style: GoogleFonts.inter(
                    fontSize: 11, color: const Color(0xFFD97706)),
              ),
            ),
          const SizedBox(height: 20),

          Row(
            children: [
              ElevatedButton(
                onPressed: saving ? null : onSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.navy,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(99)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 12),
                ),
                child: saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text('Save',
                        style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white)),
              ),
              const SizedBox(width: 10),
              TextButton(
                onPressed: onCancel,
                child: Text('Cancel',
                    style: GoogleFonts.inter(
                        fontSize: 13, color: AppColors.slate500)),
              ),
            ],
          ),
          if (selectedClass.isNotEmpty && selectedClass != currentClass) ...[
            const SizedBox(height: 8),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(99)),
              ),
              onPressed: requestingClass ? null : onRequestClass,
              child: Text(
                requestingClass
                    ? 'Submitting…'
                    : 'Request class change → Class $selectedClass',
                style: GoogleFonts.inter(
                    fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.slate600),
      ),
    );
  }
}
