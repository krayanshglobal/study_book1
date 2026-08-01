class PromoModel {
  final String id;
  final String title;
  final String subtitle;
  final String code;
  final int countdownHours;
  final bool isActive;
  final String? createdAt;

  PromoModel({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.code,
    required this.countdownHours,
    this.isActive = true,
    this.createdAt,
  });

  factory PromoModel.fromJson(Map<String, dynamic> json) {
    return PromoModel(
      id: json['_id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      subtitle: json['subtitle']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      countdownHours: (json['countdown_hours'] as num?)?.toInt() ?? 24,
      isActive: json['is_active'] == true,
      createdAt: json['created_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        '_id': id,
        'title': title,
        'subtitle': subtitle,
        'code': code,
        'countdown_hours': countdownHours,
        'is_active': isActive,
        'created_at': createdAt,
      };

  /// Returns remaining duration from creation time, or Duration.zero if expired.
  Duration remainingTime() {
    if (createdAt == null) return Duration.zero;
    try {
      final end = DateTime.parse(createdAt!).toUtc().add(Duration(hours: countdownHours));
      final diff = end.difference(DateTime.now().toUtc());
      return diff.isNegative ? Duration.zero : diff;
    } catch (_) {
      return Duration.zero;
    }
  }
}
