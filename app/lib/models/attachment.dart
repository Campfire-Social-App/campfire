import 'package:freezed_annotation/freezed_annotation.dart';

part 'attachment.freezed.dart';
part 'attachment.g.dart';

@freezed
abstract class Attachment with _$Attachment {
  const factory Attachment({
    required String id,
    required String filename,
    required String contentType,
    required int sizeBytes,
    /// Server-relative (`/uploads/...`) until `resolveAssetUrl` joins it to the
    /// configured server, so the same attachment works across deployments.
    required String url,
    required DateTime createdAt,
  }) = _Attachment;

  factory Attachment.fromJson(Map<String, dynamic> json) => _$AttachmentFromJson(json);
}
