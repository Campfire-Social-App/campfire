import 'package:freezed_annotation/freezed_annotation.dart';

part 'channel.freezed.dart';
part 'channel.g.dart';

/// `dm` channels are never listed as server channels — they reach the client as
/// `DMConversation` entries instead (see `/api/dms`).
enum ChannelType {
  @JsonValue('text')
  text,
  @JsonValue('voice')
  voice,
  @JsonValue('dm')
  dm,
}

@freezed
abstract class Channel with _$Channel {
  const factory Channel({
    required String id,
    required String name,
    // A server that grows a channel kind this build has not heard of should not
    // take the whole READY frame down with it.
    @JsonKey(unknownEnumValue: ChannelType.text) required ChannelType type,
    required int position,

    /// Absent on the channels embedded in READY, present on `/api/channels`.
    /// See the note on `User.createdAt`.
    DateTime? createdAt,
  }) = _Channel;

  factory Channel.fromJson(Map<String, dynamic> json) => _$ChannelFromJson(json);
}
