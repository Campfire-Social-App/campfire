import 'package:campfire/core/commands.dart';
import 'package:campfire/models/command.dart';
import 'package:flutter_test/flutter_test.dart';

/// The cases `lib/commands.ts` is written around. A `/play` has to mean the
/// same thing typed on the phone as typed on the desktop, so these are the
/// contract for that.
void main() {
  const play = SlashCommand(
    name: 'play',
    description: 'Toca uma faixa',
    usage: '<url ou busca>',
    requiresVoice: true,
  );
  const pause = SlashCommand(name: 'pause', description: 'Pausa', requiresVoice: true);
  const queue = SlashCommand(name: 'queue', description: 'Mostra a fila');
  const commands = [play, pause, queue];

  group('activeCommandQuery', () {
    test('opens on a slash at the start of the line', () {
      expect(activeCommandQuery('/pl', 3), const CommandQuery('pl'));
      expect(activeCommandQuery('/', 1), const CommandQuery(''));
    });

    test('closes once an argument is being typed', () {
      // The command is settled by then; the menu would only be in the way.
      expect(activeCommandQuery('/play ', 6), isNull);
      expect(activeCommandQuery('/play never gonna', 17), isNull);
    });

    test('ignores a slash that is not the first character', () {
      // A pasted URL is the case that matters — its slashes are never first.
      expect(activeCommandQuery('https://example.com/x', 21), isNull);
      expect(activeCommandQuery('e/ou', 4), isNull);
      expect(activeCommandQuery(' /play', 6), isNull);
    });

    test('follows the cursor rather than the whole text', () {
      expect(activeCommandQuery('/play', 3), const CommandQuery('pl'));
    });
  });

  group('commandCandidates', () {
    test('filters by prefix', () {
      expect(commandCandidates('p', commands), [play, pause]);
      expect(commandCandidates('pl', commands), [play]);
      expect(commandCandidates('', commands), commands);
    });

    test('is case-insensitive', () {
      expect(commandCandidates('PL', commands), [play]);
    });

    test('offers nothing for a name no bot claims', () {
      expect(commandCandidates('dance', commands), isEmpty);
    });
  });

  group('parseCommand', () {
    test('splits the name from its arguments', () {
      final parsed = parseCommand('/play never gonna give you up', commands);
      expect(parsed?.command, play);
      expect(parsed?.args, 'never gonna give you up');
    });

    test('a command with no arguments parses to an empty string', () {
      expect(parseCommand('/pause', commands)?.args, '');
      expect(parseCommand('/pause   ', commands)?.args, '');
    });

    test('leaves an unknown command as an ordinary message', () {
      // Otherwise typing "/me shrugs" would silently vanish into a 404 instead
      // of being posted.
      expect(parseCommand('/me shrugs', commands), isNull);
    });

    test('text that merely opens with a slash is still a message', () {
      expect(parseCommand('and/or', commands), isNull);
      expect(parseCommand('/ play', commands), isNull);
    });

    test('is case-insensitive on the name', () {
      expect(parseCommand('/PLAY algo', commands)?.command, play);
    });
  });
}
