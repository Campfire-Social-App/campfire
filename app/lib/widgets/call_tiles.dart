import 'package:campfire/models/server.dart';
import 'package:campfire/state/auth.dart';
import 'package:campfire/state/presence.dart';
import 'package:campfire/state/users.dart';
import 'package:campfire/theme/icons.dart';
import 'package:campfire/theme/tokens.dart';
import 'package:campfire/widgets/user_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart'
    show VideoTrack, VideoTrackRenderer, VideoViewMirrorMode;

/// One rectangle on a call stage. Everyone in the room has a camera tile — the
/// avatar stands in while the camera is off — and gains a second one while they
/// share a screen. Port of `CallTiles.tsx`, shared by the voice channel view and
/// the DM call panel.
@immutable
class CallTile {
  const CallTile({
    required this.key,
    required this.kind,
    required this.participant,
    this.track,
  });

  final String key;
  final CallTileKind kind;
  final VoiceParticipantState participant;
  final VideoTrack? track;
}

enum CallTileKind { camera, screen }

List<CallTile> buildTiles(
  List<VoiceParticipantState> participants,
  Map<String, VideoTrack> cameraTracks,
  Map<String, VideoTrack> screenShareTracks,
) {
  return [
    for (final participant in participants) ...[
      CallTile(
        key: 'cam:${participant.userId}',
        kind: CallTileKind.camera,
        participant: participant,
        track: cameraTracks[participant.userId],
      ),
      if (screenShareTracks[participant.userId] case final VideoTrack screen)
        CallTile(
          key: 'scr:${participant.userId}',
          kind: CallTileKind.screen,
          participant: participant,
          track: screen,
        ),
    ],
  ];
}

/// How much room the tile has, which decides what fits in it.
enum TileScale {
  /// A thumbnail in the filmstrip: the picture only, no name plate.
  compact,

  /// The default grid cell.
  normal,

  /// The focused tile, filling the stage.
  large,
}

class TileVisual extends ConsumerWidget {
  const TileVisual({required this.tile, this.scale = TileScale.normal, super.key});

  final CallTile tile;
  final TileScale scale;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isScreen = tile.kind == CallTileKind.screen;
    final me = switch (ref.watch(authProvider)) {
      AuthAuthenticated(:final user) => user.id,
      _ => null,
    };
    final isOwn = tile.participant.userId == me;
    final online = ref.watch(isOnlineProvider(tile.participant.userId));

    return Stack(
      fit: StackFit.expand,
      children: [
        if (tile.track case final VideoTrack track)
          ColoredBox(
            color: Colors.black,
            child: VideoTrackRenderer(
              track,
              // Your own camera is a mirror, the way a front-facing preview
              // always is; a screen share never is, or the text comes out
              // backwards.
              mirrorMode: !isScreen && isOwn
                  ? VideoViewMirrorMode.mirror
                  : VideoViewMirrorMode.off,
            ),
          )
        else
          DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [CampfireTokens.muted, CampfireTokens.secondary],
              ),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Sized to the tile it lands in rather than to a fixed scale:
                // the same "normal" tile is a third of a desktop window and
                // half a phone's width, and an avatar picked for one of those
                // spills out of the other.
                final size = _avatarFor(constraints.biggest.shortestSide);

                return Center(
                  child: UserAvatar(
                    username: tile.participant.username,
                    // The voice state the server sends is a name and an id; the
                    // photo comes from the roster, the only place that has one.
                    avatarUrl: ref.watch(userByIdProvider(tile.participant.userId))?.avatarUrl,
                    size: size,
                    // On anything but a middling tile the dot goes: at thumbnail
                    // size it is noise, and on a full frame a speck of a badge
                    // on a huge circle reads as an artifact — "they are online"
                    // being implied by them being in the call anyway.
                    status: size == AvatarSize.lg || size == AvatarSize.xl
                        ? (online ? PresenceDot.online : PresenceDot.offline)
                        : null,
                  ),
                );
              },
            ),
          ),
        if (scale != TileScale.compact)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _NamePlate(tile: tile, isScreen: isScreen),
          ),
      ],
    );
  }
}

/// The biggest avatar that leaves room to breathe in a box of [shortestSide],
/// and never one so big it reaches the name plate.
AvatarSize _avatarFor(double shortestSide) => switch (shortestSide) {
      < 56 => AvatarSize.sm,
      < 90 => AvatarSize.md,
      < 150 => AvatarSize.lg,
      // The big one is for the focused tile only, the way `size-40` is in the
      // web client: on an ordinary grid cell it swallows the frame.
      < 400 => AvatarSize.xl,
      _ => AvatarSize.xxl,
    };

/// Who this tile is, over the gradient that keeps the name readable against a
/// bright frame.
class _NamePlate extends StatelessWidget {
  const _NamePlate({required this.tile, required this.isScreen});

  final CallTile tile;
  final bool isScreen;

  @override
  Widget build(BuildContext context) {
    final participant = tile.participant;

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 8),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Color(0xB3000000), Colors.transparent],
        ),
      ),
      child: Row(
        children: [
          if (isScreen) ...[
            const Icon(CampfireIcons.screenPlaying, size: 14, color: Colors.white),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(
              isScreen ? '${participant.username} · screen' : participant.username,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 13,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
          if (!isScreen && (participant.muted || participant.deafened)) ...[
            const Spacer(),
            if (participant.muted)
              const Icon(CampfireIcons.micOff, size: 14, color: CampfireTokens.destructive),
            if (participant.deafened)
              const Padding(
                padding: EdgeInsets.only(left: 5),
                child: Icon(
                  CampfireIcons.volumeMuted,
                  size: 14,
                  color: CampfireTokens.destructive,
                ),
              ),
          ],
        ],
      ),
    );
  }
}
