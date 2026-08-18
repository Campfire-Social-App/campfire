// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'channel.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Channel _$ChannelFromJson(Map<String, dynamic> json) => _Channel(
  id: json['id'] as String,
  name: json['name'] as String,
  type: $enumDecode(
    _$ChannelTypeEnumMap,
    json['type'],
    unknownValue: ChannelType.text,
  ),
  position: (json['position'] as num).toInt(),
  createdAt: json['created_at'] == null
      ? null
      : DateTime.parse(json['created_at'] as String),
);

Map<String, dynamic> _$ChannelToJson(_Channel instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'type': _$ChannelTypeEnumMap[instance.type]!,
  'position': instance.position,
  'created_at': instance.createdAt?.toIso8601String(),
};

const _$ChannelTypeEnumMap = {
  ChannelType.text: 'text',
  ChannelType.voice: 'voice',
  ChannelType.dm: 'dm',
};
