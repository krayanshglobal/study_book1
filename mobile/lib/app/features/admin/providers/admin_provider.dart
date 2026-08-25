import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/models/question_model.dart';
import '../../../core/models/test_model.dart';
import '../../../core/models/video_model.dart';
import '../../../core/models/plan_model.dart';
import '../../../core/models/announcement_model.dart';
import '../../../core/models/user_model.dart';
import '../../auth/providers/auth_provider.dart';

class AdminState {
  final List<QuestionModel> questions;
  final List<TestModel> tests;
  final List<VideoModel> videos;
  final List<PlanModel> plans;
  final List<AnnouncementModel> announcements;
  final List<UserModel> users;
  final bool isLoading;
  final String? error;

  AdminState({
    this.questions = const [],
    this.tests = const [],
    this.videos = const [],
    this.plans = const [],
    this.announcements = const [],
    this.users = const [],
    this.isLoading = false,
    this.error,
  });

  AdminState copyWith({
    List<QuestionModel>? questions,
    List<TestModel>? tests,
    List<VideoModel>? videos,
    List<PlanModel>? plans,
    List<AnnouncementModel>? announcements,
    List<UserModel>? users,
    bool? isLoading,
    String? error,
  }) {
    return AdminState(
      questions: questions ?? this.questions,
      tests: tests ?? this.tests,
      videos: videos ?? this.videos,
      plans: plans ?? this.plans,
      announcements: announcements ?? this.announcements,
      users: users ?? this.users,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class AdminNotifier extends StateNotifier<AdminState> {
  final Ref ref;

  AdminNotifier(this.ref) : super(AdminState());

  // Questions
  Future<void> loadQuestions() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final dio = ref.read(dioClientProvider);
      final res = await dio.get(ApiEndpoints.questions);
      final items = (res.data['items'] as List? ?? [])
          .map((e) => QuestionModel.fromJson(e))
          .toList();
      state = state.copyWith(questions: items, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> createQuestion(Map<String, dynamic> data) async {
    try {
      final dio = ref.read(dioClientProvider);
      await dio.post(ApiEndpoints.questions, data: data);
      await loadQuestions();
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> deleteQuestion(String id) async {
    try {
      final dio = ref.read(dioClientProvider);
      await dio.delete('${ApiEndpoints.questions}/$id');
      await loadQuestions();
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  // Tests
  Future<void> loadTests() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final dio = ref.read(dioClientProvider);
      final res = await dio.get(ApiEndpoints.tests);
      final items = (res.data['items'] as List? ?? [])
          .map((e) => TestModel.fromJson(e))
          .toList();
      state = state.copyWith(tests: items, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> createTest(Map<String, dynamic> data) async {
    try {
      final dio = ref.read(dioClientProvider);
      await dio.post(ApiEndpoints.tests, data: data);
      await loadTests();
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> deleteTest(String id) async {
    try {
      final dio = ref.read(dioClientProvider);
      await dio.delete('${ApiEndpoints.tests}/$id');
      await loadTests();
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  // Videos
  Future<void> loadVideos() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final dio = ref.read(dioClientProvider);
      final res = await dio.get(ApiEndpoints.videos);
      final items = (res.data['items'] as List? ?? [])
          .map((e) => VideoModel.fromJson(e))
          .toList();
      state = state.copyWith(videos: items, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> createVideo(Map<String, dynamic> data) async {
    try {
      final dio = ref.read(dioClientProvider);
      await dio.post(ApiEndpoints.videos, data: data);
      await loadVideos();
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> deleteVideo(String id) async {
    try {
      final dio = ref.read(dioClientProvider);
      await dio.delete('${ApiEndpoints.videos}/$id');
      await loadVideos();
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  // Plans
  Future<void> loadPlans() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final dio = ref.read(dioClientProvider);
      final res = await dio.get(ApiEndpoints.adminPlans);
      final items = (res.data['items'] as List? ?? [])
          .map((e) => PlanModel.fromJson(e))
          .toList();
      state = state.copyWith(plans: items, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> createPlan(Map<String, dynamic> data) async {
    try {
      final dio = ref.read(dioClientProvider);
      await dio.post(ApiEndpoints.adminPlans, data: data);
      await loadPlans();
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> deletePlan(String id) async {
    try {
      final dio = ref.read(dioClientProvider);
      await dio.delete('${ApiEndpoints.adminPlans}/$id');
      await loadPlans();
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  // Announcements
  Future<void> loadAnnouncements() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final dio = ref.read(dioClientProvider);
      final res = await dio.get(ApiEndpoints.announcements);
      final items = (res.data['items'] as List? ?? [])
          .map((e) => AnnouncementModel.fromJson(e))
          .toList();
      state = state.copyWith(announcements: items, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> createAnnouncement(Map<String, dynamic> data) async {
    try {
      final dio = ref.read(dioClientProvider);
      await dio.post(ApiEndpoints.announcements, data: data);
      await loadAnnouncements();
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  // Users
  Future<void> loadUsers() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final dio = ref.read(dioClientProvider);
      final res = await dio.get(ApiEndpoints.adminUsers);
      final items = (res.data['items'] as List? ?? [])
          .map((e) => UserModel.fromJson(e))
          .toList();
      state = state.copyWith(users: items, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> updateUserRole(String id, String role) async {
    try {
      final dio = ref.read(dioClientProvider);
      await dio.put('${ApiEndpoints.adminUsers}/$id/role', data: {'role': role});
      await loadUsers();
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }
}

final adminProvider = StateNotifierProvider<AdminNotifier, AdminState>((ref) {
  return AdminNotifier(ref);
});

/// Single source of truth for selected class across Admin & SuperAdmin dashboards
final selectedAdminClassProvider = StateProvider<String>((ref) => '8');

