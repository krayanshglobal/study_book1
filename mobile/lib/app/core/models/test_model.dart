
class TestModel {
  final String id;
  final String title;
  final String description;
  final String testType; // "mock", "final"
  final String classLevel;
  final String subject;
  final String scheduledDate;
  final String startTime;
  final String endTime;
  final int durationMinutes;
  final bool negativeMarking;
  final List<String> questionIds;
  final bool isPublished;
  final double? unlockScoreRequired;
  final String? prerequisiteTestId;
  final bool premiumOnly;

  // Student specific flags attached by API
  final double? myScore;
  final String? myAttemptId;
  final bool locked;
  final bool premiumLocked;

  TestModel({
    required this.id,
    required this.title,
    this.description = '',
    this.testType = 'mock',
    required this.classLevel,
    this.subject = 'maths',
    required this.scheduledDate,
    this.startTime = '20:00',
    this.endTime = '21:00',
    this.durationMinutes = 60,
    this.negativeMarking = true,
    this.questionIds = const [],
    this.isPublished = false,
    this.unlockScoreRequired,
    this.prerequisiteTestId,
    this.premiumOnly = false,
    this.myScore,
    this.myAttemptId,
    this.locked = false,
    this.premiumLocked = false,
  });

  factory TestModel.fromJson(Map<String, dynamic> json) {
    return TestModel(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      testType: json['test_type']?.toString() ?? 'mock',
      classLevel: json['class_level']?.toString() ?? '10',
      subject: json['subject']?.toString() ?? 'maths',
      scheduledDate: json['scheduled_date']?.toString() ?? '',
      startTime: json['start_time']?.toString() ?? '20:00',
      endTime: json['end_time']?.toString() ?? '21:00',
      durationMinutes: (json['duration_minutes'] as num?)?.toInt() ?? 60,
      negativeMarking: json['negative_marking'] != false,
      questionIds: (json['question_ids'] as List?)?.map((e) => e.toString()).toList() ?? [],
      isPublished: json['is_published'] == true,
      unlockScoreRequired: (json['unlock_score_required'] as num?)?.toDouble(),
      prerequisiteTestId: json['prerequisite_test_id']?.toString(),
      premiumOnly: json['premium_only'] == true,
      myScore: (json['my_score'] as num?)?.toDouble(),
      myAttemptId: json['my_attempt_id']?.toString(),
      locked: json['locked'] == true,
      premiumLocked: json['premium_locked'] == true,
    );
  }
}

class TestAttemptResult {
  final String attemptId;
  final String testId;
  final double score;
  final double percent;
  final int totalQuestions;
  final int correctCount;
  final int incorrectCount;
  final int unansweredCount;
  final String? submittedAt;

  TestAttemptResult({
    required this.attemptId,
    required this.testId,
    required this.score,
    required this.percent,
    required this.totalQuestions,
    required this.correctCount,
    required this.incorrectCount,
    required this.unansweredCount,
    this.submittedAt,
  });

  factory TestAttemptResult.fromJson(Map<String, dynamic> json) {
    return TestAttemptResult(
      attemptId: json['attempt_id']?.toString() ?? json['_id']?.toString() ?? '',
      testId: json['test_id']?.toString() ?? '',
      score: (json['score'] as num?)?.toDouble() ?? 0.0,
      percent: (json['percent'] as num?)?.toDouble() ?? 0.0,
      totalQuestions: (json['total_questions'] as num?)?.toInt() ?? 0,
      correctCount: (json['correct_count'] as num?)?.toInt() ?? 0,
      incorrectCount: (json['incorrect_count'] as num?)?.toInt() ?? 0,
      unansweredCount: (json['unanswered'] as num?)?.toInt() ?? 0,
      submittedAt: json['submitted_at']?.toString(),
    );
  }
}
