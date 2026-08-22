import 'dart:async';
import 'dart:convert';

import 'package:campfire/models/events.dart';
import 'package:web_socket_channel/status.dart' as ws_status;
import 'package:web_socket_channel/web_socket_channel.dart';

/// Ceiling on the reconnect backoff — a phone that has been in a tunnel for an
/// hour should still come back within half a minute of regaining signal.
const _maxBackoff = Duration(seconds: 30);
const _heartbeatInterval = Duration(seconds: 30);

/// The socket was closed by the server for a policy reason; in practice that
/// means the access token it was opened with had gone stale.
const _policyViolation = 1008;

enum GatewayStatus { disconnected, connecting, connected }

/// Port of `ws/gateway.ts`: one socket to `/gateway`, reconnecting with
/// exponential backoff, heartbeating, and handing decoded frames to whoever is
/// listening.
///
/// Unlike the React version this does not reach into application state itself —
/// it publishes [events] and the providers subscribe to the ops they care
/// about. Same dispatch, but each store owns its own reaction instead of one
/// switch owning all of them.
class GatewayClient {
  GatewayClient({
    required this.serverUrl,
    required this.accessToken,
    required this.onAuthRejected,
    WebSocketChannel Function(Uri url)? connector,
  }) : _connect = connector ?? WebSocketChannel.connect;

  final String? Function() serverUrl;
  final String? Function() accessToken;

  /// Invoked on a 1008 close so the session can be refreshed before the next
  /// attempt — otherwise the reconnect loop would keep presenting the same
  /// dead token forever.
  final Future<void> Function() onAuthRejected;

  final WebSocketChannel Function(Uri url) _connect;

  final _events = StreamController<GatewayEvent>.broadcast();
  final _status = StreamController<GatewayStatus>.broadcast();

  WebSocketChannel? _socket;
  StreamSubscription<dynamic>? _subscription;
  Timer? _heartbeat;
  Timer? _reconnect;
  int _attempt = 0;
  bool _manualDisconnect = true;

  Stream<GatewayEvent> get events => _events.stream;
  Stream<GatewayStatus> get statusChanges => _status.stream;

  GatewayStatus _current = GatewayStatus.disconnected;
  GatewayStatus get status => _current;

  void connect() {
    _manualDisconnect = false;
    _attempt = 0;
    _openSocket();
  }

  void disconnect() {
    _manualDisconnect = true;
    _reconnect?.cancel();
    _stopHeartbeat();
    unawaited(_subscription?.cancel());
    _subscription = null;
    unawaited(_socket?.sink.close(ws_status.normalClosure));
    _socket = null;
    _setStatus(GatewayStatus.disconnected);
  }

  void sendTyping(String channelId) =>
      _send({'op': 'TYPING_START', 'data': {'channel_id': channelId}});

  Future<void> dispose() async {
    disconnect();
    await _events.close();
    await _status.close();
  }

  void _setStatus(GatewayStatus status) {
    if (_current == status) return;
    _current = status;
    if (!_status.isClosed) _status.add(status);
  }

  void _send(Map<String, dynamic> payload) {
    // Guarded on the status rather than a try/catch: adding to a closed sink
    // throws a StateError, and a heartbeat firing into the gap between close
    // and reconnect is entirely routine.
    if (_current != GatewayStatus.connected) return;
    _socket?.sink.add(jsonEncode(payload));
  }

  void _openSocket() {
    final server = serverUrl();
    if (server == null) return;

    final token = accessToken();
    if (token == null) {
      // There is a session but no access token in hand: the app was reopened
      // while the server was unreachable, so `restoreSession` kept the stored
      // user and never got one (`state/auth.dart`). Recovering is the same job
      // as a 1008 — mint a token, then retry. Returning quietly instead is what
      // used to strand the shell on "Connecting…" until the app was restarted.
      unawaited(onAuthRejected().whenComplete(_scheduleReconnect));
      return;
    }

    // http -> ws, https -> wss, leaving the rest of the URL alone.
    final base = server.replaceFirst(RegExp('^http', caseSensitive: false), 'ws');
    final url = Uri.parse('$base/gateway?token=${Uri.encodeComponent(token)}');

    _setStatus(GatewayStatus.connecting);

    final WebSocketChannel socket;
    try {
      socket = _connect(url);
    } on Object {
      _scheduleReconnect();
      return;
    }
    _socket = socket;

    _subscription = socket.stream.listen(
      _onFrame,
      onError: (Object _) {
        // The close handler below does the reconnecting; an error is always
        // followed by a done.
      },
      onDone: () => _onClosed(socket.closeCode),
      cancelOnError: false,
    );

    unawaited(
      socket.ready.then((_) {
        _attempt = 0;
        _setStatus(GatewayStatus.connected);
        _startHeartbeat();
      }).catchError((Object _) {
        // `ready` rejecting means the handshake failed; `onDone` follows.
      }),
    );
  }

  void _onFrame(dynamic raw) {
    if (raw is! String) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return;
      _events.add(GatewayEvent.fromFrame(decoded));
    } on FormatException {
      // Malformed frame — drop it rather than tearing the socket down.
    }
    // A known op whose payload no longer matches the model throws a TypeError
    // out of the generated `fromJson`. Deliberately caught: one bad frame must
    // not cost the connection, which is the containment `GatewayEvent.fromFrame`
    // documents as the caller's job.
    // ignore: avoid_catching_errors
    on TypeError {
      // Dropped.
    }
  }

  void _onClosed(int? code) {
    _stopHeartbeat();
    _setStatus(GatewayStatus.disconnected);
    if (_manualDisconnect) return;

    if (code == _policyViolation) {
      // Refresh first, then retry — reconnecting with the same stale token
      // would just be rejected again.
      unawaited(onAuthRejected().whenComplete(_scheduleReconnect));
      return;
    }
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_manualDisconnect) return;
    final millis = 1000 * (1 << _attempt.clamp(0, 5));
    final delay = Duration(milliseconds: millis.clamp(1000, _maxBackoff.inMilliseconds));
    _attempt++;
    _reconnect?.cancel();
    _reconnect = Timer(delay, _openSocket);
  }

  void _startHeartbeat() {
    _stopHeartbeat();
    _heartbeat = Timer.periodic(_heartbeatInterval, (_) => _send({'op': 'HEARTBEAT'}));
  }

  void _stopHeartbeat() {
    _heartbeat?.cancel();
    _heartbeat = null;
  }
}
