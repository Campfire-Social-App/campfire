import 'dart:async';
import 'dart:convert';

import 'package:stream_channel/stream_channel.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// A socket the test drives by hand: it can deliver frames, and close with any
/// code the server might use.
class FakeSocket extends StreamChannelMixin<dynamic> implements WebSocketChannel {
  FakeSocket();

  final _incoming = StreamController<dynamic>();
  final sent = <String>[];
  final _sink = _FakeSink();

  int? _closeCode;
  bool readyFails = false;

  void deliver(Object frame) => _incoming.add(jsonEncode(frame));

  void closeWith(int code) {
    _closeCode = code;
    unawaited(_incoming.close());
  }

  @override
  Stream<dynamic> get stream => _incoming.stream;

  @override
  WebSocketSink get sink => _sink..owner = this;

  @override
  Future<void> get ready =>
      readyFails ? Future.error(StateError('handshake failed')) : Future.value();

  @override
  int? get closeCode => _closeCode;

  @override
  String? get closeReason => null;

  @override
  String? get protocol => null;

}

class _FakeSink implements WebSocketSink {
  FakeSocket? owner;

  @override
  void add(dynamic data) => owner?.sent.add(data as String);

  @override
  Future<void> close([int? closeCode, String? closeReason]) async {
    owner?.closeWith(closeCode ?? 1000);
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future<void> addStream(Stream<dynamic> stream) async {}

  @override
  Future<void> get done => Future.value();
}
