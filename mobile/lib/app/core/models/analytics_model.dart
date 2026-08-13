class TopicAccuracy {
  final String topic;
  final double accuracy;
  final int questions;

  TopicAccuracy({required this.topic, required this.accuracy, required this.questions});

  factory TopicAccuracy.fromJson(Map<String, dynamic> json) {
    return TopicAccuracy(
      topic: json['topic']?.toString() ?? 'General',
      accuracy: (json['accuracy'] as num?)?.toDouble() ?? 0.0,
      questions: (json['questions'] as num?)?.toInt() ?? 0,
    );
  }
}

class RecentScore {
  final String title;
  final double percent;
  final String date;

  RecentScore({required this.title, required this.percent, required this.date});

  factory RecentScore.fromJson(Map<String, dynamic> json) {
    return RecentScore(
      title: json['title']?.toString() ?? 'Test',
      percent: (json['percent'] as num?)?.toDouble() ?? 0.0,
      date: json['date']?.toString() ?? '',
    );
  }
}

class StudentAnalyticsModel {
  final double overallAccuracy;
  final int totalAttempts;
  final int totalPoints;
  final List<TopicAccuracy> topics;
  final List<TopicAccuracy> strengths;
  final List<TopicAccuracy> weaknesses;
  final List<RecentScore> recentScores;

  StudentAnalyticsModel({
    required this.overallAccuracy,
    required this.totalAttempts,
    required this.totalPoints,
    required this.topics,
    required this.strengths,
    required this.weaknesses,
    required this.recentScores,
  });

  factory StudentAnalyticsModel.fromJson(Map<String, dynamic> json) {
    return StudentAnalyticsModel(
      overallAccuracy: (json['overall_accuracy'] as num?)?.toDouble() ?? 0.0,
      totalAttempts: (json['total_attempts'] as num?)?.toInt() ?? 0,
      totalPoints: (json['total_points'] as num?)?.toInt() ?? 0,
      topics: (json['topics'] as List?)?.map((e) => TopicAccuracy.fromJson(e)).toList() ?? [],
      strengths: (json['strengths'] as List?)?.map((e) => TopicAccuracy.fromJson(e)).toList() ?? [],
      weaknesses: (json['weaknesses'] as List?)?.map((e) => TopicAccuracy.fromJson(e)).toList() ?? [],
      recentScores: (json['recent_scores'] as List?)?.map((e) => RecentScore.fromJson(e)).toList() ?? [],
    );
  }
}
