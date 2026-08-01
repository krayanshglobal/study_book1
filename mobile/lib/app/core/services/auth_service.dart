import '../api/dio_client.dart';
import '../api/api_endpoints.dart';
import '../models/user_model.dart';

class AuthService {
  // Uses the global dioClient (cookie-based)
  Future<UserModel> getCurrentUser() async {
    final resp = await dioClient.get(ApiEndpoints.me);
    return UserModel.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<UserModel> login(String email, String password) async {
    final resp = await dioClient.post(
      ApiEndpoints.login,
      data: {'email': email, 'password': password},
    );
    return UserModel.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<UserModel> register({
    required String name,
    required String email,
    required String phone,
    required String password,
    String? classLevel,
    String? referralCode,
  }) async {
    final body = <String, dynamic>{
      'name': name,
      'email': email,
      'phone': phone,
      'password': password,
    };
    if (classLevel != null) body['class_level'] = classLevel;
    if (referralCode != null && referralCode.isNotEmpty) body['referral_code'] = referralCode;

    final resp = await dioClient.post(ApiEndpoints.register, data: body);
    return UserModel.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<void> logout() async {
    try {
      await dioClient.post(ApiEndpoints.logout);
    } catch (_) {}
    await dioClient.clearCookies();
  }

  Future<void> forgotPassword(String email) async {
    await dioClient.post(ApiEndpoints.forgotPassword, data: {'email': email});
  }

  /// Extracts error message from DioException, matching React's formatApiError()
  static String formatError(Object e) => formatApiError(e);
}
