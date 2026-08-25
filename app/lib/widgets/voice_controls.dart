import 'package:campfire/livekit/voice.dart';
import 'package:campfire/state/voice.dart';
import 'package:campfire/theme/icons.dart';
import 'package:campfire/theme/tokens.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Microphone, audio, camera, screen and the way out — the cluster the web
/// client spreads across the user bar and the call panel.
///
/// On a phone this is the row at the bottom of the voice screen, which is where
/// the plan puts it (PLANO_FLUTTER.md §12): controls in thumb reach rather than
/// in a header nobody can reach one-handed.
class VoiceControls extends ConsumerWidget {
  const VoiceControls({required this.onHangUp, this.dense = false, super.key});

  /// Leaving means different things in the two places this appears: a voice
  /// channel is left, a 1:1 call is hung up (which also ends the ring).
  final Future<void> Function() onHangUp;

  /// The tighter row the DM panel uses, where the chat is the main event.
  final bool dense;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final voice = ref.watch(voiceProvider);
    final session = ref.read(voiceSessionProvider);

    Future<void> guarded(Future<void> Function() action, String failure) async {
      try {
        await action();
      } on Object {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failure)));
      }
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _ControlButton(
          icon: voice.localMuted ? CampfireIcons.micOff : CampfireIcons.micOn,
          label: voice.localMuted ? 'Unmute' : 'Mute',
          active: voice.localMuted,
          dense: dense,
          onTap: () => session.setMicrophoneMuted(muted: !voice.localMuted),
        ),
        _ControlButton(
          icon: voice.localDeafened ? CampfireIcons.volumeMuted : CampfireIcons.deafenOff,
          label: voice.localDeafened ? 'Undeafen' : 'Deafen',
          active: voice.localDeafened,
          dense: dense,
          onTap: () => session.setDeafened(deafened: !voice.localDeafened),
        ),
        _ControlButton(
          icon: voice.localCameraEnabled ? CampfireIcons.cameraOn : CampfireIcons.cameraOff,
          label: voice.localCameraEnabled ? 'Stop video' : 'Start video',
          active: voice.localCameraEnabled,
          activeStyle: _ActiveStyle.primary,
          dense: dense,
          onTap: () => guarded(
            () => session.setCameraEnabled(enabled: !voice.localCameraEnabled),
            'Couldn’t access the camera.',
          ),
        ),
        // Two cameras is a phone thing, and so is this button: it only appears
        // once there is a picture to flip.
        if (voice.localCameraEnabled && _hasTwoCameras)
          _ControlButton(
            icon: CampfireIcons.switchCamera,
            label: 'Switch camera',
            active: false,
            dense: dense,
            onTap: () => guarded(session.switchCamera, 'Couldn’t switch camera.'),
          ),
        if (_canShareScreen)
          _ControlButton(
            icon: voice.localScreenShareEnabled
                ? CampfireIcons.screenShareOn
                : CampfireIcons.screenShareOff,
            label: voice.localScreenShareEnabled ? 'Stop sharing' : 'Share screen',
            active: voice.localScreenShareEnabled,
            activeStyle: _ActiveStyle.primary,
            dense: dense,
            onTap: () async {
              if (voice.localScreenShareEnabled) {
                await guarded(
                  () => session.setScreenShareEnabled(enabled: false),
                  'Couldn’t stop sharing the screen.',
                );
                return;
              }
              final captureAudio = await _chooseScreenAudio(context);
              if (captureAudio == null) return;
              await guarded(
                () => session.setScreenShareEnabled(
                  enabled: true,
                  captureAudio: captureAudio,
                ),
                'Couldn’t share the screen.',
              );
            },
          ),
        _ControlButton(
          icon: CampfireIcons.callEnd,
          label: 'Disconnect',
          active: true,
          activeStyle: _ActiveStyle.danger,
          dense: dense,
          onTap: onHangUp,
        ),
      ],
    );
  }

  /// iOS screen sharing needs a ReplayKit broadcast extension — a second
  /// process, signed alongside the app — which this build does not ship, so the
  /// button would be a dead end there (PLANO_FLUTTER.md, task F5).
  bool get _canShareScreen =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux);

  bool get _hasTwoCameras =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<bool?> _chooseScreenAudio(BuildContext context) => showModalBottomSheet<bool>(
        context: context,
        backgroundColor: CampfireTokens.popover,
        showDragHandle: true,
        builder: (sheetContext) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(CampfireIcons.volumeHigh),
                title: const Text('Share with audio'),
                subtitle: const Text('Include sound from apps when the system supports it'),
                onTap: () => Navigator.of(sheetContext).pop(true),
              ),
              ListTile(
                leading: const Icon(CampfireIcons.screenShareOn),
                title: const Text('Screen only'),
                subtitle: const Text('Share video without system audio'),
                onTap: () => Navigator.of(sheetContext).pop(false),
              ),
            ],
          ),
        ),
      );
}

enum _ActiveStyle { muted, primary, danger }

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    this.activeStyle = _ActiveStyle.muted,
    this.dense = false,
  });

  final IconData icon;
  final String label;
  final bool active;
  final _ActiveStyle activeStyle;
  final bool dense;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch ((active, activeStyle)) {
      (false, _) => (CampfireTokens.glass, CampfireTokens.mutedForeground),
      (true, _ActiveStyle.muted) => (
          CampfireTokens.destructive.withValues(alpha: 0.15),
          CampfireTokens.destructive,
        ),
      (true, _ActiveStyle.primary) => (
          CampfireTokens.primary.withValues(alpha: 0.15),
          CampfireTokens.primary,
        ),
      (true, _ActiveStyle.danger) => (CampfireTokens.destructive, Colors.white),
    };
    final diameter = dense ? 36.0 : 48.0;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: dense ? 3 : 6),
      child: Tooltip(
        message: label,
        child: Material(
          color: background,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: SizedBox(
              width: diameter,
              height: diameter,
              child: Icon(icon, size: dense ? 17 : 21, color: foreground),
            ),
          ),
        ),
      ),
    );
  }
}
