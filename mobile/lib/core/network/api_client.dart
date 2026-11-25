import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:lms/core/config/app_config.dart';
import 'package:lms/core/network/api_exception.dart';

enum CircuitState { closed, open, halfOpen }

class CircuitBreaker {
  CircuitBreaker({
    this.failureThreshold = 10,
    this.resetTimeout = const Duration(seconds: 15),
  });

  final int failureThreshold;
  final Duration resetTimeout;

  CircuitState state = CircuitState.closed;
  int _failureCount = 0;
  DateTime? _lastStateChange;

  Future<T> execute<T>(Future<T> Function() action) async {
    if (state == CircuitState.open) {
      if (_lastStateChange != null &&
          DateTime.now().difference(_lastStateChange!) > resetTimeout) {
        state = CircuitState.halfOpen;
      } else {
        throw ApiException('Service temporarily unavailable due to server instability. Please try again shortly.', statusCode: 503);
      }
    }

    try {
      final result = await action();
      _onSuccess();
      return result;
    } catch (e) {
      // Only count actual 5xx Server Errors for CircuitBreaker tripping.
      // Client-side offline network/DNS errors should NOT trip the server circuit breaker.
      if (e is ApiException && e.statusCode != null && e.statusCode! >= 500) {
        _onFailure();
      }
      rethrow;
    }
  }

  void _onSuccess() {
    _failureCount = 0;
    if (state == CircuitState.halfOpen) {
      state = CircuitState.closed;
    }
  }

  void _onFailure() {
    _failureCount++;
    if (_failureCount >= failureThreshold || state == CircuitState.halfOpen) {
      state = CircuitState.open;
      _lastStateChange = DateTime.now();
    }
  }
}

class ApiClient {
  ApiClient({Dio? dio})
      : _dio = dio ?? Dio(),
        _circuitBreaker = CircuitBreaker() {
    _dio.options = BaseOptions(
      baseUrl: AppConfig.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 12),
      sendTimeout: const Duration(seconds: 10),
      headers: const {'Content-Type': 'application/json'},
    );

    if (kDebugMode) {
      _dio.interceptors.add(LogInterceptor(
        request: true,
        requestHeader: true,
        requestBody: true,
        responseHeader: false,
        responseBody: true,
        error: true,
        logPrint: (object) => debugPrint(object.toString()),
      ));
    }
  }

  final Dio _dio;
  final CircuitBreaker _circuitBreaker;

  /// Called when an authenticated request is rejected with 401 (e.g. the
  /// account was signed in on another device). Wired by [AuthRepository] so
  /// every feature gets the same session-expiry handling without each repo
  /// checking status codes.
  void Function()? onSessionExpired;

  void _notifyIfSessionExpired(DioException error) {
    // Only requests that carried a bearer token: a 401 on login/OTP calls
    // just means wrong credentials, not an ended session.
    final auth = error.requestOptions.headers['Authorization'];
    if (error.response?.statusCode == 401 && auth != null) {
      onSessionExpired?.call();
    }
  }

  Future<Map<String, dynamic>> get(
    String path, {
    String? token,
    Map<String, dynamic>? queryParameters,
  }) async {
    return _circuitBreaker.execute(() async {
      try {
        final response = await _dio.get<Map<String, dynamic>>(
          path,
          queryParameters: queryParameters,
          options: _options(token),
        );
        return response.data ?? <String, dynamic>{};
      } on DioException catch (error) {
        _notifyIfSessionExpired(error);
        throw _mapError(error);
      }
    });
  }

  /// Download a binary file (e.g. a PDF receipt). Error bodies are still
  /// JSON, so they are decoded to give the server's message.
  Future<Uint8List> getBytes(String path, {String? token}) async {
    return _circuitBreaker.execute(() async {
      try {
        final options = _options(token)
          ..responseType = ResponseType.bytes
          ..receiveTimeout = const Duration(seconds: 60);
        final response = await _dio.get<List<int>>(path, options: options);
        return Uint8List.fromList(response.data ?? const <int>[]);
      } on DioException catch (error) {
        final raw = error.response?.data;
        if (raw is List<int>) {
          try {
            error.response!.data = jsonDecode(utf8.decode(raw));
          } catch (_) {
            error.response!.data = null;
          }
        }
        _notifyIfSessionExpired(error);
        throw _mapError(error);
      }
    });
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Object? data,
    String? token,
  }) async {
    return _circuitBreaker.execute(() async {
      try {
        final response = await _dio.post<Map<String, dynamic>>(
          path,
          data: data,
          options: _options(token),
        );
        return response.data ?? <String, dynamic>{};
      } on DioException catch (error) {
        _notifyIfSessionExpired(error);
        throw _mapError(error);
      }
    });
  }

  Future<Map<String, dynamic>> put(
    String path, {
    Object? data,
    String? token,
  }) async {
    return _circuitBreaker.execute(() async {
      try {
        final response = await _dio.put<Map<String, dynamic>>(
          path,
          data: data,
          options: _options(token),
        );
        return response.data ?? <String, dynamic>{};
      } on DioException catch (error) {
        _notifyIfSessionExpired(error);
        throw _mapError(error);
      }
    });
  }

  Future<Map<String, dynamic>> delete(
    String path, {
    Object? data,
    String? token,
  }) async {
    return _circuitBreaker.execute(() async {
      try {
        final response = await _dio.delete<Map<String, dynamic>>(
          path,
          data: data,
          options: _options(token),
        );
        return response.data ?? <String, dynamic>{};
      } on DioException catch (error) {
        _notifyIfSessionExpired(error);
        throw _mapError(error);
      }
    });
  }

  Options _options(String? token) {
    final headers = <String, dynamic>{};
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return Options(headers: headers);
  }

  ApiException _mapError(DioException error) {
    final errStr = error.error?.toString() ?? '';
    if (error.type == DioExceptionType.connectionError ||
        errStr.contains('SocketException') ||
        errStr.contains('Failed host lookup')) {
      return ApiException(
        'Unable to connect to server. Please check your internet connection.',
        statusCode: null,
      );
    }

    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return ApiException(
        'Connection timed out. Please try again.',
        statusCode: null,
      );
    }

    final data = error.response?.data;
    if (data is Map<String, dynamic>) {
      final message = data['message']?.toString();
      if (message != null && message.isNotEmpty) {
        return ApiException(message, statusCode: error.response?.statusCode);
      }
    }

    return ApiException(
      error.message ?? 'Something went wrong',
      statusCode: error.response?.statusCode,
    );
  }
}
