import 'dart:async';
import 'dart:math' as math;

import 'package:campfire/livekit/voice.dart';
import 'package:campfire/state/auth.dart';
import 'package:campfire/state/voice.dart';
import 'package:campfire/theme/icons.dart';
import 'package:campfire/theme/tokens.dart';
import 'package:campfire/widgets/call_tiles.dart';
import 'package:campfire/widgets/participant_volume_sheet.dart';
import 'package:campfire/widgets/voice_controls.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Paisagem num aparelho de bolso: curto o bastante para que o padding e os
/// botões de 48px do painel de controles comam espaço demais. Tablets
/// girados do mesmo jeito ainda têm altura de sobra, por isso o corte é pelo
/// lado mais curto da tela, não só pela orientação.
bool isCompactLandscape(BuildContext context) {
  final size = MediaQuery.sizeOf(context);
  return size.width > size.height && size.shortestSide < 600;
}

/// Opts into someone else's screen share, if the tapped tile needs it,
/// before focusing it — the "watch stream" half of the opt-in model.
void _watchThenFocus(WidgetRef ref, CallTile tile, void Function(String key) onFocus) {
  final me = switch (ref.read(authProvider)) {
    AuthAuthenticated(:final user) => user.id,
    _ => null,
  };
  if (tile.kind == CallTileKind.screen &&
      tile.track == null &&
      tile.participant.userId != me &&
      !ref.read(voiceProvider).viewingScreenShares.contains(tile.participant.userId)) {
    unawaited(
      ref.read(voiceSessionProvider).setScreenShareViewing(tile.participant.userId, viewing: true),
    );
  }
  onFocus(tile.key);
}

/// Leaves someone else's screen share, if the tile being unfocused was one —
/// the "leave stream" action, folded into the close button that already
/// exists rather than a new one.
void _leaveIfScreenShare(WidgetRef ref, CallTile tile) {
  final me = switch (ref.read(authProvider)) {
    AuthAuthenticated(:final user) => user.id,
    _ => null,
  };
  if (tile.kind == CallTileKind.screen && tile.participant.userId != me) {
    unawaited(
      ref.read(voiceSessionProvider).setScreenShareViewing(tile.participant.userId, viewing: false),
    );
  }
}

/// Shared, touch-friendly grid and focused view for channels and private calls.
/// The parent supplies a bounded height so the grid can scroll on small screens.
class CallStage extends StatefulWidget {
  const CallStage({
    required this.tiles,
    required this.speaking,
    required this.onHangUp,
    super.key,
  });

  final List<CallTile> tiles;
  final Set<String> speaking;
  final Future<void> Function() onHangUp;

  @override
  State<CallStage> createState() => _CallStageState();
}

class _CallStageState extends State<CallStage> {
  String? _focusedKey;

  @override
  void didUpdateWidget(CallStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.tiles.any((tile) => tile.key == _focusedKey)) {
      _focusedKey = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final focused = widget.tiles.where((tile) => tile.key == _focusedKey).firstOrNull;
    return focused != null
        ? _FocusedStage(
            focused: focused,
            tiles: widget.tiles,
            onFocus: (key) => setState(() => _focusedKey = key),
            onHangUp: widget.onHangUp,
          )
        : _TileGrid(
            tiles: widget.tiles,
            speaking: widget.speaking,
            onFocus: (key) => setState(() => _focusedKey = key),
          );
  }
}

/// Everyone at once. The column count follows the square root of the head
/// count, so four people are a 2×2 and nine are a 3×3 rather than a long strip.
class _TileGrid extends ConsumerWidget {
  const _TileGrid({required this.tiles, required this.speaking, required this.onFocus});

  final List<CallTile> tiles;
  final Set<String> speaking;
  final void Function(String key) onFocus;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final columns = math.min(4, math.max(1, math.sqrt(tiles.length).ceil()));
    final rows = (tiles.length / columns).ceil();
    const spacing = 8.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Fills the box we actually have instead of a fixed 16:9: the same
        // pair of participants is a narrow strip standing up and nearly a
        // square lying down.
        final cellWidth = (constraints.maxWidth - spacing * (columns - 1)) / columns;
        final cellHeight = (constraints.maxHeight - spacing * (rows - 1)) / rows;
        final aspectRatio = (cellWidth / cellHeight).clamp(0.5, 2.5);

        return GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            childAspectRatio: aspectRatio,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
          ),
          itemCount: tiles.length,
          itemBuilder: (context, index) {
            final tile = tiles[index];
            return _TileFrame(
              tile: tile,
              speaking:
                  tile.kind == CallTileKind.camera && speaking.contains(tile.participant.userId),
              onTap: () => _watchThenFocus(ref, tile, onFocus),
            );
          },
        );
      },
    );
  }
}

/// One tile blown up, with the rest as a strip underneath — the web client's
/// focus mode, which is how a shared screen becomes readable.
class _FocusedStage extends ConsumerStatefulWidget {
  const _FocusedStage({
    required this.focused,
    required this.tiles,
    required this.onFocus,
    required this.onHangUp,
  });

  final CallTile focused;
  final List<CallTile> tiles;
  final void Function(String? key) onFocus;
  final Future<void> Function() onHangUp;

  @override
  ConsumerState<_FocusedStage> createState() => _FocusedStageState();
}

class _FocusedStageState extends ConsumerState<_FocusedStage> {
  bool _fullscreenOpen = false;

  @override
  Widget build(BuildContext context) {
    // Landscape plus focused means a real fullscreen — pushed next frame
    // rather than mid-build, which the Navigator does not allow.
    final isLandscape = MediaQuery.orientationOf(context) == Orientation.landscape;
    if (isLandscape && !_fullscreenOpen) {
      _fullscreenOpen = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_openFullscreen()));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // The strip shrinks with the height we get instead of staying locked
        // at 72px — generous on a tall portrait screen, thinned to a sliver
        // when the phone is on its side or the DM panel's box is small.
        final stripHeight = (constraints.maxHeight * 0.18).clamp(40.0, 80.0);

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
                        child: TileVisual(tile: widget.focused, scale: TileScale.large),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: _CloseButton(
                      onTap: () {
                        _leaveIfScreenShare(ref, widget.focused);
                        widget.onFocus(null);
                      },
                    ),
                  ),
                ],
              ),
            ),
            if (widget.tiles.length > 1)
              SizedBox(
                height: stripHeight,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(top: 8),
                  itemCount: widget.tiles.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final tile = widget.tiles[index];
                    return AspectRatio(
                      aspectRatio: 16 / 9,
                      child: _TileFrame(
                        tile: tile,
                        scale: TileScale.compact,
                        selected: tile.key == widget.focused.key,
                        onTap: () => _watchThenFocus(ref, tile, widget.onFocus),
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _openFullscreen() async {
    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        barrierColor: Colors.black,
        pageBuilder: (_, _, _) => _CallFullscreenPage(
          focused: widget.focused,
          onExit: () {
            _leaveIfScreenShare(ref, widget.focused);
            widget.onFocus(null);
          },
          onHangUp: widget.onHangUp,
        ),
      ),
    );
    // Only comes back here once the route is popped (either the × or a
    // rotation back to portrait). If we are still focused, the orientation
    // check above has already flipped to false by now, so this will not
    // immediately reopen it.
    if (mounted) _fullscreenOpen = false;
  }
}

/// The close button that floats over a focused tile, in the same spot in the
/// theater view and the real fullscreen page.
class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: const SizedBox(
          width: 32,
          height: 32,
          child: Icon(CampfireIcons.close, size: 16, color: Colors.white),
        ),
      ),
    );
  }
}

/// The real thing: system status/nav bars hidden, the tile edge-to-edge, and
/// the only UI a tap reveals — the close button and the full voice control
/// bar, so muting or hanging up does not require leaving fullscreen first.
class _CallFullscreenPage extends ConsumerStatefulWidget {
  const _CallFullscreenPage({
    required this.focused,
    required this.onExit,
    required this.onHangUp,
  });

  final CallTile focused;
  final VoidCallback onExit;
  final Future<void> Function() onHangUp;

  @override
  ConsumerState<_CallFullscreenPage> createState() => _CallFullscreenPageState();
}

class _CallFullscreenPageState extends ConsumerState<_CallFullscreenPage> {
  bool _controlsVisible = false;

  @override
  void initState() {
    super.initState();
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky));
  }

  @override
  void dispose() {
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Fullscreen only makes sense lying down — rotating back out exits it on
    // its own, keeping the tile focused; the close button is what unfocuses
    // for good.
    if (MediaQuery.orientationOf(context) == Orientation.portrait) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(Navigator.of(context).maybePop());
      });
    }

    // `widget.focused` is only a snapshot from the moment this route was
    // pushed — a screen share accepted *after* the push (the normal case,
    // since the subscription is opt-in) would otherwise show "Joining
    // stream…" forever. Re-derive the live tile from current state instead,
    // the same way `buildTiles` does.
    final userId = widget.focused.participant.userId;
    final voice = ref.watch(voiceProvider);
    final liveParticipant =
        voice.participants.where((p) => p.userId == userId).firstOrNull ??
            widget.focused.participant;
    final stillAvailable = widget.focused.kind == CallTileKind.screen
        ? liveParticipant.screenSharing
        : voice.participants.any((p) => p.userId == userId);
    if (!stillAvailable) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          widget.onExit();
          unawaited(Navigator.of(context).maybePop());
        }
      });
    }
    final liveTile = CallTile(
      key: widget.focused.key,
      kind: widget.focused.kind,
      participant: liveParticipant,
      track: widget.focused.kind == CallTileKind.screen
          ? voice.screenShareTracks[userId]
          : voice.cameraTracks[userId],
    );

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => setState(() => _controlsVisible = !_controlsVisible),
        child: Stack(
          fit: StackFit.expand,
          children: [
            TileVisual(tile: liveTile, scale: TileScale.large),
            if (_controlsVisible)
              SafeArea(
                child: Stack(
                  children: [
                    Positioned(
                      top: 8,
                      right: 8,
                      child: _CloseButton(
                        onTap: () {
                          widget.onExit();
                          unawaited(Navigator.of(context).maybePop());
                        },
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 16,
                      // Glass tints are tuned against the app's own dark
                      // background, not an arbitrary screen share — opaque
                      // here gives each button its own flat, solid color
                      // instead of letting the video show through the gaps.
                      child: Center(
                        child: VoiceControls(onHangUp: widget.onHangUp, opaque: true),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The rounded, ringed box every tile sits in. The ring is what turns amber
/// when its participant has the floor.
class _TileFrame extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final me = switch (ref.watch(authProvider)) {
      AuthAuthenticated(:final user) => user.id,
      _ => null,
    };
    final isOwnTile = tile.participant.userId == me;
    final radius = BorderRadius.circular(scale == TileScale.compact ? 8 : 12);

    return GestureDetector(
      onTap: onTap,
      // Volume is a listening preference — it does not apply to your own
      // tile, and `Helper.setVolume` has no web implementation (see
      // `livekit/voice.dart`).
      onLongPress: (!kIsWeb && !isOwnTile)
          ? () => unawaited(showParticipantVolumeSheet(context, tile.participant))
          : null,
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
