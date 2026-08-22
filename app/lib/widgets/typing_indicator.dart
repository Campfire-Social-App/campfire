import 'dart:async';

import 'package:campfire/state/presence.dart';
import 'package:campfire/state/users.dart';
import 'package:campfire/theme/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// "ana is typing…", under the history and above the composer.
///
/// Port of `TypingIndicator.tsx`, including the reserved height: the row is
/// always there, so the composer does not jump a line every time someone starts
/// and stops typing.
class TypingIndicator extends ConsumerStatefulWidget {
  const TypingIndicator({required this.channelId, super.key});

  final String channelId;

  @override
  ConsumerState<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends ConsumerState<TypingIndicator> {
  Timer? _prune;

  @override
  void initState() {
    super.initState();
    // The server never says "stopped typing", so entries expire on a clock.
    _prune = Timer.periodic(
      const Duration(seconds: 2),
      (_) => ref.read(typingProvider.notifier).prune(widget.channelId),
    );
  }

  @override
  void dispose() {
    _prune?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final typing = ref.watch(typingInChannelProvider(widget.channelId));
    if (typing.isEmpty) return const SizedBox(height: 20);

    final names = [
      for (final userId in typing) ref.watch(userByIdProvider(userId))?.username ?? 'someone',
    ];

    final label = names.length == 1
        ? '${names.first} is typing…'
        : '${names.sublist(0, names.length - 1).join(', ')} and ${names.last} are typing…';

    return SizedBox(
      height: 20,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text(
          label,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: 12,
                color: CampfireTokens.mutedForeground,
              ),
        ),
      ),
    );
  }
}
