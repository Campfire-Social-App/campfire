import 'package:campfire/core/files.dart';
import 'package:campfire/models/attachment.dart';
import 'package:campfire/theme/icons.dart';
import 'package:flutter_test/flutter_test.dart';

Attachment attachment(String contentType) => Attachment(
      id: 'a1',
      filename: 'file',
      contentType: contentType,
      sizeBytes: 1,
      url: '/api/uploads/a1',
      createdAt: DateTime(2026, 8, 20),
    );

void main() {
  group('kind', () {
    test('previews the image types the server serves inline', () {
      for (final type in ['image/png', 'image/jpeg', 'image/gif', 'image/webp', 'image/avif']) {
        expect(isImage(attachment(type)), isTrue, reason: type);
      }
    });

    test('does not preview SVG', () {
      // The server sends it as a download precisely because it can carry
      // script; showing it inline would undo that.
      expect(isImage(attachment('image/svg+xml')), isFalse);
      expect(isPlainFile(attachment('image/svg+xml')), isTrue);
    });

    test('recognises video and audio by prefix', () {
      expect(isVideo(attachment('video/mp4')), isTrue);
      expect(isAudio(attachment('audio/ogg')), isTrue);
    });

    test('everything else is a plain file', () {
      expect(isPlainFile(attachment('application/pdf')), isTrue);
      expect(isPlainFile(attachment('video/mp4')), isFalse);
    });
  });

  group('fileIconFor', () {
    test('picks a glyph per family', () {
      expect(fileIconFor('audio/mpeg'), CampfireIcons.fileAudio);
      expect(fileIconFor('video/webm'), CampfireIcons.fileVideo);
      expect(fileIconFor('text/plain'), CampfireIcons.fileText);
      expect(fileIconFor('application/pdf'), CampfireIcons.fileText);
      expect(fileIconFor('application/zip'), CampfireIcons.fileArchive);
      expect(fileIconFor('application/x-7z-compressed'), CampfireIcons.fileArchive);
      expect(fileIconFor('application/octet-stream'), CampfireIcons.file);
    });
  });

  group('formatBytes', () {
    test('reads bytes as bytes below a kilobyte', () {
      expect(formatBytes(0), '0 B');
      expect(formatBytes(1023), '1023 B');
    });

    test('keeps one decimal below ten and none above', () {
      expect(formatBytes(1536), '1.5 KB');
      expect(formatBytes(1024 * 20), '20 KB');
      expect(formatBytes(1024 * 1024 * 4), '4.0 MB');
    });

    test('climbs to gigabytes and stops there', () {
      expect(formatBytes(1024 * 1024 * 1024 * 2), '2.0 GB');
      expect(formatBytes(1024 * 1024 * 1024 * 2048), '2048 GB');
    });
  });

  group('formatDuration', () {
    test('drops the hour when there is none', () {
      expect(formatDuration(const Duration(seconds: 7)), '0:07');
      expect(formatDuration(const Duration(minutes: 1, seconds: 7)), '1:07');
      expect(formatDuration(const Duration(minutes: 12, seconds: 30)), '12:30');
    });

    test('pads minutes once the hour is there', () {
      expect(formatDuration(const Duration(hours: 1, minutes: 2, seconds: 3)), '1:02:03');
    });
  });
}
