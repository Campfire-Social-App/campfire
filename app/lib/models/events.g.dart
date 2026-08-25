// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'events.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ReadyData _$ReadyDataFromJson(Map<String, dynamic> json) => _ReadyData(
  user: User.fromJson(json['user'] as Map<String, dynamic>),
  server: ServerSettings.fromJson(json['server'] as Map<String, dynamic>),
  channels: (json['channels'] as List<dynamic>)
      .map((e) => Channel.fromJson(e as Map<String, dynamic>))
      .toList(),
  dms: (json['dms'] as List<dynamic>)
      .map((e) => DMConversation.fromJson(e as Map<String, dynamic>))
      .toList(),
  onlineUserIds:
      (json['online_user_ids'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const <String>[],
  voiceStates:
      (json['voice_states'] as List<dynamic>?)
          ?.map(
            (e) => VoiceParticipantState.fromJson(e as Map<String, dynamic>),
          )
          .toList() ??
      const <VoiceParticipantState>[],
);

Map<String, dynamic> _$ReadyDataToJson(_ReadyData instance) =>
    <String, dynamic>{
      'user': instance.user.toJson(),
      'server': instance.server.toJson(),
      'channels': instance.channels.map((e) => e.toJson()).toList(),
      'dms': instance.dms.map((e) => e.toJson()).toList(),
      'online_user_ids': instance.onlineUserIds,
      'voice_states': instance.voiceStates.map((e) => e.toJson()).toList(),
    };

_MessageReactionUpdateData _$MessageReactionUpdateDataFromJson(
  Map<String, dynamic> json,
) => _MessageReactionUpdateData(
  messageId: json['message_id'] as String,
  channelId: json['channel_id'] as String,
  type: $enumDecode(_$ReactionTypeEnumMap, json['type']),
  count: (json['count'] as num).toInt(),
  userId: json['user_id'] as String,
  reacted: json['reacted'] as bool,
);

Map<String, dynamic> _$MessageReactionUpdateDataToJson(
  _MessageReactionUpdateData instance,
) => <String, dynamic>{
  'message_id': instance.messageId,
  'channel_id': instance.channelId,
  'type': _$ReactionTypeEnumMap[instance.type]!,
  'count': instance.count,
  'user_id': instance.userId,
  'reacted': instance.reacted,
};

const _$ReactionTypeEnumMap = {
  ReactionType.like: 'like',
  ReactionType.love: 'love',
  ReactionType.laugh: 'laugh',
};

_PresenceUpdateData _$PresenceUpdateDataFromJson(Map<String, dynamic> json) =>
    _PresenceUpdateData(
      userId: json['user_id'] as String,
      status: $enumDecode(_$PresenceStatusEnumMap, json['status']),
    );

Map<String, dynamic> _$PresenceUpdateDataToJson(_PresenceUpdateData instance) =>
    <String, dynamic>{
      'user_id': instance.userId,
      'status': _$PresenceStatusEnumMap[instance.status]!,
    };

const _$PresenceStatusEnumMap = {
  PresenceStatus.online: 'online',
  PresenceStatus.offline: 'offline',
};

_TypingStartData _$TypingStartDataFromJson(Map<String, dynamic> json) =>
    _TypingStartData(
      userId: json['user_id'] as String,
      channelId: json['channel_id'] as String,
    );

Map<String, dynamic> _$TypingStartDataToJson(_TypingStartData instance) =>
    <String, dynamic>{
      'user_id': instance.userId,
      'channel_id': instance.channelId,
    };

_VoiceStateUpdateData _$VoiceStateUpdateDataFromJson(
  Map<String, dynamic> json,
) => _VoiceStateUpdateData(
  action: $enumDecode(_$VoiceStateActionEnumMap, json['action']),
  userId: json['user_id'] as String?,
  username: json['username'] as String?,
  channelId: json['channel_id'] as String?,
  muted: json['muted'] as bool?,
  deafened: json['deafened'] as bool?,
  screenSharing: json['screen_sharing'] as bool?,
);

Map<String, dynamic> _$VoiceStateUpdateDataToJson(
  _VoiceStateUpdateData instance,
) => <String, dynamic>{
  'action': _$VoiceStateActionEnumMap[instance.action]!,
  'user_id': instance.userId,
  'username': instance.username,
  'channel_id': instance.channelId,
  'muted': instance.muted,
  'deafened': instance.deafened,
  'screen_sharing': instance.screenSharing,
};

const _$VoiceStateActionEnumMap = {
  VoiceStateAction.joined: 'joined',
  VoiceStateAction.left: 'left',
  VoiceStateAction.updated: 'updated',
  VoiceStateAction.roomFinished: 'room_finished',
};

_DMCallActor _$DMCallActorFromJson(Map<String, dynamic> json) => _DMCallActor(
  id: json['id'] as String,
  username: json['username'] as String,
);

Map<String, dynamic> _$DMCallActorToJson(_DMCallActor instance) =>
    <String, dynamic>{'id': instance.id, 'username': instance.username};

_DMCallData _$DMCallDataFromJson(Map<String, dynamic> json) => _DMCallData(
  action: $enumDecode(_$DMCallActionEnumMap, json['action']),
  channelId: json['channel_id'] as String,
  from: DMCallActor.fromJson(json['from'] as Map<String, dynamic>),
);

Map<String, dynamic> _$DMCallDataToJson(_DMCallData instance) =>
    <String, dynamic>{
      'action': _$DMCallActionEnumMap[instance.action]!,
      'channel_id': instance.channelId,
      'from': instance.from.toJson(),
    };

const _$DMCallActionEnumMap = {
  DMCallAction.ringing: 'ringing',
  DMCallAction.accepted: 'accepted',
  DMCallAction.declined: 'declined',
  DMCallAction.cancelled: 'cancelled',
  DMCallAction.unavailable: 'unavailable',
};

_MessageDeleteData _$MessageDeleteDataFromJson(Map<String, dynamic> json) =>
    _MessageDeleteData(
      id: json['id'] as String,
      channelId: json['channel_id'] as String,
    );

Map<String, dynamic> _$MessageDeleteDataToJson(_MessageDeleteData instance) =>
    <String, dynamic>{'id': instance.id, 'channel_id': instance.channelId};

_ChannelDeleteData _$ChannelDeleteDataFromJson(Map<String, dynamic> json) =>
    _ChannelDeleteData(id: json['id'] as String);

Map<String, dynamic> _$ChannelDeleteDataToJson(_ChannelDeleteData instance) =>
    <String, dynamic>{'id': instance.id};
