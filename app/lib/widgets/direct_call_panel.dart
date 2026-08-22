import 'dart:async';
import 'dart:math' as math;

import 'package:campfire/livekit/voice.dart';
import 'package:campfire/models/dm.dart';
import 'package:campfire/state/calls.dart';
import 'package:campfire/state/voice.dart';
import 'package:campfire/theme/icons.dart';
import 'package:campfire/theme/tokens.dart';
import 'package:campfire/widgets/call_tiles.dart';
import 'package:campfire/widgets/voice_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The call stage inside a conversation: status, controls and the tiles, above
/// the message list rather than instead of it — you can keep typing while the
/// call runs. Port of `DirectCallPanel.tsx`.
///
/// Draws nothing at all when there is no call to show, which is what lets the
/// DM view hand it in unconditionally.
class DirectCallPanel extends ConsumerWidget {
  const DirectCallPanel({required this.conversation, super.key});

  final DMConversation conversation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final voice = ref.watch(voiceProvider);
    final participants = ref.watch(voiceParticipantsProvider(conversation.id));
    final ringing = ref.watch(callsProvider).outgoing == conversation.id;
    final inThisCall = voice.isConnectedTo(conversation.id);

    // Someone is in the room without us: a call we left, or one we declined and
    // they stayed on. Offer the way back in rather than pretending it is over.
    final elsewhere = !inThisCall && participants.isNotEmpty;
    if (!inThisCall && !ringing && !elsewhere) return const SizedBox.shrink();

    final tiles = buildTiles(
      participants,
      inThisCall ? voice.cameraTracks : const {},
      inThisCall ? voice.screenShareTracks : const {},
    );

    final status = switch ((ringing, voice.status, inThisCall)) {
      (true, _, _) => 'Ringing ${conversation.recipient.username}…',
      (_, VoiceConnectionStatus.connecting, _) => 'Connecting…',
      (_, _, true) => 'In call',
      _ => '${conversation.recipient.username} is on a call',
    };

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: const BoxDecoration(
        color: CampfireTokens.glass,
        border: Border(bottom: BorderSide(color: CampfireTokens.glassBorder)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _RingingIcon(ringing: ringing),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  status,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              if (!inThisCall && !ringing)
                FilledButton.icon(
                  onPressed: () => _join(context, ref),
                  icon: const Icon(CampfireIcons.callAnswer, size: 16),
                  label: const Text('Join'),
                ),
              if (ringing && !inThisCall)
                _HangUp(onTap: () => ref.read(callsProvider.notifier).hangUp(conversation.id)),
            ],
          ),
          if (inThisCall) ...[
            const SizedBox(height: 8),
            VoiceControls(
              dense: true,
              onHangUp: () => ref.read(callsProvider.notifier).hangUp(conversation.id),
            ),
          ],
          if (inThisCall && tiles.isNotEmpty) ...[
            const SizedBox(height: 10),
            _Tiles(tiles: tiles, speaking: voice.speakingUserIds),
          ],
        ],
      ),
    );
  }

  Future<void> _join(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(voiceSessionProvider).join(conversation.id);
    } on Object {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Couldn’t join the call.')),
      );
    }
  }
}

/// The handset, pulsing while the other end is still ringing.
class _RingingIcon extends StatefulWidget {
  const _RingingIcon({required this.ringing});

  final bool ringing;

  @override
  State<_RingingIcon> createState() => _RingingIconState();
}

class _RingingIconState extends State<_RingingIcon> with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void initState() {
    super.initState();
    if (widget.ringing) unawaited(_pulse.repeat(reverse: true));
  }

  @override
  void didUpdateWidget(_RingingIcon old) {
    super.didUpdateWidget(old);
    if (widget.ringing == old.ringing) return;
    if (widget.ringing) {
      unawaited(_pulse.repeat(reverse: true));
    } else {
      _pulse.stop();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: widget.ringing
          ? Tween<double>(begin: 1, end: 0.35).animate(_pulse)
          : const AlwaysStoppedAnimation(1),
      child: const Icon(CampfireIcons.callAnswer, size: 16, color: CampfireTokens.primary),
    );
  }
}

class _HangUp extends StatelessWidget {
  const _HangUp({required this.onTap});

  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: CampfireTokens.destructive,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: const SizedBox(
          width: 32,
          height: 32,
          child: Icon(CampfireIcons.callEnd, size: 16, color: Colors.white),
        ),
      ),
    );
  }
}

/// A 1:1 has at most a handful of tiles, and the chat below has to keep most of
/// the screen — so they are capped rather than left to grow with the window.
class _Tiles extends StatelessWidget {
  const _Tiles({required this.tiles, required this.speaking});

  final List<CallTile> tiles;
  final Set<String> speaking;

  /// Same ceiling as the web client's `max-h-52`: past this the call stops
  /// being a banner over the conversation and becomes the conversation.
  static const double maxHeight = 208;

  static const double _spacing = 6;

  @override
  Widget build(BuildContext context) {
    final columns = math.min(3, math.max(1, tiles.length));

    return LayoutBuilder(
      builder: (context, constraints) {
        final available = (constraints.maxWidth - _spacing * (columns - 1)) / columns;
        final width = math.min(available, maxHeight * 16 / 9);

        return Wrap(
          spacing: _spacing,
          runSpacing: _spacing,
          alignment: WrapAlignment.center,
          children: [
            for (final tile in tiles)
              SizedBox(width: width, height: width * 9 / 16, child: _tile(tile)),
          ],
        );
      },
    );
  }

  Widget _tile(CallTile tile) => DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: tile.kind == CallTileKind.camera && speaking.contains(tile.participant.userId)
                ? CampfireTokens.primary
                : CampfireTokens.glassBorder,
            width: 1.5,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: TileVisual(tile: tile),
        ),
      );
}
