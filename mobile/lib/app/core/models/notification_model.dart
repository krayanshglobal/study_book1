/// Notification model for the in-app notification feed.
///
/// Notifications are aggregated client-side from:
/// - /api/announcements  (type: announcement)
/// - /api/tests/upcoming (type: testReminder)
library;

enum NotifType {
  announcement,
  testReminder,
  newQuestions,
  offer,
  premiumActivated,
  premiumExpired,
  referralReward,
  missedTest,
}

extension NotifTypeX on NotifType {
  String get label {
    switch (this) {
      case NotifType.announcement:     return 'Announcement';
      case NotifType.testReminder:     return 'Test Reminder';
      case NotifType.newQuestions:     return 'New Questions';
      case NotifType.offer:            return 'Offer';
      case NotifType.premiumActivated: return 'Premium Activated';
      case NotifType.premiumExpired:   return 'Premium Expired';
      case NotifType.referralReward:   return 'Referral Reward';
      case NotifType.missedTest:       return 'Missed Test';
    }
  }

  /// Route to navigate to when the notification is tapped (logged-in context).
  String get route {
    switch (this) {
      case NotifType.announcement:     return '/dashboard';
      case NotifType.testReminder:     return '/tests';
      case NotifType.missedTest:       return '/tests';
      case NotifType.newQuestions:     return '/questions';
      case NotifType.offer:            return '/dashboard';
      case NotifType.premiumActivated: return '/profile';
      case NotifType.premiumExpired:   return '/pricing';
      case NotifType.referralReward:   return '/referrals';
    }
  }

  bool get isPremium {
    return this == NotifType.premiumActivated ||
        this == NotifType.premiumExpired ||
        this == NotifType.offer;
  }
}

class AppNotification {
  final String id;
  final NotifType type;
  final String title;
  final String body;
  final DateTime timestamp;
  bool isRead;

  AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.timestamp,
    this.isRead = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'title': title,
        'body': body,
        'timestamp': timestamp.toIso8601String(),
        'isRead': isRead,
      };

  factory AppNotification.fromJson(Map<String, dynamic> j) {
    final typeStr = j['type'] as String? ?? 'announcement';
    final type = NotifType.values.firstWhere(
      (t) => t.name == typeStr,
      orElse: () => NotifType.announcement,
    );
    return AppNotification(
      id: j['id'] as String,
      type: type,
      title: j['title'] as String,
      body: j['body'] as String,
      timestamp: DateTime.parse(j['timestamp'] as String),
      isRead: j['isRead'] as bool? ?? false,
    );
  }
}
