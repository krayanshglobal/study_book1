import 'package:flutter/foundation.dart';
import '../api/dio_client.dart';
import '../api/api_endpoints.dart';
import '../models/user_model.dart';
import 'storage_service.dart';

class AuthService {
  // Uses the global dioClient (cookie & bearer token enabled)
  Future<UserModel> getCurrentUser() async {
    final resp = await dioClient.get(ApiEndpoints.me);
    final user = UserModel.fromJson(resp.data as Map<String, dynamic>);
    final accessToken = resp.data['access_token']?.toString();
    final refreshToken = resp.data['refresh_token']?.toString();
    await StorageService.saveSession(
      user: user,
      accessToken: accessToken,
      refreshToken: refreshToken,
    );
    return user;
  }

  Future<UserModel> login(String email, String password) async {
    final resp = await dioClient.post(
      ApiEndpoints.login,
      data: {'email': email, 'password': password},
    );
    final user = UserModel.fromJson(resp.data as Map<String, dynamic>);
    final accessToken = resp.data['access_token']?.toString();
    final refreshToken = resp.data['refresh_token']?.toString();
    
    debugPrint('[AUTH DIAGNOSTICS] Login success for user: ${user.email}, role: ${user.role}');
    await StorageService.saveSession(
      user: user,
      accessToken: accessToken,
      refreshToken: refreshToken,
    );
    return user;
  }

  Future<UserModel> loginWithGoogle(
    String idToken, {
    String? classLevel,
    String? referralCode,
  }) async {
    final body = <String, dynamic>{'id_token': idToken};
    if (classLevel != null) body['class_level'] = classLevel;
    if (referralCode != null && referralCode.isNotEmpty) {
      body['referral_code'] = referralCode;
    }

    final resp = await dioClient.post(ApiEndpoints.googleLogin, data: body);
    final user = UserModel.fromJson(resp.data as Map<String, dynamic>);
    final accessToken = resp.data['access_token']?.toString();
    final refreshToken = resp.data['refresh_token']?.toString();

    debugPrint('[AUTH DIAGNOSTICS] Google login success for user: ${user.email}, role: ${user.role}');
    await StorageService.saveSession(
      user: user,
      accessToken: accessToken,
      refreshToken: refreshToken,
    );
    return user;
  }

  Future<Map<String, dynamic>> sendMobileOtp(String phone) async {
    final resp = await dioClient.post(
      ApiEndpoints.mobileSendOtp,
      data: {'phone': phone},
    );
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> verifyOtpForRegistration({
    required String phone,
    required String otp,
  }) async {
    final resp = await dioClient.post(
      ApiEndpoints.mobileVerifyOtp,
      data: {'phone': phone, 'otp': otp},
    );
    return resp.data as Map<String, dynamic>;
  }

  Future<UserModel> verifyMobileOtp({
    required String phone,
    required String otp,
    String? name,
    String? classLevel,
    String? referralCode,
  }) async {
    final body = <String, dynamic>{
      'phone': phone,
      'otp': otp,
    };
    if (name != null && name.isNotEmpty) body['name'] = name;
    if (classLevel != null && classLevel.isNotEmpty) body['class_level'] = classLevel;
    if (referralCode != null && referralCode.isNotEmpty) body['referral_code'] = referralCode;

    final resp = await dioClient.post(ApiEndpoints.mobileVerifyOtp, data: body);
    final user = UserModel.fromJson(resp.data as Map<String, dynamic>);
    final accessToken = resp.data['access_token']?.toString();
    final refreshToken = resp.data['refresh_token']?.toString();

    debugPrint('[AUTH DIAGNOSTICS] Mobile OTP verify success for user: ${user.email}, role: ${user.role}');
    await StorageService.saveSession(
      user: user,
      accessToken: accessToken,
      refreshToken: refreshToken,
    );
    return user;
  }

  Future<UserModel> register({
    required String name,
    required String email,
    required String phone,
    required String password,
    String? classLevel,
    String? referralCode,
    String? verificationToken,
  }) async {
    final body = <String, dynamic>{
      'name': name,
      'email': email,
      'phone': phone,
      'password': password,
    };
    if (classLevel != null) body['class_level'] = classLevel;
    if (referralCode != null && referralCode.isNotEmpty) body['referral_code'] = referralCode;
    if (verificationToken != null && verificationToken.isNotEmpty) body['verification_token'] = verificationToken;

    final resp = await dioClient.post(ApiEndpoints.register, data: body);
    final user = UserModel.fromJson(resp.data as Map<String, dynamic>);
    final accessToken = resp.data['access_token']?.toString();
    final refreshToken = resp.data['refresh_token']?.toString();

    debugPrint('[AUTH DIAGNOSTICS] Registration success for user: ${user.email}, role: ${user.role}');
    await StorageService.saveSession(
      user: user,
      accessToken: accessToken,
      refreshToken: refreshToken,
    );
    return user;
  }

  Future<void> logout() async {
    try {
      await dioClient.post(ApiEndpoints.logout);
    } catch (_) {}
    await StorageService.clearSession();
    await dioClient.clearCookies();
  }

  Future<void> forgotPassword(String email) async {
    await dioClient.post(ApiEndpoints.forgotPassword, data: {'email': email});
  }

  /// Extracts error message from DioException, matching React's formatApiError()
  static String formatError(Object e) => formatApiError(e);
}
