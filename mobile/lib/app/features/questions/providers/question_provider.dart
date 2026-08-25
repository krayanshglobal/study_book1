import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/models/question_model.dart';
import '../../auth/providers/auth_provider.dart';

class QuestionBankState {
  final List<QuestionModel> questions;
  final List<Map<String, dynamic>> topics;
  final String? selectedClass;
  final String? selectedTopic;
  final bool isLoading;
  final String? error;

  QuestionBankState({
    this.questions = const [],
    this.topics = const [],
    this.selectedClass,
    this.selectedTopic,
    this.isLoading = false,
    this.error,
  });

  QuestionBankState copyWith({
    List<QuestionModel>? questions,
    List<Map<String, dynamic>>? topics,
    String? selectedClass,
    String? selectedTopic,
    bool? isLoading,
    String? error,
  }) {
    return QuestionBankState(
      questions: questions ?? this.questions,
      topics: topics ?? this.topics,
      selectedClass: selectedClass ?? this.selectedClass,
      selectedTopic: selectedTopic ?? this.selectedTopic,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class QuestionBankNotifier extends StateNotifier<QuestionBankState> {
  final Ref ref;

  QuestionBankNotifier(this.ref) : super(QuestionBankState(isLoading: true)) {
    loadQuestions();
    loadTopics();
  }

  Future<void> loadQuestions({String? classLevel, String? topic}) async {
    state = state.copyWith(
      isLoading: true,
      error: null,
      selectedClass: classLevel,
      selectedTopic: topic,
    );
    try {
      final dio = ref.read(dioClientProvider);
      final query = <String, dynamic>{};
      if (classLevel != null && classLevel.isNotEmpty) query['class_level'] = classLevel;
      if (topic != null && topic.isNotEmpty) query['topic'] = topic;

      final res = await dio.get(ApiEndpoints.questions, queryParameters: query);
      final items = (res.data['items'] as List? ?? [])
          .map((e) => QuestionModel.fromJson(e))
          .toList();

      state = state.copyWith(questions: items, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadTopics() async {
    try {
      final dio = ref.read(dioClientProvider);
      final res = await dio.get(ApiEndpoints.topics);
      final topicsList = (res.data['topics'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      state = state.copyWith(topics: topicsList);
    } catch (_) {}
  }

  Future<Map<String, dynamic>> checkAnswer(String qid, {int? selectedIndex, String? typedAnswer}) async {
    final dio = ref.read(dioClientProvider);
    final res = await dio.post(
      ApiEndpoints.checkQuestion(qid),
      data: {
        if (selectedIndex != null) 'selected_index': selectedIndex,
        if (typedAnswer != null) 'typed_answer': typedAnswer,
      },
    );
    return Map<String, dynamic>.from(res.data);
  }
}

final questionBankProvider = StateNotifierProvider<QuestionBankNotifier, QuestionBankState>((ref) {
  return QuestionBankNotifier(ref);
});
