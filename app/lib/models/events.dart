import 'package:campfire/models/channel.dart';
import 'package:campfire/models/dm.dart';
import 'package:campfire/models/message.dart';
import 'package:campfire/models/server.dart';
import 'package:campfire/models/user.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'events.freezed.dart';
part 'events.g.dart';

/// Every frame the server can push down `/gateway`, as a sealed union so a
/// `switch` over them is checked at compile time — add a thirteenth op on the
/// server and the dispatcher stops compiling until it is handled.
///
/// The wire format is `{"op": ..., "data": {...}}`: a discriminator with the
/// payload nested one level down, which is why [fromFrame] does the dispatch by
/// hand rather than leaning on freezed's union serialisation.
@freezed
sealed class GatewayEvent with _$GatewayEvent {
  const GatewayEvent._();

  /// One frame carrying user, server, channels, DMs, presence and voice state.
  /// The client must not re-fetch any of it over REST at boot — see
  /// PLANO_FLUTTER.md §6.
  const factory GatewayEvent.ready(ReadyData data) = ReadyEvent;
  const factory GatewayEvent.messageCreate(Message message) = MessageCreateEvent;
  const factory GatewayEvent.messageUpdate(Message message) = MessageUpdateEvent;
  const factory GatewayEvent.messageDelete(MessageDeleteData data) = MessageDeleteEvent;
  const factory GatewayEvent.typingStart(TypingStartData data) = TypingStartEvent;
  const factory GatewayEvent.presenceUpdate(PresenceUpdateData data) = PresenceUpdateEvent;
  const factory GatewayEvent.voiceStateUpdate(VoiceStateUpdateData data) = VoiceStateUpdateEvent;
  const factory GatewayEvent.channelCreate(Channel channel) = ChannelCreateEvent;
  const factory GatewayEvent.channelUpdate(Channel channel) = ChannelUpdateEvent;
  const factory GatewayEvent.channelDelete(ChannelDeleteData data) = ChannelDeleteEvent;
  const factory GatewayEvent.dmUpdate(DMConversation conversation) = DMUpdateEvent;
  const factory GatewayEvent.dmCall(DMCallData data) = DMCallEvent;

  /// An op this build does not know. A newer server must not be able to kill an
  /// older client's socket, so unknown frames are surfaced and dropped rather
  /// than thrown.
  ///
  /// A *known* op with a payload that will not parse is the opposite case — it
  /// means the contract broke — and [fromFrame] lets that throw for the gateway
  /// loop to log and skip.
  const factory GatewayEvent.unknown(String op) = UnknownEvent;

  // Not a factory constructor: freezed reads every `factory` on this class as
  // another union case.
  // ignore: prefer_constructors_over_static_methods
  static GatewayEvent fromFrame(Map<String, dynamic> frame) {
    final op = frame['op'] as String? ?? '';
    // `Map.from` rather than a cast: a frame that arrived as part of a larger
    // decoded structure can carry a `Map<dynamic, dynamic>`, which a cast to
    // `Map<String, dynamic>` rejects even though every key is a string.
    final raw = frame['data'];
    final data = raw is Map ? Map<String, dynamic>.from(raw) : const <String, dynamic>{};

    return switch (op) {
      'READY' => GatewayEvent.ready(ReadyData.fromJson(data)),
      'MESSAGE_CREATE' => GatewayEvent.messageCreate(Message.fromJson(data)),
      'MESSAGE_UPDATE' => GatewayEvent.messageUpdate(Message.fromJson(data)),
      'MESSAGE_DELETE' => GatewayEvent.messageDelete(MessageDeleteData.fromJson(data)),
      'TYPING_START' => GatewayEvent.typingStart(TypingStartData.fromJson(data)),
      'PRESENCE_UPDATE' => GatewayEvent.presenceUpdate(PresenceUpdateData.fromJson(data)),
      'VOICE_STATE_UPDATE' => GatewayEvent.voiceStateUpdate(VoiceStateUpdateData.fromJson(data)),
      'CHANNEL_CREATE' => GatewayEvent.channelCreate(Channel.fromJson(data)),
      'CHANNEL_UPDATE' => GatewayEvent.channelUpdate(Channel.fromJson(data)),
      'CHANNEL_DELETE' => GatewayEvent.channelDelete(ChannelDeleteData.fromJson(data)),
      'DM_UPDATE' => GatewayEvent.dmUpdate(DMConversation.fromJson(data)),
      'DM_CALL' => GatewayEvent.dmCall(DMCallData.fromJson(data)),
      _ => GatewayEvent.unknown(op),
    };
  }
}

@freezed
abstract class ReadyData with _$ReadyData {
  const factory ReadyData({
    required User user,
    required ServerSettings server,
    required List<Channel> channels,
    required List<DMConversation> dms,
    @Default(<String>[]) List<String> onlineUserIds,
    @Default(<VoiceParticipantState>[]) List<VoiceParticipantState> voiceStates,
  }) = _ReadyData;

  factory ReadyData.fromJson(Map<String, dynamic> json) => _$ReadyDataFromJson(json);
}

@freezed
abstract class PresenceUpdateData with _$PresenceUpdateData {
  const factory PresenceUpdateData({
    required String userId,
    required PresenceStatus status,
  }) = _PresenceUpdateData;

  factory PresenceUpdateData.fromJson(Map<String, dynamic> json) =>
      _$PresenceUpdateDataFromJson(json);
}

@freezed
abstract class TypingStartData with _$TypingStartData {
  const factory TypingStartData({
    required String userId,
    required String channelId,
  }) = _TypingStartData;

  factory TypingStartData.fromJson(Map<String, dynamic> json) => _$TypingStartDataFromJson(json);
}

enum VoiceStateAction {
  @JsonValue('joined')
  joined,
  @JsonValue('left')
  left,
  @JsonValue('room_finished')
  roomFinished,
}

@freezed
abstract class VoiceStateUpdateData with _$VoiceStateUpdateData {
  const factory VoiceStateUpdateData({
    required VoiceStateAction action,

    /// Absent on `room_finished`, which is about the room rather than a person.
    String? userId,
    String? username,

    /// Null when someone left voice altogether rather than a specific channel.
    String? channelId,
  }) = _VoiceStateUpdateData;

  factory VoiceStateUpdateData.fromJson(Map<String, dynamic> json) =>
      _$VoiceStateUpdateDataFromJson(json);
}

enum DMCallAction {
  @JsonValue('ringing')
  ringing,
  @JsonValue('accepted')
  accepted,
  @JsonValue('declined')
  declined,
  @JsonValue('cancelled')
  cancelled,
  @JsonValue('unavailable')
  unavailable,
}

/// Who caused a step in a DM call's ring: the caller when ringing or
/// cancelling, the callee when accepting or declining.
@freezed
abstract class DMCallActor with _$DMCallActor {
  const factory DMCallActor({
    required String id,
    required String username,
  }) = _DMCallActor;

  factory DMCallActor.fromJson(Map<String, dynamic> json) => _$DMCallActorFromJson(json);
}

/// A step in a DM call's ring. Once a call is answered it leaves this channel
/// entirely and lives as LiveKit room state.
@freezed
abstract class DMCallData with _$DMCallData {
  const factory DMCallData({
    required DMCallAction action,
    required String channelId,
    required DMCallActor from,
  }) = _DMCallData;

  factory DMCallData.fromJson(Map<String, dynamic> json) => _$DMCallDataFromJson(json);
}

@freezed
abstract class MessageDeleteData with _$MessageDeleteData {
  const factory MessageDeleteData({
    required String id,
    required String channelId,
  }) = _MessageDeleteData;

  factory MessageDeleteData.fromJson(Map<String, dynamic> json) => _$MessageDeleteDataFromJson(json);
}

@freezed
abstract class ChannelDeleteData with _$ChannelDeleteData {
  const factory ChannelDeleteData({required String id}) = _ChannelDeleteData;

  factory ChannelDeleteData.fromJson(Map<String, dynamic> json) => _$ChannelDeleteDataFromJson(json);
}
