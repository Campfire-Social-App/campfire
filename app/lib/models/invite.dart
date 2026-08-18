import 'package:freezed_annotation/freezed_annotation.dart';

part 'invite.freezed.dart';
part 'invite.g.dart';

@freezed
abstract class Invite with _$Invite {
  const factory Invite({
    required String id,
    required String code,
    required String createdById,
    required int? maxUses,
    required int usesCount,
    required DateTime? expiresAt,
    required DateTime createdAt,
  }) = _Invite;

  factory Invite.fromJson(Map<String, dynamic> json) => _$InviteFromJson(json);
}
