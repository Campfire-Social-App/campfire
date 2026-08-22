import 'package:campfire/models/dm.dart';
import 'package:campfire/state/calls.dart';
import 'package:campfire/state/voice.dart';
import 'package:campfire/theme/icons.dart';
import 'package:campfire/theme/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Call and video-call, in the conversation's header.
///
/// They disappear once a call is up or ringing: from that point the call panel
/// owns it, and a second button here would only be another way to start the one
/// already running. Same rule as `DirectMessageView.tsx`.
class DmCallButtons extends ConsumerWidget {
  const DmCallButtons({required this.conversation, super.key});

  final DMConversation conversation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inCall = ref.watch(voiceProvider).isConnectedTo(conversation.id);
    final ringing = ref.watch(callsProvider).outgoing == conversation.id;
    if (inCall || ringing) return const SizedBox.shrink();

    Future<void> start({required bool video}) async {
      try {
        await ref.read(callsProvider.notifier).start(conversation.id, video: video);
      } on Object {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Couldn’t start the call.')),
        );
      }
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(CampfireIcons.callAnswer, size: 20),
          color: CampfireTokens.mutedForeground,
          tooltip: 'Call ${conversation.recipient.username}',
          onPressed: () => start(video: false),
        ),
        IconButton(
          icon: const Icon(CampfireIcons.cameraOn, size: 20),
          color: CampfireTokens.mutedForeground,
          tooltip: 'Video call ${conversation.recipient.username}',
          onPressed: () => start(video: true),
        ),
      ],
    );
  }
}
