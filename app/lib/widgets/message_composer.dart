import 'dart:async';

import 'package:campfire/api/api_exception.dart';
import 'package:campfire/core/files.dart';
import 'package:campfire/core/mentions.dart';
import 'package:campfire/models/attachment.dart';
import 'package:campfire/models/message.dart';
import 'package:campfire/state/api.dart';
import 'package:campfire/state/channels.dart';
import 'package:campfire/state/gateway.dart';
import 'package:campfire/state/messages.dart';
import 'package:campfire/state/server.dart';
import 'package:campfire/state/users.dart';
import 'package:campfire/theme/icons.dart';
import 'package:campfire/theme/tokens.dart';
import 'package:campfire/widgets/user_avatar.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// How often a keystroke turns into a `TYPING_START` frame. Same throttle as
/// the web composer.
const _typingThrottle = Duration(seconds: 3);

/// A file on its way up: shown in the strip with its own progress bar.
class _PendingUpload {
  _PendingUpload({required this.key, required this.name, this.bytes});

  final String key;
  final String name;

  /// Local preview while it uploads — the server URL only exists afterwards.
  final Uint8List? bytes;

  double progress = 0;
}

/// Where a message is written. Port of `MessageComposer.tsx`: text, attachments
/// with per-file progress, the reply banner, and `@`/`#` autocomplete.
class MessageComposer extends ConsumerStatefulWidget {
  const MessageComposer({
    required this.channelId,
    required this.placeholder,
    this.replyingTo,
    this.onCancelReply,
    this.onSent,
    super.key,
  });

  /// Text channel or DM conversation to post into.
  final String channelId;
  final String placeholder;
  final Message? replyingTo;
  final VoidCallback? onCancelReply;
  final VoidCallback? onSent;

  @override
  ConsumerState<MessageComposer> createState() => _MessageComposerState();
}

class _MessageComposerState extends ConsumerState<MessageComposer> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  final _attachments = <Attachment>[];
  final _uploads = <_PendingUpload>[];

  MentionQuery? _mention;
  DateTime _lastTypingSentAt = DateTime.fromMillisecondsSinceEpoch(0);
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  bool get _canSend =>
      !_sending && (_controller.text.trim().isNotEmpty || _attachments.isNotEmpty);

  void _onChanged() {
    setState(() {
      _mention = activeMentionQuery(
        _controller.text,
        _controller.selection.baseOffset.clamp(0, _controller.text.length),
      );
    });
    _notifyTyping();
  }

  void _notifyTyping() {
    if (_controller.text.isEmpty) return;
    final now = DateTime.now();
    if (now.difference(_lastTypingSentAt) < _typingThrottle) return;
    _lastTypingSentAt = now;
    ref.read(gatewayProvider).sendTyping(widget.channelId);
  }

  List<MentionCandidate> get _candidates {
    final query = _mention;
    if (query == null) return const [];
    return mentionCandidates(
      query.trigger,
      query.query,
      ref.read(usersProvider).value ?? const [],
      ref.read(channelsProvider),
    );
  }

  void _insertMention(MentionCandidate candidate) {
    final query = _mention;
    if (query == null) return;

    final cursor = _controller.selection.baseOffset.clamp(0, _controller.text.length);
    final before = _controller.text.substring(0, query.start);
    final after = _controller.text.substring(cursor);
    final inserted = '${query.trigger.character}${candidate.insert} ';

    _controller.value = TextEditingValue(
      text: '$before$inserted$after',
      selection: TextSelection.collapsed(offset: before.length + inserted.length),
    );
    setState(() => _mention = null);
    _focus.requestFocus();
  }

  Future<void> _pickFiles() async {
    final picked = await FilePicker.pickFiles();
    await _upload([
      for (final file in picked)
        (
          name: file.name,
          path: file.path,
          // Only read the whole thing into memory where there is no path to
          // stream from — that is the web build.
          bytes: file.path == null ? await file.readAsBytes() : null,
          size: await file.length(),
        ),
    ]);
  }

  Future<void> _pickImages({required ImageSource source}) async {
    final picker = ImagePicker();
    final picked = source == ImageSource.camera
        ? [?await picker.pickImage(source: source)]
        : await picker.pickMultiImage();

    await _upload([
      for (final file in picked)
        (
          name: file.name,
          path: kIsWeb ? null : file.path,
          bytes: kIsWeb ? await file.readAsBytes() : null,
          size: await file.length(),
        ),
    ]);
  }

  /// One at a time and in order, so a batch of photos arrives in the message in
  /// the order they were picked rather than in whichever finished first.
  Future<void> _upload(
    List<({String name, String? path, Uint8List? bytes, int size})> files,
  ) async {
    final maxBytes = ref.read(serverProvider)?.maxUploadBytes ?? 25 * 1024 * 1024;

    for (final file in files) {
      if (file.size > maxBytes) {
        _toast('${file.name} is larger than ${formatBytes(maxBytes)}.');
        continue;
      }

      final upload = _PendingUpload(
        key: '${DateTime.now().microsecondsSinceEpoch}:${file.name}',
        name: file.name,
        bytes: file.bytes,
      );
      setState(() => _uploads.add(upload));

      try {
        final attachment = await ref.read(apiProvider).uploadAttachment(
              filePath: file.path,
              bytes: file.path == null ? file.bytes : null,
              filename: file.name,
              onProgress: (fraction) {
                if (!mounted) return;
                setState(() => upload.progress = fraction);
              },
            );
        if (!mounted) return;
        setState(() => _attachments.add(attachment));
      } on ApiException catch (error) {
        _toast(error.message);
      } finally {
        if (mounted) setState(() => _uploads.remove(upload));
      }
    }
  }

  Future<void> _send() async {
    final trimmed = _controller.text.trim();
    if (trimmed.isEmpty && _attachments.isEmpty) return;
    if (_uploads.isNotEmpty) {
      _toast('Still uploading — one moment.');
      return;
    }

    final replyingTo = widget.replyingTo;
    setState(() => _sending = true);
    try {
      await ref.read(messagesProvider(widget.channelId).notifier).send(
            content: trimmed,
            attachmentIds: [for (final attachment in _attachments) attachment.id],
            replyToId: replyingTo?.id,
            replyTo: replyingTo == null
                ? null
                : MessageReplyPreview(
                    id: replyingTo.id,
                    author: replyingTo.author,
                    content: replyingTo.content,
                    hasAttachments: replyingTo.attachments.isNotEmpty,
                  ),
          );
      if (!mounted) return;
      _controller.clear();
      setState(() {
        _attachments.clear();
        _mention = null;
      });
      widget.onCancelReply?.call();
      widget.onSent?.call();
    } on ApiException catch (error) {
      // The row stays in the list marked as failed, so nothing typed is lost —
      // this is only the immediate feedback.
      _toast(error.message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final candidates = _candidates;

    // The shell draws edge to edge so the ember glow reaches the bottom of the
    // screen, which puts the gesture bar over anything not inset here. With the
    // keyboard up the inset collapses and the Scaffold does the lifting.
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_mention != null && candidates.isNotEmpty)
              _MentionList(
                candidates: candidates,
                trigger: _mention!.trigger,
                onSelected: _insertMention,
              ),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _focus.hasFocus
                      ? CampfireTokens.emberTintBorder
                      : CampfireTokens.glassBorder,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.replyingTo != null)
                    _ReplyBanner(
                      message: widget.replyingTo!,
                      onCancel: widget.onCancelReply,
                    ),
                  if (_attachments.isNotEmpty || _uploads.isNotEmpty) _attachmentStrip(),
                  _inputRow(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _attachmentStrip() {
    final api = ref.read(apiClientProvider);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: CampfireTokens.glassBorder)),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final attachment in _attachments)
            _StripTile(
              label: attachment.filename,
              imageUrl: isImage(attachment) ? api.resolveAssetUrl(attachment.url) : null,
              onRemove: () => setState(() => _attachments.remove(attachment)),
            ),
          for (final upload in _uploads)
            _StripTile(
              label: upload.name,
              previewBytes: upload.bytes,
              progress: upload.progress,
            ),
        ],
      ),
    );
  }

  Widget _inputRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          IconButton(
            icon: const Icon(CampfireIcons.attach, size: 20),
            color: CampfireTokens.mutedForeground,
            tooltip: 'Attach',
            onPressed: () => _showAttachMenu(context),
          ),
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focus,
              minLines: 1,
              maxLines: 6,
              textCapitalization: TextCapitalization.sentences,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 15),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                hintText: widget.placeholder,
                hintStyle: const TextStyle(
                  color: CampfireTokens.mutedForeground,
                  fontSize: 15,
                ),
              ),
              onTap: _onChanged,
            ),
          ),
          IconButton(
            icon: const Icon(CampfireIcons.send, size: 18),
            color: _canSend ? CampfireTokens.primary : CampfireTokens.mutedForeground,
            tooltip: 'Send',
            onPressed: _canSend ? () => unawaited(_send()) : null,
          ),
        ],
      ),
    );
  }

  /// The phone's answer to a file input: camera, gallery, or anything on disk.
  void _showAttachMenu(BuildContext context) {
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        backgroundColor: CampfireTokens.popover,
        showDragHandle: true,
        builder: (sheetContext) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(LucideIcons.image, size: 18),
                title: const Text('Photos'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  unawaited(_pickImages(source: ImageSource.gallery));
                },
              ),
              // The web build has no camera to open; the picker would throw.
              if (!kIsWeb)
                ListTile(
                  leading: const Icon(LucideIcons.camera, size: 18),
                  title: const Text('Camera'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    unawaited(_pickImages(source: ImageSource.camera));
                  },
                ),
              ListTile(
                leading: const Icon(CampfireIcons.file, size: 18),
                title: const Text('File'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  unawaited(_pickFiles());
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MentionList extends StatelessWidget {
  const _MentionList({
    required this.candidates,
    required this.trigger,
    required this.onSelected,
  });

  final List<MentionCandidate> candidates;
  final MentionTrigger trigger;
  final void Function(MentionCandidate) onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      constraints: const BoxConstraints(maxHeight: 220),
      decoration: BoxDecoration(
        color: CampfireTokens.popover,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: CampfireTokens.glassBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListView(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        children: [
          for (final candidate in candidates)
            InkWell(
              onTap: () => onSelected(candidate),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    if (trigger == MentionTrigger.channel)
                      const _GlyphBubble(icon: CampfireIcons.textChannel)
                    else if (candidate.key == everyoneMention)
                      const _GlyphBubble(icon: CampfireIcons.mention)
                    else
                      UserAvatar(username: candidate.label, size: AvatarSize.sm),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        candidate.label,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontSize: 14,
                              color: trigger == MentionTrigger.channel
                                  ? CampfireTokens.foreground
                                  : usernameColorFor(candidate.label),
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _GlyphBubble extends StatelessWidget {
  const _GlyphBubble({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: const BoxDecoration(color: CampfireTokens.glass, shape: BoxShape.circle),
      child: Icon(icon, size: 14, color: CampfireTokens.mutedForeground),
    );
  }
}

class _ReplyBanner extends StatelessWidget {
  const _ReplyBanner({required this.message, this.onCancel});

  final Message message;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: CampfireTokens.glassBorder)),
      ),
      child: Row(
        children: [
          const Icon(CampfireIcons.reply, size: 14, color: CampfireTokens.mutedForeground),
          const SizedBox(width: 6),
          Text(
            'Replying to ',
            style: theme.textTheme.labelMedium?.copyWith(
              fontSize: 12,
              color: CampfireTokens.mutedForeground,
            ),
          ),
          Flexible(
            child: Text(
              message.author.username,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: usernameColorFor(message.author.username),
              ),
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(CampfireIcons.close, size: 14),
            color: CampfireTokens.mutedForeground,
            visualDensity: VisualDensity.compact,
            tooltip: 'Cancel reply',
            onPressed: onCancel,
          ),
        ],
      ),
    );
  }
}

/// One square in the attachment strip: an uploaded file, or one still going up
/// with its progress bar across the bottom.
class _StripTile extends StatelessWidget {
  const _StripTile({
    required this.label,
    this.imageUrl,
    this.previewBytes,
    this.progress,
    this.onRemove,
  });

  final String label;
  final String? imageUrl;
  final Uint8List? previewBytes;
  final double? progress;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final uploading = progress != null;

    return SizedBox(
      width: 64,
      height: 64,
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: CampfireTokens.glass,
                  border: Border.all(color: CampfireTokens.glassBorder),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: switch ((imageUrl, previewBytes)) {
                  (final String url, _) => Image.network(url, fit: BoxFit.cover),
                  (_, final Uint8List bytes) => Opacity(
                      opacity: 0.4,
                      child: Image.memory(bytes, fit: BoxFit.cover),
                    ),
                  _ => Padding(
                      padding: const EdgeInsets.all(4),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            CampfireIcons.file,
                            size: 18,
                            color: CampfireTokens.mutedForeground,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontFamily: 'Geist',
                              fontSize: 9,
                              color: CampfireTokens.mutedForeground,
                            ),
                          ),
                        ],
                      ),
                    ),
                },
              ),
            ),
          ),
          if (uploading)
            Positioned(
              left: 4,
              right: 4,
              bottom: 4,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 3,
                  backgroundColor: Colors.black.withValues(alpha: 0.5),
                  valueColor: const AlwaysStoppedAnimation(CampfireTokens.primary),
                ),
              ),
            ),
          if (onRemove != null)
            Positioned(
              top: 0,
              right: 0,
              child: GestureDetector(
                onTap: onRemove,
                child: Container(
                  width: 20,
                  height: 20,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(CampfireIcons.close, size: 12, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
