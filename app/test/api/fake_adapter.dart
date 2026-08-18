import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

/// Stands in for the network so the client's behaviour can be tested without
/// one. Records every request in order, and answers from a handler the test
/// supplies.
class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.handle);

  /// Given a request, produces the status and JSON body to answer with.
  final FutureOr<(int status, Object? body)> Function(RequestOptions request) handle;

  final List<RequestOptions> requests = [];

  List<String> get paths => requests.map((r) => r.path).toList();

  int countOf(String path) => requests.where((r) => r.path.endsWith(path)).length;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final (status, body) = await handle(options);
    return ResponseBody.fromString(
      body == null ? '' : jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
