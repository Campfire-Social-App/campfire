import 'dart:async';

import 'package:campfire/core/files.dart';
import 'package:campfire/models/attachment.dart';
import 'package:campfire/state/api.dart';
import 'package:campfire/theme/icons.dart';
import 'package:campfire/theme/tokens.dart';
import 'package:campfire/widgets/image_lightbox.dart';
import 'package:campfire/widgets/media_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// How a message shows what came with it: photos as photos, video and audio with
/// players, anything else as a card you can save. Port of `AttachmentList.tsx`.
class AttachmentList extends ConsumerWidget {
  const AttachmentList({required this.attachments, super.key});

  final List<Attachment> attachments;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.read(apiClientProvider);
    final images = attachments.where(isImage).toList();
    final videos = attachments.where(isVideo).toList();
    final audio = attachments.where(isAudio).toList();
    final files = attachments.where(isPlainFile).toList();

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (images.isNotEmpty)
            _Images(images: images, resolve: api.resolveAssetUrl),
          for (final attachment in videos) ...[
            const SizedBox(height: 6),
            CampfireVideoPlayer(src: api.resolveAssetUrl(attachment.url)),
          ],
          for (final attachment in audio) ...[
            const SizedBox(height: 6),
            CampfireAudioPlayer(
              src: api.resolveAssetUrl(attachment.url),
              filename: attachment.filename,
            ),
          ],
          for (final attachment in files) ...[
            const SizedBox(height: 6),
            _FileCard(
              attachment: attachment,
              url: api.resolveAssetUrl(attachment.url),
            ),
          ],
        ],
      ),
    );
  }
}

/// One photo gets room to breathe; a set reads as a strip of thumbnails, so a
/// dozen photos cannot push the message off screen.
class _Images extends StatelessWidget {
  const _Images({required this.images, required this.resolve});

  final List<Attachment> images;
  final String Function(String) resolve;

  @override
  Widget build(BuildContext context) {
    if (images.length == 1) {
      final image = images.single;
      return ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380, maxHeight: 320),
        child: _Thumbnail(
          attachment: image,
          url: resolve(image.url),
          images: images,
          index: 0,
          fit: BoxFit.contain,
        ),
      );
    }

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final (index, image) in images.indexed)
          SizedBox(
            width: 132,
            height: 132,
            child: _Thumbnail(
              attachment: image,
              url: resolve(image.url),
              images: images,
              index: index,
              fit: BoxFit.cover,
            ),
          ),
      ],
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({
    required this.attachment,
    required this.url,
    required this.images,
    required this.index,
    required this.fit,
  });

  final Attachment attachment;
  final String url;
  final List<Attachment> images;
  final int index;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => unawaited(showImageLightbox(context, images: images, index: index)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: CampfireTokens.glassBorder),
          ),
          child: Hero(
            tag: 'attachment:${attachment.id}',
            child: Image.network(
              url,
              fit: fit,
              loadingBuilder: (context, child, progress) => progress == null
                  ? child
                  : const Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: CampfireTokens.ember,
                        ),
                      ),
                    ),
              errorBuilder: (_, _, _) => const Center(
                child: Icon(CampfireIcons.error, color: CampfireTokens.mutedForeground),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FileCard extends StatelessWidget {
  const _FileCard({required this.attachment, required this.url});

  final Attachment attachment;
  final String url;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 380),
      child: Material(
        color: CampfireTokens.glass,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: () => unawaited(openAttachment(url)),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: CampfireTokens.glassBorder),
            ),
            child: Row(
              children: [
                Icon(
                  fileIconFor(attachment.contentType),
                  size: 22,
                  color: CampfireTokens.mutedForeground,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        attachment.filename,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(fontSize: 14),
                      ),
                      Text(
                        formatBytes(attachment.sizeBytes),
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 12,
                          color: CampfireTokens.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  CampfireIcons.download,
                  size: 16,
                  color: CampfireTokens.mutedForeground,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
