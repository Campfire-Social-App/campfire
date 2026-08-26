import 'dart:async';

import 'package:campfire/api/api_exception.dart';
import 'package:campfire/core/mentions.dart';
import 'package:campfire/models/events.dart';
import 'package:campfire/models/message.dart';
import 'package:campfire/state/api.dart';
import 'package:campfire/state/auth.dart';
import 'package:campfire/state/messages.dart';
import 'package:campfire/theme/icons.dart';
import 'package:campfire/theme/tokens.dart';
import 'package:campfire/widgets/attachment_list.dart';
import 'package:campfire/widgets/bot_badge.dart';
import 'package:campfire/widgets/mention_text.dart';
import 'package:campfire/widgets/user_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// The three reactions, in the order the web client lists them.
const _reactions = <(ReactionType, String, String)>[
  (ReactionType.like, '👍', 'Like'),
  (ReactionType.love, '❤️', 'Love'),
  (ReactionType.laugh, '😂', 'Laugh'),
];

/// One message in the history. Port of `MessageItem.tsx`.
///
/// Flat and always left-aligned — no bubbles, no mirrored layout for your own
/// messages, same as the web client. What changes for the phone is how the
/// actions are reached: there is no hover, so a long press opens the sheet the
/// hover toolbar stands in for, and a double tap likes the message.
class MessageItem extends ConsumerStatefulWidget {
  const MessageItem({
    required this.message,
    required this.showHeader,
    required this.onReply,
    super.key,
  });

  final Message message;

  /// False for a message that continues a run from the same author — it gets
  /// the timestamp gutter instead of an avatar and a name.
  final bool showHeader;

  final void Function(Message message) onReply;

  @override
  ConsumerState<MessageItem> createState() => _MessageItemState();
}

class _MessageItemState extends ConsumerState<MessageItem> {
  bool _editing = false;
  ReactionType? _pending;
  TextEditingController? _draft;

  @override
  void dispose() {
    _draft?.dispose();
    super.dispose();
  }

  Message get _message => widget.message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentUser = switch (ref.watch(authProvider)) {
      AuthAuthenticated(:final user) => user,
      _ => null,
    };
    final isOwn = currentUser?.id == _message.author.id;
    final isMentioned = currentUser != null &&
        messageMentionsUser(_message.content, currentUser.username);
    final time = DateFormat('HH:mm').format(_message.createdAt.toLocal());

    return GestureDetector(
      onLongPress: _message.pending ? null : () => _showActions(context, isOwn: isOwn),
      onDoubleTap: _message.pending ? null : () => unawaited(_toggleReaction(ReactionType.like)),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: EdgeInsets.fromLTRB(16, widget.showHeader ? 10 : 1, 16, 1),
        color: isMentioned ? CampfireTokens.emberTint.withValues(alpha: 0.1 * 0.35) : null,
        child: Opacity(
          // A message on its way to the server is dimmed until it lands, so a
          // slow network is visible rather than silently pending.
          opacity: _message.pending && !_message.sendFailed ? 0.55 : 1,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 36,
                child: widget.showHeader
                    ? UserAvatar(
                        username: _message.author.username,
                        avatarUrl: _message.author.avatarUrl,
                      )
                    : Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(
                          time,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontSize: 10,
                            color: CampfireTokens.mutedForeground.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_message.replyTo != null) _QuotedLine(preview: _message.replyTo!),
                    if (widget.showHeader)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Flexible(
                            child: Text(
                              isOwn ? 'You' : _message.author.username,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: usernameColorFor(_message.author.username),
                              ),
                            ),
                          ),
                          if (_message.author.isBot) ...[
                            const SizedBox(width: 6),
                            const BotBadge(),
                          ],
                          const SizedBox(width: 8),
                          Text(
                            time,
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontSize: 11,
                              color: CampfireTokens.mutedForeground,
                            ),
                          ),
                        ],
                      ),
                    if (_editing)
                      _EditField(
                        controller: _draft!,
                        onCancel: _cancelEdit,
                        onSave: () => unawaited(_saveEdit()),
                      )
                    // A message can be attachments alone — an empty line would
                    // still take up space under the author's name.
                    else if (_message.content.trim().isNotEmpty)
                      _Body(message: _message, currentUsername: currentUser?.username),
                    if (_message.attachments.isNotEmpty)
                      AttachmentList(attachments: _message.attachments),
                    if (_message.reactions.isNotEmpty) _reactionRow(),
                    if (_message.sendFailed) _failedRow(theme),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _reactionRow() {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(
        spacing: 4,
        children: [
          for (final (type, emoji, label) in _reactions)
            if (_message.reactions.where((r) => r.type == type).firstOrNull
                case final reaction?)
              _ReactionChip(
                emoji: emoji,
                label: label,
                count: reaction.count,
                active: reaction.reactedByMe,
                busy: _pending == type,
                onTap: () => unawaited(_toggleReaction(type)),
              ),
        ],
      ),
    );
  }

  Widget _failedRow(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          const Icon(CampfireIcons.warning, size: 12, color: CampfireTokens.destructive),
          const SizedBox(width: 4),
          Text(
            'Not sent.',
            style: theme.textTheme.labelMedium?.copyWith(
              fontSize: 11,
              color: CampfireTokens.destructive,
            ),
          ),
          TextButton(
            onPressed: () => unawaited(
              ref.read(messagesProvider(_message.channelId).notifier).retry(_message),
            ),
            style: TextButton.styleFrom(
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Retry', style: TextStyle(fontSize: 11)),
          ),
          TextButton(
            onPressed: () =>
                ref.read(messagesProvider(_message.channelId).notifier).discard(_message.id),
            style: TextButton.styleFrom(
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: CampfireTokens.mutedForeground,
            ),
            child: const Text('Discard', style: TextStyle(fontSize: 11)),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleReaction(ReactionType type) async {
    if (_pending != null || _message.pending) return;

    final current = _message.reactions.where((r) => r.type == type).firstOrNull;
    setState(() => _pending = type);
    try {
      final api = ref.read(apiProvider);
      final result = current?.reactedByMe ?? false
          ? await api.removeReaction(_message.id, type)
          : await api.addReaction(_message.id, type);

      final me = switch (ref.read(authProvider)) {
        AuthAuthenticated(:final user) => user.id,
        _ => null,
      };
      if (me == null) return;

      // The broadcast will say the same thing, but not necessarily before the
      // next frame — applying the answer here keeps the tap instant.
      ref.read(messagesProvider(_message.channelId).notifier).applyReaction(
            MessageReactionUpdateData(
              messageId: _message.id,
              channelId: _message.channelId,
              type: type,
              count: result.count,
              userId: me,
              reacted: result.reactedByMe,
            ),
          );
    } on ApiException catch (error) {
      _toast(error.message);
    } finally {
      if (mounted) setState(() => _pending = null);
    }
  }

  void _startEdit() {
    setState(() {
      _draft = TextEditingController(text: _message.content);
      _editing = true;
    });
  }

  void _cancelEdit() {
    setState(() {
      _editing = false;
      _draft?.dispose();
      _draft = null;
    });
  }

  Future<void> _saveEdit() async {
    final trimmed = _draft?.text.trim() ?? '';
    if (trimmed.isNotEmpty && trimmed != _message.content) {
      try {
        await ref.read(apiProvider).editMessage(_message.id, trimmed);
      } on ApiException catch (error) {
        _toast(error.message);
        return;
      }
    }
    _cancelEdit();
  }

  Future<void> _delete() async {
    try {
      await ref.read(apiProvider).deleteMessage(_message.id);
    } on ApiException catch (error) {
      _toast(error.message);
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  /// The mobile stand-in for the hover toolbar: reactions across the top, then
  /// the actions as rows.
  void _showActions(BuildContext context, {required bool isOwn}) {
    final isAdmin = switch (ref.read(authProvider)) {
      AuthAuthenticated(:final user) => user.isAdmin,
      _ => false,
    };
    final canModify = isOwn || isAdmin;
    unawaited(HapticFeedback.selectionClick());

    unawaited(
      showModalBottomSheet<void>(
        context: context,
        backgroundColor: CampfireTokens.popover,
        showDragHandle: true,
        builder: (sheetContext) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    for (final (type, emoji, label) in _reactions)
                      IconButton(
                        tooltip: label,
                        iconSize: 26,
                        onPressed: () {
                          Navigator.of(sheetContext).pop();
                          unawaited(_toggleReaction(type));
                        },
                        icon: Text(emoji, style: const TextStyle(fontSize: 24)),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1, color: CampfireTokens.glassBorder),
              ListTile(
                leading: const Icon(CampfireIcons.reply, size: 18),
                title: const Text('Reply'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  widget.onReply(_message);
                },
              ),
              if (_message.content.trim().isNotEmpty)
                ListTile(
                  leading: const Icon(CampfireIcons.copy, size: 18),
                  title: const Text('Copy text'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    unawaited(Clipboard.setData(ClipboardData(text: _message.content)));
                  },
                ),
              if (canModify && isOwn)
                ListTile(
                  leading: const Icon(CampfireIcons.edit, size: 18),
                  title: const Text('Edit'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _startEdit();
                  },
                ),
              if (canModify)
                ListTile(
                  leading: const Icon(
                    CampfireIcons.delete,
                    size: 18,
                    color: CampfireTokens.destructive,
                  ),
                  title: const Text(
                    'Delete',
                    style: TextStyle(color: CampfireTokens.destructive),
                  ),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    unawaited(_confirmDelete(context));
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: CampfireTokens.popover,
        title: const Text('Delete message?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: CampfireTokens.destructive),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) await _delete();
  }
}

/// The message text itself, with mentions picked out and the edited marker
/// trailing it.
class _Body extends StatelessWidget {
  const _Body({required this.message, this.currentUsername});

  final Message message;
  final String? currentUsername;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium!.copyWith(
          fontSize: 15,
          height: 1.35,
          color: CampfireTokens.foreground,
        );

    return Padding(
      padding: const EdgeInsets.only(top: 1),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.end,
        children: [
          MentionText(
            content: message.content,
            style: style,
            currentUsername: currentUsername,
          ),
          if (message.editedAt != null)
            Padding(
              padding: const EdgeInsets.only(left: 5, bottom: 2),
              child: Text(
                '(edited)',
                style: style.copyWith(
                  fontSize: 10,
                  color: CampfireTokens.mutedForeground,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The line above a reply: who was quoted, and the first of what they said.
class _QuotedLine extends StatelessWidget {
  const _QuotedLine({required this.preview});

  final MessageReplyPreview preview;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final quoted = preview.content.trim().isNotEmpty
        ? preview.content.trim()
        : (preview.hasAttachments ? 'Attachment' : '');

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          Transform.flip(
            flipX: true,
            child: const Icon(
              CampfireIcons.quoted,
              size: 12,
              color: CampfireTokens.mutedForeground,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            preview.author.username,
            style: theme.textTheme.labelMedium?.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: usernameColorFor(preview.author.username),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              quoted,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(
                fontSize: 12,
                color: CampfireTokens.mutedForeground.withValues(alpha: 0.8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EditField extends StatelessWidget {
  const _EditField({required this.controller, required this.onCancel, required this.onSave});

  final TextEditingController controller;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: controller,
            autofocus: true,
            maxLines: null,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => onSave(),
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              TextButton(
                onPressed: onCancel,
                style: TextButton.styleFrom(
                  foregroundColor: CampfireTokens.mutedForeground,
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                ),
                child: const Text('Cancel', style: TextStyle(fontSize: 12)),
              ),
              TextButton(
                onPressed: onSave,
                style: TextButton.styleFrom(
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                ),
                child: const Text('Save', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReactionChip extends StatelessWidget {
  const _ReactionChip({
    required this.emoji,
    required this.label,
    required this.count,
    required this.active,
    required this.busy,
    required this.onTap,
  });

  final String emoji;
  final String label;
  final int count;
  final bool active;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Material(
        color: active
            ? CampfireTokens.primary.withValues(alpha: 0.15)
            : Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: busy ? null : onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            height: 26,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: active
                    ? CampfireTokens.primary.withValues(alpha: 0.5)
                    : CampfireTokens.glassBorder,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 12)),
                const SizedBox(width: 4),
                Text(
                  '$count',
                  style: TextStyle(
                    fontFamily: 'Geist',
                    fontSize: 12,
                    color: active
                        ? CampfireTokens.foreground
                        : CampfireTokens.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
