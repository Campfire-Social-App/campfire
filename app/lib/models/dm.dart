import 'package:campfire/models/user.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'dm.freezed.dart';
part 'dm.g.dart';

/// A 1:1 conversation as seen by the signed-in user: [id] is the underlying
/// channel id (so the message endpoints take it as-is), [recipient] is the other
/// member, and [unreadCount] is relative to us.
@freezed
abstract class DMConversation with _$DMConversation {
  const factory DMConversation({
    required String id,
    required User recipient,
    required DateTime? lastMessageAt,
    @Default(0) int unreadCount,
  }) = _DMConversation;

  factory DMConversation.fromJson(Map<String, dynamic> json) => _$DMConversationFromJson(json);
}
