import 'dart:math' as math;

import 'package:campfire/theme/icons.dart';
import 'package:campfire/theme/tokens.dart';
import 'package:campfire/widgets/call_tiles.dart';
import 'package:flutter/material.dart';

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
