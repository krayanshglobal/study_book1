import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/models/notification_model.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/notification_provider.dart';
import '../widgets/shared_widgets.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(notificationProvider);
    final notifier = ref.read(notificationProvider.notifier);
    final user = ref.watch(authProvider).user;
    final isPremium = user?.subscriptionActive == true;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.navy, size: 18),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Notifications',
          style: GoogleFonts.fraunces(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.navy,
          ),
        ),
        actions: [
          if (state.unreadCount > 0)
            TextButton(
              onPressed: () => notifier.markAllRead(),
              child: Text(
                'Mark all read',
                style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.blue,
                    fontWeight: FontWeight.w600),
              ),
            ),
          const SizedBox(width: 4),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.slate200),
        ),
      ),
      body: state.loading && state.notifications.isEmpty
          ? const LoadingIndicator()
          : RefreshIndicator(
              color: AppColors.blue,
              onRefresh: () => notifier.refresh(),
              child: state.notifications.isEmpty
                  ? _EmptyNotifications()
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      itemCount: state.notifications.length,
                      separatorBuilder: (_, __) => const Divider(
                          height: 1,
                          indent: 16,
                          endIndent: 16,
                          color: AppColors.slate100),
                      itemBuilder: (context, i) {
                        final notif = state.notifications[i];
                        return _NotificationCard(
                          notif: notif,
                          isPremium: isPremium,
                          onTap: () {
                            notifier.markRead(notif.id);
                            _navigate(context, notif, isPremium);
                          },
                          onMarkRead: () => notifier.markRead(notif.id),
                          onDelete: () => notifier.delete(notif.id),
                        );
                      },
                    ),
            ),
    );
  }

  void _navigate(
      BuildContext context, AppNotification notif, bool isPremium) {
    final route = notif.type.isPremium && !isPremium
        ? '/pricing'
        : notif.type.route;
    context.push(route);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Notification Card
// ─────────────────────────────────────────────────────────────────────────────

class _NotificationCard extends StatelessWidget {
  final AppNotification notif;
  final bool isPremium;
  final VoidCallback onTap;
  final VoidCallback onMarkRead;
  final VoidCallback onDelete;

  const _NotificationCard({
    required this.notif,
    required this.isPremium,
    required this.onTap,
    required this.onMarkRead,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final meta = _typeMeta(notif.type);

    return Dismissible(
      key: Key(notif.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: AppColors.error.withAlpha(15),
        child: const Icon(Icons.delete_outline_rounded,
            color: AppColors.error, size: 22),
      ),
      onDismissed: (_) => onDelete(),
      child: InkWell(
        onTap: onTap,
        child: Container(
          color: notif.isRead ? Colors.transparent : AppColors.blue.withAlpha(5),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon circle
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: meta.color.withAlpha(18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(meta.icon, color: meta.color, size: 20),
              ),
              const SizedBox(width: 12),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // Type badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: meta.color.withAlpha(15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            notif.type.label,
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: meta.color,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const Spacer(),
                        // Timestamp
                        Text(
                          _formatTime(notif.timestamp),
                          style: GoogleFonts.inter(
                              fontSize: 10, color: AppColors.slate400),
                        ),
                        // Unread dot
                        if (!notif.isRead) ...[
                          const SizedBox(width: 6),
                          Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: AppColors.blue,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      notif.title,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: notif.isRead
                            ? FontWeight.w500
                            : FontWeight.w700,
                        color: AppColors.navy,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      notif.body,
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.slate500,
                          height: 1.4),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),

                    // Action row
                    Row(
                      children: [
                        if (!notif.isRead)
                          _ActionChip(
                            label: 'Mark as read',
                            icon: Icons.check_rounded,
                            onTap: onMarkRead,
                          ),
                        const SizedBox(width: 8),
                        _ActionChip(
                          label: 'View',
                          icon: Icons.arrow_forward_rounded,
                          onTap: onTap,
                          primary: true,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('d MMM').format(dt);
  }

  _NotifMeta _typeMeta(NotifType type) {
    switch (type) {
      case NotifType.announcement:
        return _NotifMeta(Icons.campaign_rounded, AppColors.blue);
      case NotifType.testReminder:
        return _NotifMeta(Icons.access_time_rounded, AppColors.warning);
      case NotifType.missedTest:
        return _NotifMeta(Icons.warning_rounded, AppColors.error);
      case NotifType.newQuestions:
        return _NotifMeta(Icons.quiz_rounded, AppColors.success);
      case NotifType.offer:
        return _NotifMeta(Icons.local_offer_rounded, AppColors.violet);
      case NotifType.premiumActivated:
        return _NotifMeta(Icons.workspace_premium_rounded, AppColors.success);
      case NotifType.premiumExpired:
        return _NotifMeta(Icons.lock_outline_rounded, AppColors.error);
      case NotifType.referralReward:
        return _NotifMeta(Icons.card_giftcard_rounded, AppColors.violet);
    }
  }
}

class _NotifMeta {
  final IconData icon;
  final Color color;
  const _NotifMeta(this.icon, this.color);
}

// ─────────────────────────────────────────────────────────────────────────────
// Action Chip
// ─────────────────────────────────────────────────────────────────────────────

class _ActionChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool primary;

  const _ActionChip({
    required this.label,
    required this.icon,
    required this.onTap,
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: primary
              ? AppColors.navy.withAlpha(10)
              : AppColors.slate100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: primary
                  ? AppColors.navy.withAlpha(20)
                  : AppColors.slate200),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 12,
                color:
                    primary ? AppColors.navy : AppColors.slate500),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: primary ? AppColors.navy : AppColors.slate500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty State
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyNotifications extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.slate100,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.notifications_none_rounded,
                    size: 40, color: AppColors.slate400),
              ),
              const SizedBox(height: 20),
              Text(
                'All caught up!',
                style: GoogleFonts.fraunces(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'No notifications right now.\nPull down to refresh.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.slate500,
                    height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
