import 'package:freezed_annotation/freezed_annotation.dart';

part 'command.freezed.dart';
part 'command.g.dart';

/// One slash command the server's bots answer to, as offered in the composer's
/// `/` menu. Port of the `SlashCommand` in `lib/types.ts`.
///
/// The list comes from `GET /api/commands` and is empty on a deployment with no
/// bots service — then the menu simply never opens.
@freezed
abstract class SlashCommand with _$SlashCommand {
  const factory SlashCommand({
    required String name,
    required String description,

    /// Argument hint shown next to the name, e.g. `<url ou busca>`.
    @Default('') String usage,

    /// The bot enforces this; the client only uses it to explain the
    /// requirement before spending a round trip.
    @Default(false) bool requiresVoice,
  }) = _SlashCommand;

  factory SlashCommand.fromJson(Map<String, dynamic> json) => _$SlashCommandFromJson(json);
}
