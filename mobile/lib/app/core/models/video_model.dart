class VideoModel {
  final String id;
  final String title;
  final String description;
  final String url;
  final String? thumbnailUrl;
  final String subject;
  final String classLevel;
  final String topic;
  final bool premiumOnly;
  final String? createdAt;

  VideoModel({
    required this.id,
    required this.title,
    this.description = '',
    required this.url,
    this.thumbnailUrl,
    this.subject = 'maths',
    required this.classLevel,
    this.topic = '',
    this.premiumOnly = false,
    this.createdAt,
  });

  factory VideoModel.fromJson(Map<String, dynamic> json) {
    return VideoModel(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      url: json['url']?.toString() ?? '',
      thumbnailUrl: json['thumbnail_url']?.toString(),
      subject: json['subject']?.toString() ?? 'maths',
      classLevel: json['class_level']?.toString() ?? '10',
      topic: json['topic']?.toString() ?? '',
      premiumOnly: json['premium_only'] == true,
      createdAt: json['created_at']?.toString(),
    );
  }
}
