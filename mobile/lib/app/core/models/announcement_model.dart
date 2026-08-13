class AnnouncementModel {
  final String id;
  final String title;
  final String body;
  final String audience;
  final bool active;
  final String? createdAt;

  AnnouncementModel({
    required this.id,
    required this.title,
    required this.body,
    this.audience = 'all',
    this.active = true,
    this.createdAt,
  });

  factory AnnouncementModel.fromJson(Map<String, dynamic> json) {
    return AnnouncementModel(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      audience: json['audience']?.toString() ?? 'all',
      active: json['active'] != false,
      createdAt: json['created_at']?.toString(),
    );
  }
}
