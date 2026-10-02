import 'dart:async';
import 'dart:math' as math;

import 'package:campfire/livekit/voice.dart';
import 'package:campfire/state/auth.dart';
import 'package:campfire/state/voice.dart';
import 'package:campfire/theme/icons.dart';
import 'package:campfire/theme/tokens.dart';
import 'package:campfire/widgets/call_tiles.dart';
import 'package:campfire/widgets/participant_volume_sheet.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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
  const CallStage({required this.tiles, required this.speaking, super.key});

  final List<CallTile> tiles;
  final Set<String> speaking;

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
class _FocusedStage extends ConsumerWidget {
  const _FocusedStage({required this.focused, required this.tiles, required this.onFocus});

  final CallTile focused;
  final List<CallTile> tiles;
  final void Function(String? key) onFocus;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                        onTap: () {
                          _leaveIfScreenShare(ref, focused);
                          onFocus(null);
                        },
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
                height: stripHeight,
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
                        onTap: () => _watchThenFocus(ref, tile, onFocus),
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
