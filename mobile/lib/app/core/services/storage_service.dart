import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';

class StorageService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      resetOnError: true,
    ),
  );

  static const _keyUser = 'user_session';
  static const _keyAccessToken = 'access_token';
  static const _keyRefreshToken = 'refresh_token';

  static Future<void> saveSession({
    required UserModel user,
    String? accessToken,
    String? refreshToken,
  }) async {
    try {
      final userMap = user.toJson();
      final jsonStr = jsonEncode(userMap);

      // 1. Save user session to SharedPreferences for reliable fallback
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_keyUser, jsonStr);
      } catch (e) {
        debugPrint('SharedPreferences write error: $e');
      }

      // 2. Save session and tokens to encrypted secure storage
      try {
        await _storage.write(key: _keyUser, value: jsonStr);
        if (accessToken != null && accessToken.isNotEmpty) {
          await _storage.write(key: _keyAccessToken, value: accessToken);
        }
        if (refreshToken != null && refreshToken.isNotEmpty) {
          await _storage.write(key: _keyRefreshToken, value: refreshToken);
        }
      } catch (e) {
        debugPrint('FlutterSecureStorage write error: $e');
      }
    } catch (e) {
      debugPrint('StorageService.saveSession general error: $e');
    }
  }

  static Future<UserModel?> getSavedUser() async {
    try {
      // Try FlutterSecureStorage first
      String? jsonStr;
      try {
        jsonStr = await _storage.read(key: _keyUser);
      } catch (_) {}

      // Fallback to SharedPreferences if null
      if (jsonStr == null || jsonStr.isEmpty) {
        try {
          final prefs = await SharedPreferences.getInstance();
          jsonStr = prefs.getString(_keyUser);
        } catch (_) {}
      }

      if (jsonStr == null || jsonStr.isEmpty) return null;
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      return UserModel.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  static Future<String?> getAccessToken() async {
    try {
      return await _storage.read(key: _keyAccessToken);
    } catch (_) {
      return null;
    }
  }

  static Future<String?> getRefreshToken() async {
    try {
      return await _storage.read(key: _keyRefreshToken);
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveTokens({String? accessToken, String? refreshToken}) async {
    try {
      if (accessToken != null && accessToken.isNotEmpty) {
        await _storage.write(key: _keyAccessToken, value: accessToken);
      }
      if (refreshToken != null && refreshToken.isNotEmpty) {
        await _storage.write(key: _keyRefreshToken, value: refreshToken);
      }
    } catch (e) {
      debugPrint('saveTokens error: $e');
    }
  }

  static Future<void> clearSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyUser);
    } catch (_) {}
    try {
      await _storage.delete(key: _keyUser);
      await _storage.delete(key: _keyAccessToken);
      await _storage.delete(key: _keyRefreshToken);
    } catch (_) {}
  }
}
