// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dm.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_DMConversation _$DMConversationFromJson(Map<String, dynamic> json) =>
    _DMConversation(
      id: json['id'] as String,
      recipient: User.fromJson(json['recipient'] as Map<String, dynamic>),
      lastMessageAt: json['last_message_at'] == null
          ? null
          : DateTime.parse(json['last_message_at'] as String),
      unreadCount: (json['unread_count'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$DMConversationToJson(_DMConversation instance) =>
    <String, dynamic>{
      'id': instance.id,
      'recipient': instance.recipient.toJson(),
      'last_message_at': instance.lastMessageAt?.toIso8601String(),
      'unread_count': instance.unreadCount,
    };
