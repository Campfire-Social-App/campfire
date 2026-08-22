import 'package:campfire/models/attachment.dart';
import 'package:campfire/models/user.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'message.freezed.dart';
part 'message.g.dart';

@freezed
abstract class MessageReplyPreview with _$MessageReplyPreview {
  const factory MessageReplyPreview({
    required String id,
    required User author,
    required String content,
    required bool hasAttachments,
  }) = _MessageReplyPreview;

  factory MessageReplyPreview.fromJson(Map<String, dynamic> json) =>
      _$MessageReplyPreviewFromJson(json);
}

/// The three reactions this server accepts. Not free-form emoji: the column is
/// an enum (`server/app/models/message_reaction.py`), so a fourth one is a
/// migration on both sides rather than a client-side addition.
enum ReactionType {
  @JsonValue('like')
  like,
  @JsonValue('love')
  love,
  @JsonValue('laugh')
  laugh;
}

@freezed
abstract class MessageReaction with _$MessageReaction {
  const factory MessageReaction({
    required ReactionType type,
    required int count,
    required bool reactedByMe,
  }) = _MessageReaction;

  factory MessageReaction.fromJson(Map<String, dynamic> json) =>
      _$MessageReactionFromJson(json);
}

@freezed
abstract class Message with _$Message {
  const factory Message({
    required String id,
    required String channelId,
    required User author,
    required String content,
    required DateTime createdAt,
    required DateTime? editedAt,
    @Default(<Attachment>[]) List<Attachment> attachments,
    MessageReplyPreview? replyTo,

    /// Absent from servers older than the reactions migration, and from any
    /// message this client cached before it — an empty list, not a failure to
    /// parse (the React client defaults it the same way).
    @Default(<MessageReaction>[]) List<MessageReaction> reactions,

    /// Local only: an optimistic row standing in for a message the server has
    /// not acknowledged yet. The web client has no equivalent — it waits for the
    /// POST — but on a phone the network is slow often enough that the text has
    /// to appear the moment it is sent.
    @JsonKey(includeFromJson: false, includeToJson: false) @Default(false) bool pending,

    /// Local only: the POST came back an error, so the row offers to send it
    /// again or throw it away instead of quietly losing what was typed.
    @JsonKey(includeFromJson: false, includeToJson: false) @Default(false) bool sendFailed,
  }) = _Message;

  factory Message.fromJson(Map<String, dynamic> json) => _$MessageFromJson(json);
}

@freezed
abstract class MessagePage with _$MessagePage {
  const factory MessagePage({
    required List<Message> messages,
    required bool hasMore,
  }) = _MessagePage;

  factory MessagePage.fromJson(Map<String, dynamic> json) => _$MessagePageFromJson(json);
}
