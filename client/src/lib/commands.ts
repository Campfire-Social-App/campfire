import type { SlashCommand } from "@/lib/types";

/** A slash command being typed: only ever at the very start of the composer,
 * and only until the first space — after that whatever follows is the argument.
 *
 * Anchoring at position 0 is what keeps a pasted URL ("https://x/y") or a date
 * out of the menu: those slashes are never the first character.
 */
export interface CommandQuery {
  /** Text typed after the "/", used to filter the menu. */
  query: string;
}

export function activeCommandQuery(value: string, cursor: number): CommandQuery | null {
  if (!value.startsWith("/")) return null;
  const upToCursor = value.slice(0, cursor);
  // Past the first space the command is settled and the menu gets out of the
  // way — the person is typing arguments now.
  if (/\s/.test(upToCursor)) return null;
  return { query: upToCursor.slice(1) };
}

export function commandCandidates(query: string, commands: SlashCommand[]): SlashCommand[] {
  const lowerQuery = query.toLowerCase();
  return commands.filter((command) => command.name.toLowerCase().startsWith(lowerQuery)).slice(0, 8);
}

/** Splits a composed line into the command and everything after it.
 *
 * Returns null when the text isn't a command at all, or names one this server
 * doesn't have — a message that merely opens with a slash is still a message,
 * and sending it must not silently vanish into a 404.
 */
export function parseCommand(
  value: string,
  commands: SlashCommand[],
): { command: SlashCommand; args: string } | null {
  if (!value.startsWith("/")) return null;
  const firstSpace = value.search(/\s/);
  const name = (firstSpace === -1 ? value.slice(1) : value.slice(1, firstSpace)).toLowerCase();
  const command = commands.find((item) => item.name.toLowerCase() === name);
  if (!command) return null;
  return { command, args: firstSpace === -1 ? "" : value.slice(firstSpace + 1).trim() };
}
