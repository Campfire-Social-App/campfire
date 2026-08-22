import 'dart:async';

import 'package:campfire/core/ringtone.dart';
import 'package:campfire/models/events.dart';
import 'package:campfire/screens/shell_screen.dart';
import 'package:campfire/state/calls.dart';
import 'package:campfire/state/users.dart';
import 'package:campfire/theme/icons.dart';
import 'package:campfire/theme/tokens.dart';
import 'package:campfire/widgets/user_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// How long a call rings before giving up on its own. Without it, an unanswered
/// call rings until somebody closes the app.
const ringTimeout = Duration(seconds: 45);

/// Everything about a call that has to outlive the conversation being on
/// screen: the tones, the give-up timers, and the incoming-call card. Wrapped
/// around the shell once — a call can arrive while you are anywhere in the app.
///
/// Port of `CallCenter.tsx`.
class CallCenter extends ConsumerStatefulWidget {
  const CallCenter({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<CallCenter> createState() => _CallCenterState();
}

class _CallCenterState extends ConsumerState<CallCenter> {
  Timer? _incomingTimer;
  Timer? _outgoingTimer;

  @override
  void dispose() {
    _incomingTimer?.cancel();
    _outgoingTimer?.cancel();
    super.dispose();
  }

  /// One tone at a time, and a call ringing *at* us wins: it is the one that
  /// needs answering.
  void _ring({required String? incoming, required String? outgoing}) {
    final ringtone = ref.read(ringtoneProvider);
    if (incoming != null) {
      ringtone.startIncoming();
    } else if (outgoing != null) {
      ringtone.startOutgoing();
    } else {
      ringtone.stop();
    }
  }

  void _armTimers({required String? incoming, required String? outgoing}) {
    _incomingTimer?.cancel();
    _incomingTimer = incoming == null
        ? null
        : Timer(ringTimeout, () {
            // Letting it ring out is a decline: the caller has to be told, and
            // the server has to stop holding the ring open.
            unawaited(ref.read(callsProvider.notifier).decline(incoming).catchError((_) {}));
          });

    _outgoingTimer?.cancel();
    _outgoingTimer = outgoing == null
        ? null
        : Timer(ringTimeout, () {
            _showNotice('No answer.');
            unawaited(ref.read(callsProvider.notifier).hangUp(outgoing).catchError((_) {}));
          });
  }

  void _showNotice(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    ref
      ..listen(callsProvider.select((s) => (s.incoming?.channelId, s.outgoing)), (_, next) {
        final (incoming, outgoing) = next;
        _ring(incoming: incoming, outgoing: outgoing);
        _armTimers(incoming: incoming, outgoing: outgoing);
      })
      // Declined, unavailable, missed: the call is already gone from the state,
      // so the sentence is the only trace of it left.
      ..listen(callsProvider.select((s) => s.notice), (_, notice) {
        if (notice != null) _showNotice(notice.message);
      });

    final incoming = ref.watch(callsProvider).incoming;

    return Stack(
      children: [
        widget.child,
        if (incoming != null)
          // Deliberately not a modal: an unwanted call should not take the app
          // hostage, so this floats over a corner and leaves the rest usable.
          // On a phone the corner is the full width; on a wide window it is the
          // same 18rem card the web client shows.
          Positioned(
            left: MediaQuery.sizeOf(context).width >= ShellScreen.wideBreakpoint ? null : 12,
            right: 12,
            bottom: 12,
            child: SafeArea(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: _IncomingCard(call: incoming),
              ),
            ),
          ),
      ],
    );
  }
}

class _IncomingCard extends ConsumerWidget {
  const _IncomingCard({required this.call});

  final DMCallData call;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final caller = call.from;
    final calls = ref.read(callsProvider.notifier);

    Future<void> answer({required bool video}) async {
      try {
        await calls.accept(call.channelId, video: video);
      } on Object {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Couldn’t join the call.')),
        );
      }
    }

    return Material(
      color: CampfireTokens.popover,
      elevation: 12,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: CampfireTokens.glassBorder),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                UserAvatar(
                  username: caller.username,
                  avatarUrl: ref.watch(userByIdProvider(caller.id))?.avatarUrl,
                  size: AvatarSize.lg,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        caller.username,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall,
                      ),
                      Text(
                        'Incoming call…',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: CampfireTokens.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => answer(video: false),
                    style: FilledButton.styleFrom(backgroundColor: CampfireTokens.online),
                    icon: const Icon(CampfireIcons.callAnswer, size: 18),
                    label: const Text('Accept'),
                  ),
                ),
                const SizedBox(width: 8),
                _RoundAction(
                  icon: CampfireIcons.cameraOn,
                  tooltip: 'Accept with video',
                  background: CampfireTokens.glass,
                  foreground: CampfireTokens.foreground,
                  onTap: () => answer(video: true),
                ),
                const SizedBox(width: 8),
                _RoundAction(
                  icon: CampfireIcons.callEnd,
                  tooltip: 'Decline',
                  background: CampfireTokens.destructive,
                  foreground: Colors.white,
                  onTap: () => calls.decline(call.channelId).catchError((_) {}),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({
    required this.icon,
    required this.tooltip,
    required this.background,
    required this.foreground,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final Color background;
  final Color foreground;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: background,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(icon, size: 18, color: foreground),
          ),
        ),
      ),
    );
  }
}
