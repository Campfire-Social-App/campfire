import 'package:campfire/models/server.dart';
import 'package:campfire/state/auth.dart';
import 'package:campfire/state/presence.dart';
import 'package:campfire/state/users.dart';
import 'package:campfire/state/voice.dart';
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
      if (participant.screenSharing)
        CallTile(
          key: 'scr:${participant.userId}',
          kind: CallTileKind.screen,
          participant: participant,
          track: screenShareTracks[participant.userId],
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final shortestSide = constraints.biggest.shortestSide;
        // Sized to the tile it lands in rather than to a fixed scale: the
        // same "normal" tile is a third of a desktop window and half a
        // phone's width, and an avatar picked for one of those spills out of
        // the other.
        final avatarSize = _avatarFor(shortestSide);

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
            else if (isScreen && !isOwn)
              _ScreenSharePlaceholder(
                username: tile.participant.username,
                viewing: ref.watch(voiceProvider).viewingScreenShares.contains(
                      tile.participant.userId,
                    ),
                compact: scale == TileScale.compact,
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
                child: Center(
                  child: UserAvatar(
                    username: tile.participant.username,
                    // The voice state the server sends is a name and an id;
                    // the photo comes from the roster, the only place that
                    // has one.
                    avatarUrl: ref.watch(userByIdProvider(tile.participant.userId))?.avatarUrl,
                    size: avatarSize,
                    // On anything but a middling tile the dot goes: at
                    // thumbnail size it is noise, and on a full frame a
                    // speck of a badge on a huge circle reads as an artifact
                    // — "they are online" being implied by them being in the
                    // call anyway.
                    status: avatarSize == AvatarSize.lg || avatarSize == AvatarSize.xl
                        ? (online ? PresenceDot.online : PresenceDot.offline)
                        : null,
                  ),
                ),
              ),
            if (scale != TileScale.compact)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                // A small grid cell in a packed call, sideways, has no room for
                // the status icons without pushing the name out.
                child: _NamePlate(
                  tile: tile,
                  isScreen: isScreen,
                  compact: shortestSide < 64,
                ),
              ),
          ],
        );
      },
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
  const _NamePlate({required this.tile, required this.isScreen, this.compact = false});

  final CallTile tile;
  final bool isScreen;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final participant = tile.participant;

    return Container(
      padding: compact
          ? const EdgeInsets.fromLTRB(6, 6, 6, 4)
          : const EdgeInsets.fromLTRB(10, 12, 10, 8),
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
            Icon(CampfireIcons.screenPlaying, size: compact ? 11 : 14, color: Colors.white),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(
              isScreen ? '${participant.username} · screen' : participant.username,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: compact ? 11 : 13,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
          if (!compact && !isScreen && (participant.muted || participant.deafened)) ...[
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

/// What a screen-share tile shows before its track exists: either nobody
/// opted in yet (the whole tile is the "watch" gesture — see
/// `call_stage.dart`), or we just did and the subscription has not caught up
/// with the SFU yet.
class _ScreenSharePlaceholder extends StatelessWidget {
  const _ScreenSharePlaceholder({
    required this.username,
    required this.viewing,
    required this.compact,
  });

  final String username;
  final bool viewing;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final icon = viewing
        ? const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
          )
        : const Icon(CampfireIcons.screenPlaying, size: 20, color: Colors.white);

    return DecoratedBox(
      decoration: const BoxDecoration(color: CampfireTokens.muted),
      child: Center(
        child: compact
            ? icon
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  icon,
                  const SizedBox(height: 8),
                  Text(
                    viewing ? 'Joining stream…' : '$username is streaming',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white),
                  ),
                  if (!viewing) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Tap to watch',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}
