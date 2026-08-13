class QuestionOption {
  final String label;
  final String text;

  QuestionOption({required this.label, required this.text});

  factory QuestionOption.fromJson(Map<String, dynamic> json) {
    return QuestionOption(
      label: json['label']?.toString() ?? '',
      text: json['text']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {'label': label, 'text': text};
}

class QuestionModel {
  final String id;
  final String subject;
  final String classLevel;
  final String topic;
  final String questionText;
  final String qType; // "mcq" or "typed"
  final List<QuestionOption>? options;
  final int? correctIndex;
  final String? correctAnswerText;
  final String? explanation;
  final double positiveMarks;
  final double negativeMarks;
  final String difficulty;
  final String? imageUrl;
  final String? createdBy;
  final String? createdAt;

  QuestionModel({
    required this.id,
    this.subject = 'maths',
    required this.classLevel,
    required this.topic,
    required this.questionText,
    this.qType = 'mcq',
    this.options,
    this.correctIndex,
    this.correctAnswerText,
    this.explanation,
    this.positiveMarks = 1.0,
    this.negativeMarks = 0.25,
    this.difficulty = 'medium',
    this.imageUrl,
    this.createdBy,
    this.createdAt,
  });

  factory QuestionModel.fromJson(Map<String, dynamic> json) {
    return QuestionModel(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      subject: json['subject']?.toString() ?? 'maths',
      classLevel: json['class_level']?.toString() ?? '10',
      topic: json['topic']?.toString() ?? '',
      questionText: json['question_text']?.toString() ?? '',
      qType: json['q_type']?.toString() ?? 'mcq',
      options: json['options'] != null
          ? (json['options'] as List)
              .map((e) => QuestionOption.fromJson(e as Map<String, dynamic>))
              .toList()
          : null,
      correctIndex: (json['correct_index'] as num?)?.toInt(),
      correctAnswerText: json['correct_answer_text']?.toString(),
      explanation: json['explanation']?.toString(),
      positiveMarks: (json['positive_marks'] as num?)?.toDouble() ?? 1.0,
      negativeMarks: (json['negative_marks'] as num?)?.toDouble() ?? 0.25,
      difficulty: json['difficulty']?.toString() ?? 'medium',
      imageUrl: json['image_url']?.toString(),
      createdBy: json['created_by']?.toString(),
      createdAt: json['created_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'subject': subject,
      'class_level': classLevel,
      'topic': topic,
      'question_text': questionText,
      'q_type': qType,
      'options': options?.map((e) => e.toJson()).toList(),
      'correct_index': correctIndex,
      'correct_answer_text': correctAnswerText,
      'explanation': explanation,
      'positive_marks': positiveMarks,
      'negative_marks': negativeMarks,
      'difficulty': difficulty,
      'image_url': imageUrl,
      'created_by': createdBy,
      'created_at': createdAt,
    };
  }
}
