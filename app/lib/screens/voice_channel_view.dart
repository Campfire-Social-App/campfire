import 'dart:math' as math;

import 'package:campfire/livekit/voice.dart';
import 'package:campfire/models/channel.dart';
import 'package:campfire/state/voice.dart';
import 'package:campfire/theme/icons.dart';
import 'package:campfire/theme/tokens.dart';
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
  /// The tile blown up to fill the stage, if any. Held by key rather than by
  /// value so a tile that goes away (camera off, participant left) simply stops
  /// resolving instead of freezing a dead track on screen.
  String? _focusedKey;

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
    final focused = tiles.where((t) => t.key == _focusedKey).firstOrNull;

    return Column(
      children: [
        Expanded(
          child: tiles.isEmpty
              ? _EmptyRoom(channel: widget.channel)
              : Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                  child: focused != null
                      ? _FocusedStage(
                          focused: focused,
                          tiles: tiles,
                          onFocus: (key) => setState(() => _focusedKey = key),
                        )
                      : _TileGrid(
                          tiles: tiles,
                          speaking: voice.speakingUserIds,
                          onFocus: (key) => setState(() => _focusedKey = key),
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

/// Everyone at once. The column count follows the square root of the head
/// count, so four people are a 2×2 and nine are a 3×3 rather than a long strip.
class _TileGrid extends StatelessWidget {
  const _TileGrid({required this.tiles, required this.speaking, required this.onFocus});

  final List<CallTile> tiles;
  final Set<String> speaking;
  final void Function(String key) onFocus;

  @override
  Widget build(BuildContext context) {
    final columns = math.min(4, math.max(1, math.sqrt(tiles.length).ceil()));

    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        childAspectRatio: 16 / 9,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: tiles.length,
      itemBuilder: (context, index) {
        final tile = tiles[index];
        return _TileFrame(
          tile: tile,
          speaking: tile.kind == CallTileKind.camera && speaking.contains(tile.participant.userId),
          onTap: () => onFocus(tile.key),
        );
      },
    );
  }
}

/// One tile blown up, with the rest as a strip underneath — the web client's
/// focus mode, which is how a shared screen becomes readable.
class _FocusedStage extends StatelessWidget {
  const _FocusedStage({required this.focused, required this.tiles, required this.onFocus});

  final CallTile focused;
  final List<CallTile> tiles;
  final void Function(String? key) onFocus;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: CampfireTokens.glassBorder),
                    ),
                    child: TileVisual(tile: focused, scale: TileScale.large),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Material(
                  color: Colors.black.withValues(alpha: 0.5),
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => onFocus(null),
                    child: const SizedBox(
                      width: 32,
                      height: 32,
                      child: Icon(CampfireIcons.close, size: 16, color: Colors.white),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (tiles.length > 1)
          SizedBox(
            height: 72,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(top: 8),
              itemCount: tiles.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final tile = tiles[index];
                return AspectRatio(
                  aspectRatio: 16 / 9,
                  child: _TileFrame(
                    tile: tile,
                    scale: TileScale.compact,
                    selected: tile.key == focused.key,
                    onTap: () => onFocus(tile.key),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

/// The rounded, ringed box every tile sits in. The ring is what turns amber
/// when its participant has the floor.
class _TileFrame extends StatelessWidget {
  const _TileFrame({
    required this.tile,
    required this.onTap,
    this.scale = TileScale.normal,
    this.speaking = false,
    this.selected = false,
  });

  final CallTile tile;
  final TileScale scale;
  final bool speaking;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(scale == TileScale.compact ? 8 : 12);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: CampfireTokens.glass,
          borderRadius: radius,
          border: Border.all(
            color: speaking || selected ? CampfireTokens.primary : CampfireTokens.glassBorder,
            width: speaking ? 2.5 : 1.5,
          ),
          boxShadow: speaking
              ? [
                  BoxShadow(
                    color: CampfireTokens.primary.withValues(alpha: 0.45),
                    blurRadius: 20,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        clipBehavior: Clip.antiAlias,
        child: TileVisual(tile: tile, scale: scale),
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
