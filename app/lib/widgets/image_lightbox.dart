import 'dart:async';

import 'package:campfire/core/files.dart';
import 'package:campfire/models/attachment.dart';
import 'package:campfire/state/api.dart';
import 'package:campfire/theme/icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// Full-screen viewer for the images of one message. Port of
/// `ImageLightbox.tsx`, with the gestures a phone expects on top: pinch to
/// zoom, swipe sideways for the next image, swipe down to dismiss.
Future<void> showImageLightbox(
  BuildContext context, {
  required List<Attachment> images,
  required int index,
}) {
  return Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      pageBuilder: (_, _, _) => _ImageLightbox(images: images, initialIndex: index),
    ),
  );
}

class _ImageLightbox extends ConsumerStatefulWidget {
  const _ImageLightbox({required this.images, required this.initialIndex});

  final List<Attachment> images;
  final int initialIndex;

  @override
  ConsumerState<_ImageLightbox> createState() => _ImageLightboxState();
}

class _ImageLightboxState extends ConsumerState<_ImageLightbox> {
  late final PageController _pages = PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;

  /// Dismiss-by-drag only applies at rest: once the image is zoomed in, a drag
  /// is panning it, not throwing it away.
  bool _zoomed = false;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final image = widget.images[_index];
    final api = ref.read(apiClientProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            onVerticalDragEnd: (details) {
              if (!_zoomed && (details.primaryVelocity ?? 0).abs() > 300) {
                Navigator.of(context).pop();
              }
            },
            child: PageView.builder(
              controller: _pages,
              itemCount: widget.images.length,
              onPageChanged: (next) => setState(() {
                _index = next;
                _zoomed = false;
              }),
              itemBuilder: (context, i) => InteractiveViewer(
                maxScale: 5,
                onInteractionEnd: (_) => setState(() => _zoomed = true),
                child: Center(
                  child: Hero(
                    tag: 'attachment:${widget.images[i].id}',
                    child: Image.network(
                      api.resolveAssetUrl(widget.images[i].url),
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const Icon(
                        CampfireIcons.error,
                        color: Colors.white54,
                        size: 40,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(CampfireIcons.close, color: Colors.white70),
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    Expanded(
                      child: Text(
                        widget.images.length > 1
                            ? '${_index + 1} of ${widget.images.length}'
                            : '',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'Geist',
                          fontSize: 13,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(CampfireIcons.download, color: Colors.white70),
                      tooltip: 'Download',
                      onPressed: () => unawaited(openAttachment(api.resolveAssetUrl(image.url))),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  '${image.filename} · ${formatBytes(image.sizeBytes)}',
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Geist',
                    fontSize: 12,
                    color: Colors.white60,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Hands the file to the OS, the same move `downloadAttachment` makes in the
/// Tauri client: the browser (or the system handler) honours the
/// `Content-Disposition` the server sets and saves it under its real name,
/// which is exactly what an in-app writer would have to reimplement.
Future<bool> openAttachment(String url) =>
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
