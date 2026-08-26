// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'command.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_SlashCommand _$SlashCommandFromJson(Map<String, dynamic> json) =>
    _SlashCommand(
      name: json['name'] as String,
      description: json['description'] as String,
      usage: json['usage'] as String? ?? '',
      requiresVoice: json['requires_voice'] as bool? ?? false,
    );

Map<String, dynamic> _$SlashCommandToJson(_SlashCommand instance) =>
    <String, dynamic>{
      'name': instance.name,
      'description': instance.description,
      'usage': instance.usage,
      'requires_voice': instance.requiresVoice,
    };
