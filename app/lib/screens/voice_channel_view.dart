import 'package:campfire/livekit/voice.dart';
import 'package:campfire/models/channel.dart';
import 'package:campfire/state/voice.dart';
import 'package:campfire/theme/icons.dart';
import 'package:campfire/theme/tokens.dart';
import 'package:campfire/widgets/call_stage.dart';
import 'package:campfire/widgets/call_tiles.dart';
import 'package:campfire/widgets/voice_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A voice channel's pane: who is in the room, and the controls for being in it.
///
/// Port of `VoiceChannelView.tsx`, with the Discord phone arrangement the plan
/// calls for — the tiles fill the screen and the controls sit on a panel at the
/// bottom, in thumb reach, instead of in the header.
class VoiceChannelView extends ConsumerStatefulWidget {
  const VoiceChannelView({required this.channel, super.key});

  final Channel channel;

  @override
  ConsumerState<VoiceChannelView> createState() => _VoiceChannelViewState();
}

class _VoiceChannelViewState extends ConsumerState<VoiceChannelView> {
  Future<void> _join() async {
    try {
      await ref.read(voiceSessionProvider).join(widget.channel.id);
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_joinFailure(error))),
      );
    }
  }

  String _joinFailure(Object error) => switch (error) {
        // The server's own words when it turns a join away (not a member of the
        // DM, channel gone) are better than anything invented here.
        final Object e when e.toString().contains('Voice channel not found') =>
          'That voice channel is gone.',
        _ => 'Couldn’t join the voice channel.',
      };

  @override
  Widget build(BuildContext context) {
    final voice = ref.watch(voiceProvider);
    final participants = ref.watch(voiceParticipantsProvider(widget.channel.id));
    final connectedHere = voice.isConnectedTo(widget.channel.id);

    // Tracks only exist for the room we are in; a channel we are merely looking
    // at shows avatars, which is all the server tells us about it.
    final tiles = buildTiles(
      participants,
      connectedHere ? voice.cameraTracks : const {},
      connectedHere ? voice.screenShareTracks : const {},
    );

    return Column(
      children: [
        Expanded(
          child: tiles.isEmpty
              ? _EmptyRoom(channel: widget.channel)
              : Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                  child: CallStage(
                    key: ValueKey(widget.channel.id),
                    tiles: tiles,
                    speaking: voice.speakingUserIds,
                  ),
                ),
        ),
        _BottomPanel(
          channel: widget.channel,
          connectedHere: connectedHere,
          connecting: voice.status == VoiceConnectionStatus.connecting,
          onJoin: _join,
          onLeave: ref.read(voiceSessionProvider).leave,
        ),
      ],
    );
  }
}

/// Nobody in the room. The same copy the web client shows, with the way in
/// living on the panel below rather than here.
class _EmptyRoom extends StatelessWidget {
  const _EmptyRoom({required this.channel});

  final Channel channel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              CampfireIcons.voiceChannel,
              size: 36,
              color: CampfireTokens.mutedForeground,
            ),
            const SizedBox(height: 8),
            Text(
              'No one’s here yet!',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 4),
            Text(
              'When you are ready to talk, just hop in.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: CampfireTokens.mutedForeground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The panel in thumb reach: the way in when we are out, the controls when we
/// are in.
class _BottomPanel extends StatelessWidget {
  const _BottomPanel({
    required this.channel,
    required this.connectedHere,
    required this.connecting,
    required this.onJoin,
    required this.onLeave,
  });

  final Channel channel;
  final bool connectedHere;
  final bool connecting;
  final Future<void> Function() onJoin;
  final Future<void> Function() onLeave;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: CampfireTokens.glass,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: CampfireTokens.glassBorder),
          ),
          child: connectedHere
              ? VoiceControls(onHangUp: onLeave)
              : SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: connecting ? null : onJoin,
                    icon: const Icon(CampfireIcons.callAnswer, size: 18),
                    label: Text(
                      connecting ? 'Connecting…' : 'Join ${channel.name}',
                      style: theme.textTheme.labelLarge,
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
