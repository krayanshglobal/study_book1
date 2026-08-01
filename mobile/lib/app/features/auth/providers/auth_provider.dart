import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/dio_client.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/auth_service.dart';

final dioClientProvider = Provider<DioClient>((ref) => dioClient);

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

// Three-state: loading=true/user=null → loading; loading=false/user!=null → logged in; loading=false/user=null → logged out
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
      state = const AuthState(user: null, isLoading: false);
    };
    checkAuthStatus();
  }

  Future<void> checkAuthStatus() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final user = await _authService.getCurrentUser();
      state = AuthState(user: user, isLoading: false);
    } catch (_) {
      state = const AuthState(user: null, isLoading: false);
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

  Future<bool> register({
    required String name,
    required String email,
    required String phone,
    required String password,
    String? classLevel,
    String? referralCode,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final user = await _authService.register(
        name: name, email: email, phone: phone, password: password,
        classLevel: classLevel, referralCode: referralCode,
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
    state = const AuthState(user: null, isLoading: false);
  }

  Future<void> refresh() => checkAuthStatus();

  /// Silently fetches the latest user profile from the server and updates
  /// [state.user] WITHOUT touching [isLoading]. This means any screen that
  /// is already displaying content will not flash a loading spinner, but
  /// all widgets watching [authProvider] will automatically rebuild with the
  /// latest subscription/plan data the moment the response arrives.
  Future<void> refreshSilently() async {
    if (!state.isAuthenticated) return;
    try {
      final user = await _authService.getCurrentUser();
      if (state.isAuthenticated) {
        state = state.copyWith(user: user, error: null);
      }
    } catch (_) {
      // Network hiccup — keep existing cached user, do not sign out.
    }
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.watch(authServiceProvider));
});
