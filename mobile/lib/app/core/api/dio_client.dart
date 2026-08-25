import 'package:dio/dio.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../config/app_config.dart';
import '../services/storage_service.dart';

late DioClient dioClient;

final dioClientProvider = Provider<DioClient>((ref) => dioClient);

/// Callback signature when a 401 Unauthorized is returned by the server
typedef UnauthorizedCallback = void Function();

/// Formats FastAPI error responses exactly like the React website's formatApiError()
String formatApiError(dynamic err) {
  if (err is DioException) {
    final detail = err.response?.data?['detail'];
    if (detail == null) return err.message ?? 'Something went wrong.';
    if (detail is String) return detail;
    if (detail is List) {
      return detail
          .map((e) => e is Map && e['msg'] is String ? e['msg'] : e.toString())
          .join(' ');
    }
    if (detail is Map && detail['msg'] is String) return detail['msg'];
    return detail.toString();
  }
  return err?.toString() ?? 'Something went wrong.';
}

class DioClient {
  late final Dio dio;
  late final PersistCookieJar _cookieJar;
  UnauthorizedCallback? onUnauthorized;

  DioClient._internal(this.dio, this._cookieJar);

  /// Must be called once at app startup (after path_provider is ready)
  static Future<DioClient> create() async {
    final appDir = await getApplicationDocumentsDirectory();
    final cookieJar = PersistCookieJar(
      storage: FileStorage('${appDir.path}/.cookies/'),
      ignoreExpires: true,
    );

    final dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.baseUrl,
        connectTimeout: const Duration(milliseconds: AppConfig.connectTimeoutMs),
        receiveTimeout: const Duration(milliseconds: AppConfig.receiveTimeoutMs),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // Cookie manager — persists cookies across launches
    dio.interceptors.add(CookieManager(cookieJar));

    final client = DioClient._internal(dio, cookieJar);

    // Request & 401 Refresh Interceptor
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await StorageService.getAccessToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (error, handler) async {
          if (error.response?.statusCode == 401) {
            final path = error.requestOptions.path;
            final isAuthCheck = path.contains('/login') ||
                path.contains('/register') ||
                path.contains('/refresh');

            if (!isAuthCheck) {
              // Attempt to refresh access token using saved refresh token
              final refreshToken = await StorageService.getRefreshToken();
              if (refreshToken != null && refreshToken.isNotEmpty) {
                try {
                  final refreshDio = Dio(
                    BaseOptions(
                      baseUrl: AppConfig.baseUrl,
                      connectTimeout: const Duration(seconds: 10),
                      receiveTimeout: const Duration(seconds: 10),
                    ),
                  );

                  final refreshResp = await refreshDio.post(
                    '/api/auth/refresh',
                    data: {'refresh_token': refreshToken},
                    options: Options(
                      headers: {'Authorization': 'Bearer $refreshToken'},
                    ),
                  );

                  if (refreshResp.statusCode == 200) {
                    final newAccess = refreshResp.data['access_token']?.toString();
                    final newRefresh = refreshResp.data['refresh_token']?.toString();

                    if (newAccess != null && newAccess.isNotEmpty) {
                      await StorageService.saveTokens(
                        accessToken: newAccess,
                        refreshToken: newRefresh ?? refreshToken,
                      );

                      // Retry the original request with new access token
                      error.requestOptions.headers['Authorization'] = 'Bearer $newAccess';
                      final clonedRequest = await dio.fetch(error.requestOptions);
                      return handler.resolve(clonedRequest);
                    }
                  }
                } catch (e) {
                  debugPrint('Token refresh failed: $e');
                }
              }

              // Genuinely unauthenticated / expired -> clear session & trigger logout callback
              await StorageService.clearSession();
              await client.clearCookies();
              client.onUnauthorized?.call();
            }
          }
          return handler.next(error);
        },
      ),
    );

    return client;
  }

  Future<void> clearCookies() async {
    await _cookieJar.deleteAll();
  }

  Future<Response> get(String path, {Map<String, dynamic>? queryParameters, Options? options}) async {
    return await dio.get(path, queryParameters: queryParameters, options: options);
  }

  Future<Response> post(String path, {dynamic data, Map<String, dynamic>? queryParameters, Options? options}) async {
    return await dio.post(path, data: data, queryParameters: queryParameters, options: options);
  }

  Future<Response> put(String path, {dynamic data, Map<String, dynamic>? queryParameters}) async {
    return await dio.put(path, data: data, queryParameters: queryParameters);
  }

  Future<Response> patch(String path, {dynamic data, Map<String, dynamic>? queryParameters}) async {
    return await dio.patch(path, data: data, queryParameters: queryParameters);
  }

  Future<Response> delete(String path, {Map<String, dynamic>? queryParameters}) async {
    return await dio.delete(path, queryParameters: queryParameters);
  }
}
