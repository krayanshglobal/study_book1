class FlashcardModel {
  final String id;
  final String subject;
  final String classLevel;
  final String topic;
  final String front;
  final String back;

  FlashcardModel({
    required this.id,
    required this.subject,
    required this.classLevel,
    required this.topic,
    required this.front,
    required this.back,
  });

  factory FlashcardModel.fromJson(Map<String, dynamic> json) {
    return FlashcardModel(
      id: json['_id']?.toString() ?? '',
      subject: json['subject']?.toString() ?? '',
      classLevel: json['class_level']?.toString() ?? '',
      topic: json['topic']?.toString() ?? '',
      front: json['front']?.toString() ?? '',
      back: json['back']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        '_id': id,
        'subject': subject,
        'class_level': classLevel,
        'topic': topic,
        'front': front,
        'back': back,
      };
}
