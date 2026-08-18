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
