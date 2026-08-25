class NoteModel {
  final String id;
  final String title;
  final String content;
  final String subject;
  final String classLevel;
  final String topic;
  final bool premiumOnly;
  final String? createdAt;

  NoteModel({
    required this.id,
    required this.title,
    required this.content,
    required this.subject,
    required this.classLevel,
    required this.topic,
    this.premiumOnly = false,
    this.createdAt,
  });

  factory NoteModel.fromJson(Map<String, dynamic> json) {
    return NoteModel(
      id: json['_id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      subject: json['subject']?.toString() ?? '',
      classLevel: json['class_level']?.toString() ?? '',
      topic: json['topic']?.toString() ?? '',
      premiumOnly: json['premium_only'] == true,
      createdAt: json['created_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        '_id': id,
        'title': title,
        'content': content,
        'subject': subject,
        'class_level': classLevel,
        'topic': topic,
        'premium_only': premiumOnly,
        'created_at': createdAt,
      };
}
