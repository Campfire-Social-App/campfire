import 'dart:async';

import 'package:campfire/api/api_exception.dart';
import 'package:campfire/api/token_holder.dart';
import 'package:dio/dio.dart';

/// Marks a request that must not carry a Bearer header — login, register and
/// refresh have no session yet.
const _anonymousKey = 'campfire.anonymous';

/// Marks a request that has already been retried after a refresh, so a second
/// 401 gives up instead of looping.
const _retriedKey = 'campfire.retried';

/// The HTTP side of the client. Port of `api/client.ts`, with the two things
/// that file needed `fetch` plus `XMLHttpRequest` to do — a queued token
/// refresh and upload progress — both handled by dio.
class ApiClient {
  ApiClient({
    required this.tokens,
    required this.serverUrl,
    required this.onSessionExpired,
    Dio? dio,
    Dio? refreshDio,
  })  : _dio = dio ?? Dio(),
        _refreshDio = refreshDio ?? Dio() {
    _dio.interceptors.add(
      InterceptorsWrapper(onRequest: _onRequest, onError: _onError),
    );
  }

  final TokenHolder tokens;

  /// Read on every request rather than captured once: the user can switch
  /// servers without this client being rebuilt.
  final String? Function() serverUrl;

  /// Called when the refresh itself is rejected — the session is gone and the
  /// auth provider has to drop it.
  final Future<void> Function() onSessionExpired;

  final Dio _dio;

  /// Refreshing goes out on its own Dio with no interceptors — the same reason
  /// `refreshAccessToken` in the React client calls `fetch` directly instead of
  /// going back through `apiFetch`: otherwise a 401 on the refresh would try to
  /// refresh again, forever.
  final Dio _refreshDio;

  /// The in-flight refresh, if there is one. Every 401 that arrives while it is
  /// pending awaits *this* future rather than starting its own — N parallel
  /// requests must produce one refresh, not N. More than one would race, and
  /// the loser would be holding a token the server has already rotated away.
  Future<String>? _refreshing;

  String get baseUrl {
    final url = serverUrl();
    if (url == null || url.isEmpty) {
      throw const ApiException(0, 'No server configured');
    }
    return url;
  }

  /// Joins a server-relative attachment path onto the configured server, so the
  /// same message renders on any deployment. Absolute URLs pass through.
  String resolveAssetUrl(String path) {
    if (RegExp('^https?://', caseSensitive: false).hasMatch(path)) return path;
    return '$baseUrl$path';
  }

  void _onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.baseUrl = baseUrl;

    if (options.extra[_anonymousKey] != true) {
      final token = tokens.accessToken;
      if (token != null) options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  Future<void> _onError(DioException error, ErrorInterceptorHandler handler) async {
    final request = error.requestOptions;
    final canRetry = error.response?.statusCode == 401 &&
        request.extra[_anonymousKey] != true &&
        request.extra[_retriedKey] != true &&
        tokens.hasSession;

    if (!canRetry) {
      handler.next(error);
      return;
    }

    final String token;
    try {
      token = await _refreshAccessToken();
    } on ApiException {
      // The session is already cleared by the refresh; surface the original
      // 401 rather than the refresh's, which the caller never asked for.
      handler.next(error);
      return;
    }

    request.extra[_retriedKey] = true;
    request.headers['Authorization'] = 'Bearer $token';
    try {
      handler.resolve(await _dio.fetch<dynamic>(request));
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }

  Future<String> _refreshAccessToken() {
    // `??=` is the whole single-flight mechanism: the first 401 installs the
    // future, everyone else awaits it, and it is torn down once settled so the
    // next expiry starts a fresh one.
    return _refreshing ??= _performRefresh().whenComplete(() {
      _refreshing = null;
    });
  }

  Future<String> _performRefresh() async {
    final refreshToken = tokens.refreshToken;
    if (refreshToken == null) {
      throw const ApiException(401, 'No session to refresh');
    }

    try {
      final response = await _refreshDio.post<Map<String, dynamic>>(
        '$baseUrl/api/auth/refresh',
        data: {'refresh_token': refreshToken},
      );
      final token = response.data?['access_token'] as String?;
      if (token == null) throw const ApiException(500, 'Refresh returned no token');
      tokens.accessToken = token;
      return token;
    } on DioException catch (error) {
      await onSessionExpired();
      throw _toApiException(error);
    }
  }

  Future<T> request<T>(
    String path, {
    String method = 'GET',
    Object? body,
    Map<String, dynamic>? query,
    bool anonymous = false,
    T Function(dynamic json)? decode,
  }) async {
    try {
      final response = await _dio.request<dynamic>(
        path,
        data: body,
        queryParameters: query,
        options: Options(
          method: method,
          extra: {if (anonymous) _anonymousKey: true},
        ),
      );
      return _decodeBody<T>(response.data, decode);
    } on DioException catch (error) {
      throw _toApiException(error);
    }
  }

  /// Multipart upload with byte-level progress, which a 25MB video very much
  /// needs.
  Future<T> upload<T>(
    String path,
    String filePath, {
    required T Function(dynamic json) decode,
    String? filename,
    void Function(double fraction)? onProgress,
    CancelToken? cancelToken,
  }) async {
    try {
      final form = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath, filename: filename),
      });
      final response = await _dio.post<dynamic>(
        path,
        data: form,
        cancelToken: cancelToken,
        onSendProgress: (sent, total) {
          if (total > 0) onProgress?.call(sent / total);
        },
      );
      return _decodeBody<T>(response.data, decode);
    } on DioException catch (error) {
      throw _toApiException(error);
    }
  }

  T _decodeBody<T>(dynamic data, T Function(dynamic json)? decode) {
    // 204, and the endpoints that return nothing, decode to void.
    if (decode == null) return null as T;
    return decode(data);
  }

  ApiException _toApiException(DioException error) {
    // An interceptor that threw (no server configured, say) is wrapped by dio;
    // unwrap it so the caller gets the real reason instead of a generic
    // "couldn't reach the server".
    final cause = error.error;
    if (cause is ApiException) return cause;

    final status = error.response?.statusCode;
    if (status == null) {
      return ApiException.network(
        switch (error.type) {
          DioExceptionType.connectionTimeout ||
          DioExceptionType.sendTimeout ||
          DioExceptionType.receiveTimeout =>
            'The server took too long to respond',
          DioExceptionType.cancel => 'Request cancelled',
          _ => "Couldn't reach the server",
        },
      );
    }

    // FastAPI puts the human-readable reason in `detail`; falling back to the
    // status line loses the "Invalid username or password" the user needs.
    final data = error.response?.data;
    final detail = data is Map ? data['detail'] : null;
    return ApiException(
      status,
      detail is String ? detail : (error.response?.statusMessage ?? 'Error $status'),
    );
  }
}
