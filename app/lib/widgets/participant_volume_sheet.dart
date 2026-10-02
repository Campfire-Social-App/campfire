import 'dart:async';

import 'package:campfire/livekit/voice.dart';
import 'package:campfire/models/server.dart';
import 'package:campfire/state/voice.dart';
import 'package:campfire/theme/icons.dart';
import 'package:campfire/theme/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Discord-mobile-style long-press menu: how loud *I* hear this one person.
/// Local only, never shown for your own tile — see `call_stage.dart`.
Future<void> showParticipantVolumeSheet(
  BuildContext context,
  VoiceParticipantState participant,
) =>
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: CampfireTokens.popover,
      showDragHandle: true,
      builder: (_) => _ParticipantVolumeSheet(participant: participant),
    );

class _ParticipantVolumeSheet extends ConsumerWidget {
  const _ParticipantVolumeSheet({required this.participant});

  final VoiceParticipantState participant;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final voice = ref.watch(voiceProvider);
    final session = ref.read(voiceSessionProvider);
    final hasScreenAudio = voice.screenShareAudioUserIds.contains(participant.userId);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(participant.username, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _VolumeRow(
              icon: CampfireIcons.micOn,
              label: 'Microphone volume',
              value: voice.microphoneVolumes[participant.userId] ?? 1.0,
              onChanged: (v) => unawaited(session.setParticipantVolume(
                userId: participant.userId,
                screenShare: false,
                volume: v,
              )),
              onChangeEnd: (_) => unawaited(session.persistParticipantVolumes()),
            ),
            if (hasScreenAudio)
              _VolumeRow(
                icon: CampfireIcons.screenShareOn,
                label: 'Screen share volume',
                value: voice.screenShareVolumes[participant.userId] ?? 1.0,
                onChanged: (v) => unawaited(session.setParticipantVolume(
                  userId: participant.userId,
                  screenShare: true,
                  volume: v,
                )),
                onChangeEnd: (_) => unawaited(session.persistParticipantVolumes()),
              ),
          ],
        ),
      ),
    );
  }
}

class _VolumeRow extends StatelessWidget {
  const _VolumeRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
    required this.onChangeEnd,
  });

  final IconData icon;
  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: CampfireTokens.mutedForeground),
            const SizedBox(width: 8),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            const Spacer(),
            Text('${(value * 100).round()}%', style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        Slider(value: value, onChanged: onChanged, onChangeEnd: onChangeEnd),
      ],
    );
  }
}
