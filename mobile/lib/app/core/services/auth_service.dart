import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../api/dio_client.dart';
import '../api/api_endpoints.dart';
import '../models/user_model.dart';
import 'storage_service.dart';
import 'firebase_phone_auth_service.dart';

class AuthService {
  final FirebasePhoneAuthService _firebasePhoneAuth =
      FirebasePhoneAuthService();
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
    // Check the application backend before consuming an SMS request. Both
    // login and registration require the backend after Firebase verifies the
    // code, so continuing while it is unavailable would strand the user on
    // the OTP screen.
    final response = await dioClient.post(
      ApiEndpoints.mobileAccountStatus,
      data: {'phone': phone},
    );
    await _firebasePhoneAuth.sendOtp(phone);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> verifyOtpForRegistration({
    required String phone,
    required String otp,
  }) async {
    final idToken = await _firebasePhoneAuth.verifyOtp(otp);
    final resp = await dioClient.post(
      ApiEndpoints.firebasePhoneAuth,
      data: {
        'id_token': idToken,
        'verification_only': true,
      },
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
    final idToken = await _firebasePhoneAuth.verifyOtp(otp);
    final body = <String, dynamic>{
      'id_token': idToken,
    };
    if (name != null && name.isNotEmpty) body['name'] = name;
    if (classLevel != null && classLevel.isNotEmpty) body['class_level'] = classLevel;
    if (referralCode != null && referralCode.isNotEmpty) body['referral_code'] = referralCode;

    final resp = await dioClient.post(ApiEndpoints.firebasePhoneAuth, data: body);
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
  static String formatError(Object e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'invalid-phone-number':
          return 'Enter a valid mobile number.';
        case 'invalid-verification-code':
          return 'The OTP code is incorrect.';
        case 'too-many-requests':
          return 'Too many OTP requests. Please try again later.';
        case 'quota-exceeded':
          return 'The OTP service quota has been reached. Please try later.';
        case 'session-expired':
          return 'The OTP has expired. Please request a new code.';
        case 'web-context-cancelled':
          return 'Phone verification was cancelled.';
        default:
          return e.message ?? 'Firebase phone verification failed.';
      }
    }
    if (e is FormatException || e is StateError || e is TimeoutException) {
      return e.toString().replaceFirst(RegExp(r'^[^:]+:\s*'), '');
    }
    if (e is DioException) {
      final path = e.requestOptions.path;
      final isMobileOtpBackend = path.contains('/api/auth/mobile/');
      if (isMobileOtpBackend && e.response?.statusCode == 404) {
        return 'Mobile OTP login is not available on the backend yet. '
            'Deploy the updated backend and try again.';
      }
      if (isMobileOtpBackend &&
          (e.type == DioExceptionType.connectionError ||
              e.type == DioExceptionType.connectionTimeout ||
              e.type == DioExceptionType.receiveTimeout)) {
        return 'Unable to connect to the login server. Check your internet '
            'connection and try again.';
      }
    }
    return formatApiError(e);
  }
}
