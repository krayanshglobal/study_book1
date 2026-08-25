import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/dio_client.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/storage_service.dart';

final dioClientProvider = Provider<DioClient>((ref) => dioClient);

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

class AuthState {
  final UserModel? user;
  final bool isLoading;
  final String? error;

  const AuthState({this.user, this.isLoading = false, this.error});

  AuthState copyWith({UserModel? user, bool? isLoading, String? error, bool clearUser = false}) {
    return AuthState(
      user: clearUser ? null : (user ?? this.user),
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  bool get isAuthenticated => user != null;
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthService _authService;

  AuthNotifier(this._authService) : super(const AuthState(isLoading: true)) {
    dioClient.onUnauthorized = () {
      StorageService.clearSession();
      state = const AuthState(user: null, isLoading: false);
    };
    checkAuthStatus();
  }

  Future<void> checkAuthStatus() async {
    // 1. Instantly restore saved user from secure storage if present
    final savedUser = await StorageService.getSavedUser();
    if (savedUser != null) {
      state = AuthState(user: savedUser, isLoading: false);
    } else {
      state = state.copyWith(isLoading: true, error: null);
    }

    // 2. Validate session against backend in background
    try {
      final freshUser = await _authService.getCurrentUser();
      state = AuthState(user: freshUser, isLoading: false);
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 401) {
        // Genuine 401 Unauthorized & refresh failed -> clear session
        await StorageService.clearSession();
        state = const AuthState(user: null, isLoading: false);
      } else {
        // Network error / offline -> keep saved user logged in
        if (savedUser != null) {
          state = AuthState(user: savedUser, isLoading: false);
        } else {
          state = const AuthState(user: null, isLoading: false);
        }
      }
    }
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final user = await _authService.login(email, password);
      state = AuthState(user: user, isLoading: false);
      return true;
    } catch (e) {
      state = AuthState(isLoading: false, error: AuthService.formatError(e));
      return false;
    }
  }

  Future<bool> loginWithGoogle(
    String idToken, {
    String? classLevel,
    String? referralCode,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final user = await _authService.loginWithGoogle(
        idToken,
        classLevel: classLevel,
        referralCode: referralCode,
      );
      state = AuthState(user: user, isLoading: false);
      return true;
    } catch (e) {
      state = AuthState(isLoading: false, error: AuthService.formatError(e));
      return false;
    }
  }

  Future<Map<String, dynamic>?> sendMobileOtp(String phone) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final res = await _authService.sendMobileOtp(phone);
      state = state.copyWith(isLoading: false);
      return res;
    } catch (e) {
      state = AuthState(isLoading: false, error: AuthService.formatError(e));
      return null;
    }
  }

  Future<Map<String, dynamic>?> verifyOtpForRegistration({
    required String phone,
    required String otp,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final res = await _authService.verifyOtpForRegistration(phone: phone, otp: otp);
      state = state.copyWith(isLoading: false);
      return res;
    } catch (e) {
      state = AuthState(isLoading: false, error: AuthService.formatError(e));
      return null;
    }
  }

  Future<bool> verifyMobileOtp({
    required String phone,
    required String otp,
    String? name,
    String? classLevel,
    String? referralCode,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final user = await _authService.verifyMobileOtp(
        phone: phone,
        otp: otp,
        name: name,
        classLevel: classLevel,
        referralCode: referralCode,
      );
      state = AuthState(user: user, isLoading: false);
      return true;
    } catch (e) {
      state = AuthState(isLoading: false, error: AuthService.formatError(e));
      return false;
    }
  }

  Future<bool> register({
    required String name,
    required String email,
    required String phone,
    required String password,
    String? classLevel,
    String? referralCode,
    String? verificationToken,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final user = await _authService.register(
        name: name,
        email: email,
        phone: phone,
        password: password,
        classLevel: classLevel,
        referralCode: referralCode,
        verificationToken: verificationToken,
      );
      state = AuthState(user: user, isLoading: false);
      return true;
    } catch (e) {
      state = AuthState(isLoading: false, error: AuthService.formatError(e));
      return false;
    }
  }

  Future<void> logout() async {
    await _authService.logout();
    await StorageService.clearSession();
    state = const AuthState(user: null, isLoading: false);
  }

  Future<void> refresh() => checkAuthStatus();

  Future<void> refreshSilently() async {
    if (!state.isAuthenticated) return;
    try {
      final user = await _authService.getCurrentUser();
      if (state.isAuthenticated) {
        state = state.copyWith(user: user, error: null);
      }
    } catch (_) {
      // Network hiccup — keep existing cached user
    }
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.watch(authServiceProvider));
});
