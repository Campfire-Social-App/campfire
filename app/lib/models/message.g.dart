// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'message.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_MessageReplyPreview _$MessageReplyPreviewFromJson(Map<String, dynamic> json) =>
    _MessageReplyPreview(
      id: json['id'] as String,
      author: User.fromJson(json['author'] as Map<String, dynamic>),
      content: json['content'] as String,
      hasAttachments: json['has_attachments'] as bool,
    );

Map<String, dynamic> _$MessageReplyPreviewToJson(
  _MessageReplyPreview instance,
) => <String, dynamic>{
  'id': instance.id,
  'author': instance.author.toJson(),
  'content': instance.content,
  'has_attachments': instance.hasAttachments,
};

_MessageReaction _$MessageReactionFromJson(Map<String, dynamic> json) =>
    _MessageReaction(
      type: $enumDecode(_$ReactionTypeEnumMap, json['type']),
      count: (json['count'] as num).toInt(),
      reactedByMe: json['reacted_by_me'] as bool,
    );

Map<String, dynamic> _$MessageReactionToJson(_MessageReaction instance) =>
    <String, dynamic>{
      'type': _$ReactionTypeEnumMap[instance.type]!,
      'count': instance.count,
      'reacted_by_me': instance.reactedByMe,
    };

const _$ReactionTypeEnumMap = {
  ReactionType.like: 'like',
  ReactionType.love: 'love',
  ReactionType.laugh: 'laugh',
};

_Message _$MessageFromJson(Map<String, dynamic> json) => _Message(
  id: json['id'] as String,
  channelId: json['channel_id'] as String,
  author: User.fromJson(json['author'] as Map<String, dynamic>),
  content: json['content'] as String,
  createdAt: DateTime.parse(json['created_at'] as String),
  editedAt: json['edited_at'] == null
      ? null
      : DateTime.parse(json['edited_at'] as String),
  attachments:
      (json['attachments'] as List<dynamic>?)
          ?.map((e) => Attachment.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <Attachment>[],
  replyTo: json['reply_to'] == null
      ? null
      : MessageReplyPreview.fromJson(json['reply_to'] as Map<String, dynamic>),
  reactions:
      (json['reactions'] as List<dynamic>?)
          ?.map((e) => MessageReaction.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <MessageReaction>[],
);

Map<String, dynamic> _$MessageToJson(_Message instance) => <String, dynamic>{
  'id': instance.id,
  'channel_id': instance.channelId,
  'author': instance.author.toJson(),
  'content': instance.content,
  'created_at': instance.createdAt.toIso8601String(),
  'edited_at': instance.editedAt?.toIso8601String(),
  'attachments': instance.attachments.map((e) => e.toJson()).toList(),
  'reply_to': instance.replyTo?.toJson(),
  'reactions': instance.reactions.map((e) => e.toJson()).toList(),
};

_MessagePage _$MessagePageFromJson(Map<String, dynamic> json) => _MessagePage(
  messages: (json['messages'] as List<dynamic>)
      .map((e) => Message.fromJson(e as Map<String, dynamic>))
      .toList(),
  hasMore: json['has_more'] as bool,
);

Map<String, dynamic> _$MessagePageToJson(_MessagePage instance) =>
    <String, dynamic>{
      'messages': instance.messages.map((e) => e.toJson()).toList(),
      'has_more': instance.hasMore,
    };
