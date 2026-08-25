import 'dart:convert';
import 'package:dio/dio.dart' as dio;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../core/api/dio_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../../common/widgets/app_drawer.dart';
import '../../common/widgets/shared_widgets.dart';

ImageProvider? _getUserAvatarProvider(String? avatarUrl) {
  if (avatarUrl == null || avatarUrl.trim().isEmpty) return null;
  final trimmed = avatarUrl.trim();
  if (trimmed.startsWith('data:image/')) {
    try {
      final base64Str = trimmed.split(',').last;
      final bytes = base64Decode(base64Str);
      return MemoryImage(bytes);
    } catch (_) {
      return null;
    }
  }
  return NetworkImage(trimmed);
}

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _editing = false;
  bool _saving = false;
  bool _requestingClass = false;
  bool _uploadingPhoto = false;

  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  String _selectedClass = '';

  @override
  void initState() {
    super.initState();
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

  Future<void> _pickAndUploadPhoto() async {
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_outlined, color: AppColors.blue),
                title: Text('Choose from Gallery', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined, color: AppColors.violet),
                title: Text('Take a Photo', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              if (ref.read(authProvider).user?.avatarUrl?.isNotEmpty == true)
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                  title: Text('Remove Photo', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: AppColors.error)),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _removePhoto();
                  },
                ),
            ],
          ),
        ),
      ),
    );

    if (source == null) return;

    final picked = await picker.pickImage(source: source, imageQuality: 85);
    if (picked == null) return;

    final path = picked.path.toLowerCase();
    final isJpgPng = path.endsWith('.jpg') || path.endsWith('.jpeg') || path.endsWith('.png');
    final bytes = await picked.readAsBytes();

    if (!isJpgPng || bytes.length > 2 * 1024 * 1024) {
      if (mounted) {
        showToast(
          context,
          'Profile picture must be JPG or PNG and less than 2 MB.',
          isError: true,
        );
      }
      return;
    }

    setState(() => _uploadingPhoto = true);
    try {
      final fileName = picked.name.isNotEmpty ? picked.name : 'avatar.jpg';
      final mimeType = path.endsWith('.png') ? 'image/png' : 'image/jpeg';
      final formData = dio.FormData.fromMap({
        'file': dio.MultipartFile.fromBytes(
          bytes,
          filename: fileName,
          contentType: dio.DioMediaType.parse(mimeType),
        ),
      });

      await dioClient.post('/api/auth/profile/photo', data: formData);
      await ref.read(authProvider.notifier).refresh();
      if (mounted) {
        showToast(context, 'Profile picture updated successfully!');
      }
    } catch (e) {
      if (mounted) showToast(context, formatApiError(e), isError: true);
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _removePhoto() async {
    setState(() => _uploadingPhoto = true);
    try {
      await dioClient.delete('/api/auth/profile/photo');
      await ref.read(authProvider.notifier).refresh();
      if (mounted) {
        showToast(context, 'Profile picture removed');
      }
    } catch (e) {
      if (mounted) showToast(context, formatApiError(e), isError: true);
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
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
    final planLabel = user.isSuperAdmin
        ? 'Super Admin'
        : user.isAdmin
            ? 'Admin'
            : user.subscriptionActive == true
                ? 'Premium Plan'
                : 'Free Plan';

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
      parentRoute: user.isAdmin ? '/admin' : '/dashboard',
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Gradient Profile Header ──────────────────────────────────
            _ProfileHeader(
              initial: initial,
              name: user.name,
              planLabel: planLabel,
              avatarUrl: user.avatarUrl,
              studentId: user.isAdmin ? null : user.studentId,
              uploadingPhoto: _uploadingPhoto,
              onEdit: _openEdit,
              onPhotoTap: _pickAndUploadPhoto,
            ),

            const SizedBox(height: 20),

            if (_editing)
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
                    if (user.isAdmin)
                      _InfoRow(
                          icon: Icons.admin_panel_settings_outlined,
                          label: 'Role',
                          value: user.isSuperAdmin ? 'Super Admin' : 'Admin')
                    else ...[
                      if (user.studentId != null && user.studentId!.isNotEmpty)
                        _InfoRow(
                            icon: Icons.badge_outlined,
                            label: 'Student ID',
                            value: user.studentId!,
                            isMono: true,
                            isCopyable: true,
                            copyValue: user.studentId),
                      _InfoRow(
                          icon: Icons.school_outlined,
                          label: 'Class',
                          value: user.classLevel != null ? 'Class ${user.classLevel}' : '—'),
                    ],
                    _InfoRow(
                        icon: Icons.phone_outlined,
                        label: 'Phone',
                        value: user.phone ?? '—'),
                    if (!user.isAdmin)
                      _InfoRow(
                          icon: Icons.workspace_premium_outlined,
                          label: 'Plan',
                          value: planLabel),
                    _InfoRow(
                        icon: Icons.calendar_today_outlined,
                        label: 'Member Since',
                        value: memberSince),
                    if (!user.isAdmin && user.referralCode != null)
                      _InfoRow(
                          icon: Icons.star_outline_rounded,
                          label: 'Referral Code',
                          value: user.referralCode!,
                          isMono: true,
                          isCopyable: true,
                          copyValue: user.referralCode),
                  ],
                ),
              ),

              const SizedBox(height: 24),

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
                          icon: Icons.camera_alt_outlined,
                          label: 'Change Profile Picture',
                          onTap: _pickAndUploadPhoto,
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

class _ProfileHeader extends StatelessWidget {
  final String initial;
  final String name;
  final String planLabel;
  final String? avatarUrl;
  final String? studentId;
  final bool uploadingPhoto;
  final VoidCallback onEdit;
  final VoidCallback onPhotoTap;

  const _ProfileHeader({
    required this.initial,
    required this.name,
    required this.planLabel,
    this.avatarUrl,
    this.studentId,
    this.uploadingPhoto = false,
    required this.onEdit,
    required this.onPhotoTap,
  });

  @override
  Widget build(BuildContext context) {
    final imageProvider = _getUserAvatarProvider(avatarUrl);

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
          Positioned(
            right: -12,
            bottom: -16,
            child: Icon(
              Icons.school_rounded,
              size: 90,
              color: Colors.white.withAlpha(18),
            ),
          ),

          Row(
            children: [
              // Avatar with edit button
              GestureDetector(
                onTap: onPhotoTap,
                child: Stack(
                  children: [
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        color: AppColors.violet,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        image: imageProvider != null
                            ? DecorationImage(
                                image: imageProvider,
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: imageProvider == null
                          ? Center(
                              child: Text(
                                initial,
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 32,
                                ),
                              ),
                            )
                          : null,
                    ),
                    if (uploadingPhoto)
                      Positioned.fill(
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.black45,
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: AppColors.blue,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Center(
                          child: Icon(Icons.camera_alt_rounded,
                              color: Colors.white, size: 13),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 18),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 20,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    if (studentId != null && studentId!.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 3),
                        margin: const EdgeInsets.only(bottom: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(25),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.white30),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.badge_outlined, size: 12, color: Colors.white70),
                            const SizedBox(width: 4),
                            Text(
                              'ID: $studentId',
                              style: GoogleFonts.jetBrainsMono(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.blue,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        planLabel,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

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
