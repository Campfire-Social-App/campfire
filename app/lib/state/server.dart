import 'package:campfire/models/events.dart';
import 'package:campfire/models/server.dart';
import 'package:campfire/state/gateway.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Name, icon and upload ceiling of the deployment. Comes down in READY; the
/// client uses [ServerSettings.maxUploadBytes] to turn away an oversized file
/// before spending an upload on it.
class ServerNotifier extends Notifier<ServerSettings?> {
  @override
  ServerSettings? build() {
    listenToGateway(ref, (event) {
      if (event case ReadyEvent(:final data)) state = data.server;
    });
    return null;
  }
}

final serverProvider = NotifierProvider<ServerNotifier, ServerSettings?>(ServerNotifier.new);
