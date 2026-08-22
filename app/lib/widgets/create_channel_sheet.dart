import 'package:campfire/api/api_exception.dart';
import 'package:campfire/models/channel.dart';
import 'package:campfire/state/api.dart';
import 'package:campfire/theme/icons.dart';
import 'package:campfire/theme/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Admin-only channel creation, the mobile shape of `CreateChannelDialog.tsx`.
///
/// Nothing is added to the list here: the server answers the POST and then
/// pushes `CHANNEL_CREATE` to everyone, this client included, so the sidebar
/// updates through the same path it would for a channel someone else made.
Future<void> showCreateChannelSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: CampfireTokens.popover,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _CreateChannelSheet(),
  );
}

class _CreateChannelSheet extends ConsumerStatefulWidget {
  const _CreateChannelSheet();

  @override
  ConsumerState<_CreateChannelSheet> createState() => _CreateChannelSheetState();
}

class _CreateChannelSheetState extends ConsumerState<_CreateChannelSheet> {
  final _name = TextEditingController();
  ChannelType _type = ChannelType.text;
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _name.text.trim();
    if (name.isEmpty || _saving) return;

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(apiProvider).createChannel(name, _type);
      if (!mounted) return;
      Navigator.of(context).pop();
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Create channel', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 20),
            SegmentedButton<ChannelType>(
              segments: const [
                ButtonSegment(
                  value: ChannelType.text,
                  icon: Icon(CampfireIcons.textChannel, size: 16),
                  label: Text('Text'),
                ),
                ButtonSegment(
                  value: ChannelType.voice,
                  icon: Icon(CampfireIcons.voiceChannel, size: 16),
                  label: Text('Voice'),
                ),
              ],
              selected: {_type},
              onSelectionChanged: (selection) => setState(() => _type = selection.first),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              autofocus: true,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Channel name',
                hintText: 'general',
              ),
              onSubmitted: (_) => _submit(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: CampfireTokens.destructive,
                ),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _submit,
                child: Text(_saving ? 'Creating…' : 'Create'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
