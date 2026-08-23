import type { Channel, User } from "@/lib/types";

export const EVERYONE_MENTION = "everyone";

// Matches the same charset/length auth enforces for usernames (see
// server/app/schemas/auth.py), plus the "everyone" pseudo-mention.
// Channel names have no such charset restriction (free text, see
// server/app/models/channel.py), so "#" just grabs the next run of
// non-whitespace and we check it against known channel names below —
// this only linkifies cleanly for the common space-free "kebab-case"
// channel naming convention.
// Both require a word boundary before the trigger, so "foo@bar" or a
// literal "#" in prose doesn't get misread as a mention.
const MENTION_PATTERN =
  "(?<![\\w@])@(everyone|[a-zA-Z0-9_]{3,32})\\b" + "|" + "(?<![\\w#])#(\\S+)";

function mentionsRegex(): RegExp {
  return new RegExp(MENTION_PATTERN, "g");
}

export interface MentionSegment {
  text: string;
  mention: "everyone" | "user" | "channel" | null;
  channelId?: string;
}

/** Splits message content into plain-text and mention segments for rendering. */
export function splitMentions(
  content: string,
  knownUsernames: Set<string>,
  channelsByName: Map<string, Channel>,
): MentionSegment[] {
  const segments: MentionSegment[] = [];
  const regex = mentionsRegex();
  let lastIndex = 0;
  let match: RegExpExecArray | null;

  while ((match = regex.exec(content)) !== null) {
    const [full, userOrEveryone, channelToken] = match;
    let segment: MentionSegment | null = null;
    let matchedLength = full.length;

    if (userOrEveryone !== undefined) {
      const isKnown = userOrEveryone === EVERYONE_MENTION || knownUsernames.has(userOrEveryone.toLowerCase());
      if (isKnown) {
        segment = { text: full, mention: userOrEveryone === EVERYONE_MENTION ? "everyone" : "user" };
      }
    } else if (channelToken !== undefined) {
      // Channel names are free text, so trailing punctuation like "#chat," or
      // "#chat." shouldn't be swallowed into the match — trim it off first.
      const trimmedToken = channelToken.replace(/[.,!?;:)]+$/, "");
      const channel = channelsByName.get(trimmedToken.toLowerCase());
      if (channel) {
        matchedLength = 1 + trimmedToken.length;
        segment = { text: `#${trimmedToken}`, mention: "channel", channelId: channel.id };
      }
    }

    if (!segment) continue;

    if (match.index > lastIndex) {
      segments.push({ text: content.slice(lastIndex, match.index), mention: null });
    }
    segments.push(segment);
    lastIndex = match.index + matchedLength;
  }

  if (lastIndex < content.length) {
    segments.push({ text: content.slice(lastIndex), mention: null });
  }
  return segments;
}

/** Whether `content` mentions `username` directly or via @everyone. */
export function messageMentionsUser(content: string, username: string): boolean {
  const lowerUsername = username.toLowerCase();
  const regex = mentionsRegex();
  let match: RegExpExecArray | null;
  while ((match = regex.exec(content)) !== null) {
    const name = match[1];
    if (name !== undefined && (name === EVERYONE_MENTION || name.toLowerCase() === lowerUsername)) {
      return true;
    }
  }
  return false;
}

export type MentionTrigger = "@" | "#";

export interface MentionQuery {
  trigger: MentionTrigger;
  /** Text typed after the trigger, used to filter candidates. */
  query: string;
  /** Index in the textarea value where the trigger character starts. */
  start: number;
}

/** Detects an in-progress "@query" or "#query" token immediately before the cursor, if any. */
export function activeMentionQuery(value: string, cursor: number): MentionQuery | null {
  const upToCursor = value.slice(0, cursor);

  let start = -1;
  let trigger: MentionTrigger | null = null;
  for (let i = upToCursor.length - 1; i >= 0; i--) {
    const ch = upToCursor[i];
    if (ch === "@" || ch === "#") {
      start = i;
      trigger = ch;
      break;
    }
    if (/\s/.test(ch)) break;
  }
  if (start === -1 || !trigger) return null;

  // Only trigger at a word boundary — not mid-token, e.g. "foo@bar".
  const charBefore = upToCursor[start - 1];
  if (charBefore !== undefined && (/\w/.test(charBefore) || charBefore === trigger)) return null;

  return { trigger, query: upToCursor.slice(start + 1), start };
}

export interface MentionCandidate {
  key: string;
  label: string;
  insert: string;
}

export function mentionCandidates(
  trigger: MentionTrigger,
  query: string,
  users: User[],
  channels: Channel[],
  excludedUserId?: string,
): MentionCandidate[] {
  const lowerQuery = query.toLowerCase();

  if (trigger === "#") {
    return channels
      .filter((c) => c.type === "text" && c.name.toLowerCase().startsWith(lowerQuery))
      .map((c) => ({ key: c.id, label: c.name, insert: c.name }))
      .slice(0, 8);
  }

  const candidates: MentionCandidate[] = [];
  if (EVERYONE_MENTION.startsWith(lowerQuery)) {
    candidates.push({ key: "everyone", label: "everyone", insert: "everyone" });
  }
  for (const user of users) {
    if (user.id !== excludedUserId && user.username.toLowerCase().startsWith(lowerQuery)) {
      candidates.push({ key: user.id, label: user.username, insert: user.username });
    }
  }
  return candidates.slice(0, 8);
}
