// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'server.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ServerSettings _$ServerSettingsFromJson(Map<String, dynamic> json) =>
    _ServerSettings(
      name: json['name'] as String,
      iconUrl: json['icon_url'] as String?,
      maxUploadBytes: (json['max_upload_bytes'] as num).toInt(),
    );

Map<String, dynamic> _$ServerSettingsToJson(_ServerSettings instance) =>
    <String, dynamic>{
      'name': instance.name,
      'icon_url': instance.iconUrl,
      'max_upload_bytes': instance.maxUploadBytes,
    };

_VoiceTokenResponse _$VoiceTokenResponseFromJson(Map<String, dynamic> json) =>
    _VoiceTokenResponse(
      token: json['token'] as String,
      url: json['url'] as String,
      room: json['room'] as String,
    );

Map<String, dynamic> _$VoiceTokenResponseToJson(_VoiceTokenResponse instance) =>
    <String, dynamic>{
      'token': instance.token,
      'url': instance.url,
      'room': instance.room,
    };

_VoiceParticipantState _$VoiceParticipantStateFromJson(
  Map<String, dynamic> json,
) => _VoiceParticipantState(
  userId: json['user_id'] as String,
  username: json['username'] as String,
  channelId: json['channel_id'] as String,
  muted: json['muted'] as bool? ?? false,
  deafened: json['deafened'] as bool? ?? false,
  speaking: json['speaking'] as bool? ?? false,
);

Map<String, dynamic> _$VoiceParticipantStateToJson(
  _VoiceParticipantState instance,
) => <String, dynamic>{
  'user_id': instance.userId,
  'username': instance.username,
  'channel_id': instance.channelId,
  'muted': instance.muted,
  'deafened': instance.deafened,
  'speaking': instance.speaking,
};
