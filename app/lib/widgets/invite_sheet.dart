import 'dart:async';

import 'package:campfire/api/api_exception.dart';
import 'package:campfire/state/api.dart';
import 'package:campfire/theme/icons.dart';
import 'package:campfire/theme/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Mints an invite code and hands it over to be shared — the mobile shape of
/// `InviteDialog.tsx`. The code is what `RegisterScreen` asks for, so what gets
/// copied is the code itself rather than a URL the app cannot open yet (deep
/// links are task I4).
Future<void> showInviteSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: CampfireTokens.popover,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _InviteSheet(),
  );
}

class _InviteSheet extends ConsumerStatefulWidget {
  const _InviteSheet();

  @override
  ConsumerState<_InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends ConsumerState<_InviteSheet> {
  late String _code;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_create());
  }

  Future<void> _create() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final invite = await ref.read(apiProvider).createInvite();
      if (!mounted) return;
      setState(() {
        _code = invite.code;
        _loading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Invite people', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text(
              'Anyone with this code can create an account on this server.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: CampfireTokens.mutedForeground,
              ),
            ),
            const SizedBox(height: 20),
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: CampfireTokens.ember,
                  ),
                ),
              )
            else if (_error != null)
              _ErrorRow(message: _error!, onRetry: _create)
            else
              _CodeRow(code: _code),
          ],
        ),
      ),
    );
  }
}

class _CodeRow extends StatelessWidget {
  const _CodeRow({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: CampfireTokens.muted,
              borderRadius: BorderRadius.circular(CampfireTokens.radius),
              border: Border.all(color: CampfireTokens.border),
            ),
            child: Text(
              code,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    letterSpacing: 1.5,
                  ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filled(
          icon: const Icon(CampfireIcons.copy, size: 18),
          tooltip: 'Copy code',
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: code));
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Invite code copied.')),
            );
          },
        ),
      ],
    );
  }
}

class _ErrorRow extends StatelessWidget {
  const _ErrorRow({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(CampfireIcons.error, size: 18, color: CampfireTokens.destructive),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: CampfireTokens.destructive,
                ),
          ),
        ),
        TextButton(onPressed: () => unawaited(onRetry()), child: const Text('Retry')),
      ],
    );
  }
}
