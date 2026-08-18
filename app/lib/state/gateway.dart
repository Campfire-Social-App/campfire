import 'package:campfire/models/events.dart';
import 'package:campfire/state/api.dart';
import 'package:campfire/state/auth.dart';
import 'package:campfire/state/settings.dart';
import 'package:campfire/ws/gateway.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final gatewayProvider = Provider<GatewayClient>((ref) {
  final client = GatewayClient(
    serverUrl: () => ref.read(settingsProvider).serverUrl,
    accessToken: () => ref.read(tokenHolderProvider).accessToken,
    // A 1008 close means the token the socket was opened with had expired.
    // Restoring the session mints a new one before the retry.
    onAuthRejected: () => ref.read(authProvider.notifier).restoreSession(),
  );
  ref.onDispose(client.dispose);
  return client;
});

/// Subscribes [onEvent] to the gateway for as long as the calling provider
/// lives. Each state provider takes the ops it owns and ignores the rest —
/// the same dispatch the React client does in one switch, split up so no store
/// can quietly depend on another's ordering.
void listenToGateway(Ref ref, void Function(GatewayEvent event) onEvent) {
  final subscription = ref.watch(gatewayProvider).events.listen(onEvent);
  ref.onDispose(subscription.cancel);
}

final gatewayStatusProvider = StreamProvider<GatewayStatus>(
  (ref) => ref.watch(gatewayProvider).statusChanges,
);

/// Opens the socket once there is a session and closes it when there is not.
/// Something on screen has to watch this for it to stay alive — the shell does.
final gatewayLifecycleProvider = Provider<void>((ref) {
  final client = ref.watch(gatewayProvider);

  ref.listen<AuthState>(
    authProvider,
    (_, next) {
      if (next is AuthAuthenticated) {
        client.connect();
      } else {
        client.disconnect();
      }
    },
    fireImmediately: true,
  );
});
