import 'package:freezed_annotation/freezed_annotation.dart';

part 'server.freezed.dart';
part 'server.g.dart';

@freezed
abstract class ServerSettings with _$ServerSettings {
  const factory ServerSettings({
    required String name,
    required String? iconUrl,

    /// Upload ceiling of this deployment — the client turns away bigger files
    /// itself rather than spending an upload to be told no.
    required int maxUploadBytes,
  }) = _ServerSettings;

  factory ServerSettings.fromJson(Map<String, dynamic> json) => _$ServerSettingsFromJson(json);
}

@freezed
abstract class VoiceTokenResponse with _$VoiceTokenResponse {
  const factory VoiceTokenResponse({
    required String token,
    required String url,
    required String room,
  }) = _VoiceTokenResponse;

  factory VoiceTokenResponse.fromJson(Map<String, dynamic> json) =>
      _$VoiceTokenResponseFromJson(json);
}

@freezed
abstract class VoiceParticipantState with _$VoiceParticipantState {
  const factory VoiceParticipantState({
    required String userId,
    required String username,
    required String channelId,
    @Default(false) bool muted,

    /// Never sent by the server: it is a LiveKit participant attribute the
    /// clients set on themselves, so it only becomes known once we are in the
    /// same room. Someone in a channel we are not connected to always reads as
    /// not deafened, exactly as in the web client.
    @Default(false) bool deafened,
    @Default(false) bool speaking,
  }) = _VoiceParticipantState;

  factory VoiceParticipantState.fromJson(Map<String, dynamic> json) =>
      _$VoiceParticipantStateFromJson(json);
}
