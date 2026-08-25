import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api/api_endpoints.dart';
import '../../../core/api/dio_client.dart';
import '../../../core/models/notification_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Notification Provider
//
// Aggregates notifications from existing APIs:
//   /api/announcements     → NotifType.announcement
//   /api/tests/upcoming    → NotifType.testReminder
//
// Read state is persisted locally via shared_preferences so the badge count
// and unread indicators survive app restarts without any backend changes.
// ─────────────────────────────────────────────────────────────────────────────

class NotificationState {
  final List<AppNotification> notifications;
  final bool loading;
  final String? error;

  const NotificationState({
    this.notifications = const [],
    this.loading = false,
    this.error,
  });

  int get unreadCount => notifications.where((n) => !n.isRead).length;

  NotificationState copyWith({
    List<AppNotification>? notifications,
    bool? loading,
    String? error,
  }) =>
      NotificationState(
        notifications: notifications ?? this.notifications,
        loading: loading ?? this.loading,
        error: error,
      );
}

class NotificationNotifier extends StateNotifier<NotificationState> {
  static const _prefKey = 'sb_read_notification_ids';

  NotificationNotifier() : super(const NotificationState()) {
    refresh();
  }

  /// Reads locally-persisted read IDs from shared_preferences.
  Future<Set<String>> _loadReadIds() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_prefKey) ?? [];
    return raw.toSet();
  }

  Future<void> _saveReadIds(Set<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefKey, ids.toList());
  }

  /// Fetches all notifications from backend APIs and merges with local read state.
  Future<void> refresh() async {
    state = state.copyWith(loading: true, error: null);

    final readIds = await _loadReadIds();
    final List<AppNotification> notifs = [];

    try {
      // ── Announcements ────────────────────────────────────────────────────
      try {
        final resp = await dioClient.get(ApiEndpoints.announcements);
        final items = (resp.data as List?) ?? [];
        for (final item in items) {
          final id = 'ann_${item['_id'] ?? item['id']}';
          String ts = item['created_at'] ?? DateTime.now().toIso8601String();
          notifs.add(AppNotification(
            id: id,
            type: NotifType.announcement,
            title: item['title'] as String? ?? 'Announcement',
            body: item['body'] as String? ?? '',
            timestamp: _parseDate(ts),
            isRead: readIds.contains(id),
          ));
        }
      } catch (_) {}

      // ── Upcoming Tests → Reminders ────────────────────────────────────────
      try {
        final resp = await dioClient.get(ApiEndpoints.upcomingTests);
        final items = (resp.data as List?) ?? [];
        for (final item in items) {
          final id = 'test_${item['_id'] ?? item['id']}';
          final title = item['title'] as String? ?? 'Upcoming Test';
          final date = item['scheduled_date'] as String? ?? '';
          final time = item['start_time'] as String? ?? '';
          notifs.add(AppNotification(
            id: id,
            type: NotifType.testReminder,
            title: 'Test Reminder: $title',
            body: 'Scheduled on $date${time.isNotEmpty ? ' at $time' : ''}. Tap to view.',
            timestamp: _parseDate(
                item['created_at'] as String? ?? DateTime.now().toIso8601String()),
            isRead: readIds.contains(id),
          ));
        }
      } catch (_) {}

      // Sort: newest first
      notifs.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      state = state.copyWith(notifications: notifs, loading: false);
    } catch (e) {
      state = state.copyWith(
        loading: false,
        error: 'Failed to load notifications',
        notifications: notifs,
      );
    }
  }

  /// Marks a single notification as read and persists the change.
  Future<void> markRead(String id) async {
    final readIds = await _loadReadIds();
    readIds.add(id);
    await _saveReadIds(readIds);

    final updated = state.notifications.map((n) {
      if (n.id == id) {
        return AppNotification(
          id: n.id,
          type: n.type,
          title: n.title,
          body: n.body,
          timestamp: n.timestamp,
          isRead: true,
        );
      }
      return n;
    }).toList();

    state = state.copyWith(notifications: updated);
  }

  /// Marks all notifications as read.
  Future<void> markAllRead() async {
    final readIds = state.notifications.map((n) => n.id).toSet();
    await _saveReadIds(readIds);

    final updated = state.notifications.map((n) => AppNotification(
          id: n.id,
          type: n.type,
          title: n.title,
          body: n.body,
          timestamp: n.timestamp,
          isRead: true,
        )).toList();

    state = state.copyWith(notifications: updated);
  }

  /// Removes a notification from the local list (doesn't affect backend).
  Future<void> delete(String id) async {
    final updated = state.notifications.where((n) => n.id != id).toList();
    state = state.copyWith(notifications: updated);
    // Also remove from read IDs to keep clean
    final readIds = await _loadReadIds();
    readIds.remove(id);
    await _saveReadIds(readIds);
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  DateTime _parseDate(String s) {
    try {
      return DateTime.parse(s).toLocal();
    } catch (_) {
      return DateTime.now();
    }
  }
}

final notificationProvider =
    StateNotifierProvider<NotificationNotifier, NotificationState>(
  (ref) => NotificationNotifier(),
);
