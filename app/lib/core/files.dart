import 'package:campfire/models/attachment.dart';
import 'package:campfire/theme/icons.dart';
import 'package:flutter/widgets.dart' show IconData;

/// Port of `lib/files.ts`: what an attachment is, how big it reads, and how it
/// leaves the app.
///
/// SVG is deliberately not previewable — the server sends it as a download
/// rather than an image, since it can carry script.
const _previewableImages = {
  'image/png',
  'image/jpeg',
  'image/gif',
  'image/webp',
  'image/avif',
};

bool isImage(Attachment attachment) => _previewableImages.contains(attachment.contentType);

bool isVideo(Attachment attachment) => attachment.contentType.startsWith('video/');

bool isAudio(Attachment attachment) => attachment.contentType.startsWith('audio/');

/// True for the attachments that get a card instead of a preview or a player.
bool isPlainFile(Attachment attachment) =>
    !isImage(attachment) && !isVideo(attachment) && !isAudio(attachment);

final _archive = RegExp('zip|compressed|tar|rar|7z');

/// The glyph on a file card, by content type.
IconData fileIconFor(String contentType) {
  if (contentType.startsWith('audio/')) return CampfireIcons.fileAudio;
  if (contentType.startsWith('video/')) return CampfireIcons.fileVideo;
  if (contentType.startsWith('text/') || contentType == 'application/pdf') {
    return CampfireIcons.fileText;
  }
  if (_archive.hasMatch(contentType)) return CampfireIcons.fileArchive;
  return CampfireIcons.file;
}

/// `1.4 MB`, `320 KB`, `18 B` — one decimal below ten, none above, exactly as
/// `formatBytes` does in the web client.
String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';

  const units = ['KB', 'MB', 'GB'];
  var value = bytes / 1024;
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit += 1;
  }
  final rendered = value < 10 ? value.toStringAsFixed(1) : value.round().toString();
  return '$rendered ${units[unit]}';
}

/// How long a clip is, as a player shows it: `1:07`, `1:02:03`.
String formatDuration(Duration duration) {
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  final minutes = duration.inMinutes.remainder(60);
  if (duration.inHours == 0) return '$minutes:$seconds';
  return '${duration.inHours}:${minutes.toString().padLeft(2, '0')}:$seconds';
}
