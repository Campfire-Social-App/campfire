import 'package:campfire/models/channel.dart';
import 'package:campfire/models/events.dart';
import 'package:campfire/state/gateway.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The server's text and voice channels, ordered the way the server orders
/// them. Populated by READY and kept current by the `CHANNEL_*` ops — never
/// fetched over REST at boot, per PLANO_FLUTTER.md §6.
class ChannelsNotifier extends Notifier<List<Channel>> {
  @override
  List<Channel> build() {
    listenToGateway(ref, _apply);
    return const [];
  }

  void _apply(GatewayEvent event) {
    switch (event) {
      case ReadyEvent(:final data):
        state = _sorted(data.channels);
      case ChannelCreateEvent(:final channel) || ChannelUpdateEvent(:final channel):
        final without = state.where((c) => c.id != channel.id);
        state = _sorted([...without, channel]);
      case ChannelDeleteEvent(:final data):
        state = state.where((c) => c.id != data.id).toList();
      case _:
        break;
    }
  }

  List<Channel> _sorted(List<Channel> channels) {
    // `position` is what the admin dragged; name only decides ties, so two
    // channels at the same position do not swap places between frames.
    return [...channels]..sort((a, b) {
        final byPosition = a.position.compareTo(b.position);
        return byPosition != 0 ? byPosition : a.name.compareTo(b.name);
      });
  }
}

final channelsProvider =
    NotifierProvider<ChannelsNotifier, List<Channel>>(ChannelsNotifier.new);

final textChannelsProvider = Provider<List<Channel>>(
  (ref) => ref.watch(channelsProvider).where((c) => c.type == ChannelType.text).toList(),
);

final voiceChannelsProvider = Provider<List<Channel>>(
  (ref) => ref.watch(channelsProvider).where((c) => c.type == ChannelType.voice).toList(),
);

/// Which channel the chat pane is showing. Null until the first one is picked.
final selectedChannelIdProvider = NotifierProvider<SelectedChannelNotifier, String?>(
  SelectedChannelNotifier.new,
);

class SelectedChannelNotifier extends Notifier<String?> {
  @override
  String? build() {
    // Not `watch`: a new channel arriving must not reset what the user is
    // reading. The listener reconciles instead, and only when it has to.
    ref.listen(channelsProvider, (_, channels) => state = _pick(channels, state));
    return _pick(ref.read(channelsProvider), null);
  }

  String? get selected => state;

  set selected(String? channelId) => state = channelId;

  /// Keeps a channel on screen whenever there is one to show: the first text
  /// channel at boot (what `setChannels` does in `state/channels.ts`), and a
  /// fresh pick when the open channel is deleted out from under us.
  String? _pick(List<Channel> channels, String? current) {
    if (channels.isEmpty) return null;
    if (current != null && channels.any((c) => c.id == current)) return current;

    for (final channel in channels) {
      if (channel.type == ChannelType.text) return channel.id;
    }
    return channels.first.id;
  }
}
