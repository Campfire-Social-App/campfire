/// Everything the API layer throws, so callers never have to know that `dio` is
/// underneath. Mirrors `ApiError` in the React client.
class ApiException implements Exception {
  const ApiException(this.statusCode, this.message);

  /// Transport failures (no network, DNS, TLS, timeout) carry no HTTP status.
  const ApiException.network(this.message) : statusCode = 0;

  /// 0 when the request never reached the server.
  final int statusCode;
  final String message;

  bool get isNetworkFailure => statusCode == 0;
  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() => 'ApiException($statusCode): $message';
}
