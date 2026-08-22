import 'dart:async';

import 'package:campfire/core/files.dart';
import 'package:campfire/theme/icons.dart';
import 'package:campfire/theme/tokens.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// The speeds the menu offers, same list as `MediaPlayer.tsx`.
const _speeds = [0.5, 1.0, 1.25, 1.5, 2.0];

/// Shared machinery for the two players: one [VideoPlayerController], the
/// controls built on top of it, and the state they read.
///
/// Port of `useMediaController` — the React version wraps a `<video>`/`<audio>`
/// element, this one wraps the plugin's controller, and both expose the same
/// handful of operations to the same set of buttons.
abstract class _MediaState<T extends StatefulWidget> extends State<T> {
  VideoPlayerController? controller;
  bool ready = false;
  String? failure;
  double speed = 1;
  double volume = 1;
  bool muted = false;

  String get source;

  @override
  void initState() {
    super.initState();
    unawaited(_open());
  }

  @override
  void dispose() {
    unawaited(controller?.dispose());
    super.dispose();
  }

  Future<void> _open() async {
    final next = VideoPlayerController.networkUrl(Uri.parse(source));
    controller = next;
    next.addListener(_onTick);
    try {
      await next.initialize();
      if (!mounted) return;
      setState(() => ready = true);
    } on Object catch (error) {
      if (!mounted) return;
      // A codec the platform will not decode is a normal outcome for a file
      // someone else uploaded — say so in place of the player rather than
      // leaving a black rectangle.
      setState(() => failure = '$error');
    }
  }

  void _onTick() {
    if (mounted) setState(() {});
  }

  Duration get position => controller?.value.position ?? Duration.zero;
  Duration get duration => controller?.value.duration ?? Duration.zero;
  bool get playing => controller?.value.isPlaying ?? false;

  /// How much of the clip has arrived, as a fraction — drawn behind the
  /// progress bar the way the web player draws its buffered range.
  double get buffered {
    final value = controller?.value;
    if (value == null || value.buffered.isEmpty || duration == Duration.zero) return 0;
    final end = value.buffered.last.end;
    return (end.inMilliseconds / duration.inMilliseconds).clamp(0, 1);
  }

  Future<void> toggle() async {
    final media = controller;
    if (media == null || !ready) return;

    // Restarting from the end is what a play button should do when the clip has
    // already run out; otherwise it looks like the button did nothing.
    if (media.value.position >= media.value.duration && media.value.duration > Duration.zero) {
      await media.seekTo(Duration.zero);
    }
    await (media.value.isPlaying ? media.pause() : media.play());
  }

  Future<void> seekFraction(double fraction) async {
    final media = controller;
    if (media == null || !ready || duration == Duration.zero) return;
    await media.seekTo(duration * fraction.clamp(0, 1));
  }

  Future<void> setSpeed(double next) async {
    await controller?.setPlaybackSpeed(next);
    if (mounted) setState(() => speed = next);
  }

  Future<void> setVolume(double next) async {
    final clamped = next.clamp(0.0, 1.0);
    await controller?.setVolume(clamped);
    if (mounted) {
      setState(() {
        volume = clamped;
        muted = clamped == 0;
      });
    }
  }

  Future<void> toggleMute() async {
    final nextMuted = !muted;
    await controller?.setVolume(nextMuted ? 0 : (volume == 0 ? 1 : volume));
    if (mounted) {
      setState(() {
        muted = nextMuted;
        if (!nextMuted && volume == 0) volume = 1;
      });
    }
  }
}

/// Video with the app's own controls rather than the platform's, so it looks
/// the same on every target — matching `VideoPlayer` in the web client.
class CampfireVideoPlayer extends StatefulWidget {
  const CampfireVideoPlayer({required this.src, super.key});

  final String src;

  @override
  State<CampfireVideoPlayer> createState() => _CampfireVideoPlayerState();
}

class _CampfireVideoPlayerState extends _MediaState<CampfireVideoPlayer> {
  @override
  String get source => widget.src;

  @override
  Widget build(BuildContext context) {
    if (failure != null) {
      return const _PlayerFailure(message: 'This video can’t be played here.');
    }
    final media = controller;
    if (!ready || media == null) return const _PlayerLoading(height: 180);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 440),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: ColoredBox(
          color: Colors.black,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: toggle,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    AspectRatio(
                      aspectRatio: media.value.aspectRatio,
                      child: VideoPlayer(media),
                    ),
                    if (!playing)
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(CampfireIcons.play, color: Colors.white, size: 26),
                      ),
                  ],
                ),
              ),
              _Controls(
                state: this,
                onFullscreen: () => _openFullscreen(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openFullscreen(BuildContext context) {
    final media = controller;
    if (media == null) return;

    // The same controller, handed to a black route: going full screen must not
    // restart the clip or lose the position.
    unawaited(
      Navigator.of(context).push(
        PageRouteBuilder<void>(
          barrierColor: Colors.black,
          pageBuilder: (_, _, _) => _FullscreenVideo(state: this),
        ),
      ),
    );
  }
}

/// Audio: the same controls, no picture. Port of `AudioPlayer`.
class CampfireAudioPlayer extends StatefulWidget {
  const CampfireAudioPlayer({required this.src, required this.filename, super.key});

  final String src;
  final String filename;

  @override
  State<CampfireAudioPlayer> createState() => _CampfireAudioPlayerState();
}

class _CampfireAudioPlayerState extends _MediaState<CampfireAudioPlayer> {
  @override
  String get source => widget.src;

  @override
  Widget build(BuildContext context) {
    if (failure != null) {
      return const _PlayerFailure(message: 'This audio can’t be played here.');
    }
    if (!ready) return const _PlayerLoading(height: 64);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 440),
      child: Container(
        decoration: BoxDecoration(
          color: CampfireTokens.glass,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: CampfireTokens.glassBorder),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: Row(
                children: [
                  const Icon(
                    CampfireIcons.fileAudio,
                    size: 16,
                    color: CampfireTokens.mutedForeground,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.filename,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
            _Controls(state: this),
          ],
        ),
      ),
    );
  }
}

/// Play/pause, scrubber, clock, volume and speed — the row both players share.
class _Controls extends StatefulWidget {
  const _Controls({required this.state, this.onFullscreen});

  final _MediaState<dynamic> state;
  final VoidCallback? onFullscreen;

  @override
  State<_Controls> createState() => _ControlsState();
}

class _ControlsState extends State<_Controls> {
  bool _volumeOpen = false;

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final fraction = state.duration == Duration.zero
        ? 0.0
        : state.position.inMilliseconds / state.duration.inMilliseconds;

    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 2, 6, 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Scrubber(
            value: fraction.clamp(0, 1),
            buffered: state.buffered,
            onChanged: state.seekFraction,
          ),
          Row(
            children: [
              _ControlButton(
                icon: state.playing ? CampfireIcons.pause : CampfireIcons.play,
                tooltip: state.playing ? 'Pause' : 'Play',
                onPressed: state.toggle,
              ),
              Text(
                '${formatDuration(state.position)} / ${formatDuration(state.duration)}',
                style: const TextStyle(
                  fontFamily: 'Geist',
                  fontSize: 11,
                  color: CampfireTokens.mutedForeground,
                ),
              ),
              const Spacer(),
              if (_volumeOpen)
                SizedBox(
                  width: 72,
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 2,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                      overlayShape: SliderComponentShape.noOverlay,
                    ),
                    child: Slider(
                      value: state.muted ? 0 : state.volume,
                      onChanged: state.setVolume,
                    ),
                  ),
                ),
              _ControlButton(
                icon: state.muted || state.volume == 0
                    ? CampfireIcons.volumeMuted
                    : state.volume < 0.5
                        ? CampfireIcons.volumeLow
                        : CampfireIcons.volumeHigh,
                tooltip: state.muted ? 'Unmute' : 'Mute',
                onPressed: state.toggleMute,
                onLongPress: () => setState(() => _volumeOpen = !_volumeOpen),
              ),
              PopupMenuButton<double>(
                tooltip: 'Playback speed',
                initialValue: state.speed,
                onSelected: state.setSpeed,
                color: CampfireTokens.popover,
                itemBuilder: (_) => [
                  for (final speed in _speeds)
                    PopupMenuItem(value: speed, height: 38, child: Text('$speed×')),
                ],
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Text(
                    '${state.speed}×',
                    style: const TextStyle(
                      fontFamily: 'Geist',
                      fontSize: 11,
                      color: CampfireTokens.mutedForeground,
                    ),
                  ),
                ),
              ),
              if (widget.onFullscreen != null)
                _ControlButton(
                  icon: CampfireIcons.enterFullscreen,
                  tooltip: 'Full screen',
                  onPressed: widget.onFullscreen!,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Draggable progress track, with the buffered range behind it. One control for
/// both players, as in the web client.
class _Scrubber extends StatelessWidget {
  const _Scrubber({required this.value, required this.buffered, required this.onChanged});

  final double value;
  final double buffered;
  final Future<void> Function(double) onChanged;

  @override
  Widget build(BuildContext context) {
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 3,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
        overlayShape: SliderComponentShape.noOverlay,
        activeTrackColor: CampfireTokens.primary,
        inactiveTrackColor: Colors.white.withValues(alpha: 0.15),
        secondaryActiveTrackColor: Colors.white.withValues(alpha: 0.3),
        thumbColor: CampfireTokens.primary,
      ),
      child: Slider(
        value: value,
        secondaryTrackValue: buffered.clamp(value, 1),
        onChanged: onChanged,
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.onLongPress,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 18, color: CampfireTokens.foreground),
        ),
      ),
    );
  }
}

/// The video, alone on black, with the same controls at the bottom.
class _FullscreenVideo extends StatefulWidget {
  const _FullscreenVideo({required this.state});

  final _CampfireVideoPlayerState state;

  @override
  State<_FullscreenVideo> createState() => _FullscreenVideoState();
}

class _FullscreenVideoState extends State<_FullscreenVideo> {
  @override
  Widget build(BuildContext context) {
    final media = widget.state.controller;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: media == null
                  ? const SizedBox.shrink()
                  : GestureDetector(
                      onTap: widget.state.toggle,
                      child: AspectRatio(
                        aspectRatio: media.value.aspectRatio,
                        child: VideoPlayer(media),
                      ),
                    ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _Controls(state: widget.state),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(CampfireIcons.exitFullscreen, color: Colors.white),
                tooltip: 'Exit full screen',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlayerLoading extends StatelessWidget {
  const _PlayerLoading({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      constraints: const BoxConstraints(maxWidth: 440),
      decoration: BoxDecoration(
        color: CampfireTokens.glass,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CampfireTokens.glassBorder),
      ),
      child: const Center(
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2, color: CampfireTokens.ember),
        ),
      ),
    );
  }
}

class _PlayerFailure extends StatelessWidget {
  const _PlayerFailure({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 440),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CampfireTokens.glass,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CampfireTokens.glassBorder),
      ),
      child: Row(
        children: [
          const Icon(CampfireIcons.warning, size: 16, color: CampfireTokens.mutedForeground),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: CampfireTokens.mutedForeground,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
