import 'package:campfire/core/secure_store.dart';
import 'package:campfire/core/server_url.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Which server this install talks to. Port of `state/settings.ts`.
///
/// [loaded] exists so the router can tell "we have not read the keystore yet"
/// apart from "there is no server saved" — without it, the app would flash the
/// connect screen on every cold start before the stored URL arrived.
class SettingsState {
  const SettingsState({this.serverUrl, this.loaded = false});

  final String? serverUrl;
  final bool loaded;

  bool get hasServer => serverUrl != null;
}

class SettingsNotifier extends Notifier<SettingsState> {
  Future<void> _ready = Future<void>.value();

  /// Completes once the keystore has been read, whether or not it had anything
  /// in it. Tests await this instead of pumping the event queue and hoping.
  Future<void> get ready => _ready;

  @override
  SettingsState build() {
    _ready = _load();
    return const SettingsState();
  }

  SessionStore get _store => ref.read(sessionStoreProvider);

  Future<void> _load() async {
    String? url;
    try {
      url = await _store.readServerUrl();
    } on Object catch (error, stackTrace) {
      // A keystore that will not open (locked device, a platform channel that
      // is not there) must not strand the app on the splash screen forever.
      // Treating it as "nothing stored" costs the user one reconnect screen;
      // never flipping `loaded` costs them the app.
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'campfire',
          context: ErrorDescription('reading the stored server URL'),
        ),
      );
    }
    state = SettingsState(serverUrl: url, loaded: true);
  }

  /// Normalises before storing, so everything downstream — the API base URL,
  /// the gateway's `ws://` rewrite — can concatenate without thinking.
  Future<void> setServerUrl(String url) async {
    final normalized = normalizeServerUrl(url);
    await _store.writeServerUrl(normalized);
    state = SettingsState(serverUrl: normalized, loaded: true);
  }

  Future<void> clearServerUrl() async {
    await _store.clearServerUrl();
    state = const SettingsState(loaded: true);
  }
}

final settingsProvider =
    NotifierProvider<SettingsNotifier, SettingsState>(SettingsNotifier.new);
