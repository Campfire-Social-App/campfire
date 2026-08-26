import 'package:campfire/models/command.dart';
import 'package:meta/meta.dart';

/// Port of `lib/commands.ts`, case for case — a `/play` has to mean the same
/// thing typed on the phone as typed on the desktop.

/// A slash command being typed: only ever at the very start of the composer,
/// and only until the first space — after that whatever follows is the
/// argument.
///
/// Anchoring at position 0 is what keeps a pasted URL (`https://x/y`) or a date
/// out of the menu: those slashes are never the first character.
@immutable
class CommandQuery {
  const CommandQuery(this.query);

  /// Text typed after the `/`, used to filter the menu.
  final String query;

  @override
  bool operator ==(Object other) => other is CommandQuery && other.query == query;

  @override
  int get hashCode => query.hashCode;

  @override
  String toString() => 'CommandQuery($query)';
}

final _whitespace = RegExp(r'\s');

CommandQuery? activeCommandQuery(String value, int cursor) {
  if (!value.startsWith('/')) return null;
  final upToCursor = value.substring(0, cursor.clamp(0, value.length));
  // Past the first space the command is settled and the menu gets out of the
  // way — the person is typing arguments now.
  if (upToCursor.contains(_whitespace)) return null;
  return CommandQuery(upToCursor.substring(1));
}

List<SlashCommand> commandCandidates(String query, List<SlashCommand> commands) {
  final lowerQuery = query.toLowerCase();
  return commands
      .where((command) => command.name.toLowerCase().startsWith(lowerQuery))
      .take(8)
      .toList();
}

/// A command and everything typed after it.
@immutable
class ParsedCommand {
  const ParsedCommand(this.command, this.args);

  final SlashCommand command;
  final String args;
}

/// Splits a composed line into the command and its arguments.
///
/// Null when the text is not a command at all, or names one this server does
/// not have — a message that merely opens with a slash is still a message, and
/// sending it must not silently vanish into a 404.
ParsedCommand? parseCommand(String value, List<SlashCommand> commands) {
  if (!value.startsWith('/')) return null;
  final match = _whitespace.firstMatch(value);
  final name = (match == null ? value.substring(1) : value.substring(1, match.start)).toLowerCase();
  for (final command in commands) {
    if (command.name.toLowerCase() == name) {
      return ParsedCommand(
        command,
        match == null ? '' : value.substring(match.start + 1).trim(),
      );
    }
  }
  return null;
}
