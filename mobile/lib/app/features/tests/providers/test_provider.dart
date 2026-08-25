import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/models/question_model.dart';
import '../../../core/models/test_model.dart';
import '../../auth/providers/auth_provider.dart';

class TestListState {
  final List<TestModel> tests;
  final bool isLoading;
  final String? error;

  TestListState({this.tests = const [], this.isLoading = false, this.error});
}

class TestListNotifier extends StateNotifier<TestListState> {
  final Ref ref;

  TestListNotifier(this.ref) : super(TestListState(isLoading: true)) {
    loadTests();
  }

  Future<void> loadTests() async {
    state = TestListState(isLoading: true);
    try {
      final dio = ref.read(dioClientProvider);
      final res = await dio.get(ApiEndpoints.tests);
      final items = (res.data['items'] as List? ?? [])
          .map((e) => TestModel.fromJson(e))
          .toList();
      state = TestListState(tests: items, isLoading: false);
    } catch (e) {
      state = TestListState(isLoading: false, error: e.toString());
    }
  }
}

final testListProvider = StateNotifierProvider<TestListNotifier, TestListState>((ref) {
  return TestListNotifier(ref);
});

// Live Test Attempt Controller
class LiveTestState {
  final String? attemptId;
  final TestModel? test;
  final List<QuestionModel> questions;
  final Map<String, dynamic> userAnswers; // questionId -> selectedIndex or typedAnswer
  final String? deadlineAt;
  final bool isLoading;
  final bool isSubmitting;
  final TestAttemptResult? submissionResult;
  final String? error;

  LiveTestState({
    this.attemptId,
    this.test,
    this.questions = const [],
    this.userAnswers = const {},
    this.deadlineAt,
    this.isLoading = false,
    this.isSubmitting = false,
    this.submissionResult,
    this.error,
  });

  LiveTestState copyWith({
    String? attemptId,
    TestModel? test,
    List<QuestionModel>? questions,
    Map<String, dynamic>? userAnswers,
    String? deadlineAt,
    bool? isLoading,
    bool? isSubmitting,
    TestAttemptResult? submissionResult,
    String? error,
  }) {
    return LiveTestState(
      attemptId: attemptId ?? this.attemptId,
      test: test ?? this.test,
      questions: questions ?? this.questions,
      userAnswers: userAnswers ?? this.userAnswers,
      deadlineAt: deadlineAt ?? this.deadlineAt,
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      submissionResult: submissionResult ?? this.submissionResult,
      error: error,
    );
  }
}

class LiveTestNotifier extends StateNotifier<LiveTestState> {
  final Ref ref;

  LiveTestNotifier(this.ref) : super(LiveTestState());

  Future<void> startTest(String testId) async {
    state = LiveTestState(isLoading: true);
    try {
      final dio = ref.read(dioClientProvider);
      final res = await dio.post(ApiEndpoints.startTest(testId));
      
      final testData = TestModel.fromJson(res.data['test']);
      final qList = (res.data['questions'] as List? ?? [])
          .map((e) => QuestionModel.fromJson(e))
          .toList();

      state = LiveTestState(
        attemptId: res.data['attempt_id']?.toString(),
        test: testData,
        questions: qList,
        deadlineAt: res.data['deadline_at']?.toString(),
        isLoading: false,
      );
    } catch (e) {
      state = LiveTestState(isLoading: false, error: e.toString());
    }
  }

  void updateAnswer(String questionId, dynamic answer) {
    final updated = Map<String, dynamic>.from(state.userAnswers);
    updated[questionId] = answer;
    state = state.copyWith(userAnswers: updated);
  }

  Future<bool> submitTest() async {
    if (state.test == null) return false;
    state = state.copyWith(isSubmitting: true, error: null);
    try {
      final dio = ref.read(dioClientProvider);
      final answersList = <Map<String, dynamic>>[];
      
      for (final q in state.questions) {
        final val = state.userAnswers[q.id];
        if (q.qType == 'mcq') {
          answersList.add({
            'question_id': q.id,
            'selected_index': val is int ? val : null,
          });
        } else {
          answersList.add({
            'question_id': q.id,
            'typed_answer': val is String ? val : null,
          });
        }
      }

      final res = await dio.post(
        ApiEndpoints.submitTest(state.test!.id),
        data: {'answers': answersList},
      );

      final result = TestAttemptResult.fromJson(res.data);
      state = state.copyWith(
        isSubmitting: false,
        submissionResult: result,
      );
      return true;
    } catch (e) {
      state = state.copyWith(isSubmitting: false, error: e.toString());
      return false;
    }
  }
}

final liveTestProvider = StateNotifierProvider<LiveTestNotifier, LiveTestState>((ref) {
  return LiveTestNotifier(ref);
});
