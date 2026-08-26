import 'package:campfire/models/command.dart';
import 'package:campfire/state/api.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The slash commands this server's bots answer to, fetched once per session.
///
/// A failure is not an error state on purpose: an empty list just means no `/`
/// menu, which is exactly what a deployment without bots looks like. Same
/// contract as `state/commands.ts`.
class CommandsNotifier extends AsyncNotifier<List<SlashCommand>> {
  @override
  Future<List<SlashCommand>> build() async {
    try {
      return await ref.read(apiProvider).listCommands();
    } on Object {
      return const [];
    }
  }
}

final commandsProvider =
    AsyncNotifierProvider<CommandsNotifier, List<SlashCommand>>(CommandsNotifier.new);
