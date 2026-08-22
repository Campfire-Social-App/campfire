import 'package:campfire/models/channel.dart';
import 'package:campfire/models/user.dart';
import 'package:meta/meta.dart';

/// Port of `lib/mentions.ts`, character for character — the two clients have to
/// linkify the same text the same way, or the same message reads differently
/// depending on where it is opened.
const everyoneMention = 'everyone';

/// Matches the same charset/length auth enforces for usernames (see
/// `server/app/schemas/auth.py`), plus the "everyone" pseudo-mention.
///
/// Channel names have no such restriction (free text, see
/// `server/app/models/channel.py`), so `#` just grabs the next run of
/// non-whitespace and it is checked against known channel names below — this
/// only linkifies cleanly for the common space-free "kebab-case" convention.
///
/// Both require a word boundary before the trigger, so `foo@bar` or a literal
/// `#` in prose is not misread as a mention.
final _mentionPattern = RegExp(
  r'(?<![\w@])@(everyone|[a-zA-Z0-9_]{3,32})\b'
  '|'
  r'(?<![\w#])#(\S+)',
);

/// Trailing punctuation that should not be swallowed into a channel name.
final _trailingPunctuation = RegExp(r'[.,!?;:)]+$');

enum MentionKind { everyone, user, channel }

/// A run of message text: plain when [mention] is null, otherwise the whole
/// `@name` or `#channel` token including its trigger character.
@immutable
class MentionSegment {
  const MentionSegment(this.text, {this.mention, this.channelId});

  final String text;
  final MentionKind? mention;

  /// Set for [MentionKind.channel] — what to open when the segment is tapped.
  final String? channelId;

  @override
  String toString() => 'MentionSegment($text, $mention)';

  @override
  bool operator ==(Object other) =>
      other is MentionSegment &&
      other.text == text &&
      other.mention == mention &&
      other.channelId == channelId;

  @override
  int get hashCode => Object.hash(text, mention, channelId);
}

/// Splits message content into plain-text and mention segments for rendering.
///
/// An `@name` that belongs to nobody, or a `#thing` that is not a channel,
/// stays plain text — the same call the web client makes, so an unknown handle
/// does not get highlighted as if it were real.
List<MentionSegment> splitMentions(
  String content,
  Set<String> knownUsernames,
  Map<String, Channel> channelsByName,
) {
  final segments = <MentionSegment>[];
  var lastIndex = 0;

  for (final match in _mentionPattern.allMatches(content)) {
    final userOrEveryone = match.group(1);
    final channelToken = match.group(2);

    MentionSegment? segment;
    var matchedLength = match.group(0)!.length;

    if (userOrEveryone != null) {
      final isKnown = userOrEveryone == everyoneMention ||
          knownUsernames.contains(userOrEveryone.toLowerCase());
      if (isKnown) {
        segment = MentionSegment(
          match.group(0)!,
          mention: userOrEveryone == everyoneMention
              ? MentionKind.everyone
              : MentionKind.user,
        );
      }
    } else if (channelToken != null) {
      final trimmed = channelToken.replaceFirst(_trailingPunctuation, '');
      final channel = channelsByName[trimmed.toLowerCase()];
      if (channel != null) {
        matchedLength = 1 + trimmed.length;
        segment = MentionSegment(
          '#$trimmed',
          mention: MentionKind.channel,
          channelId: channel.id,
        );
      }
    }

    if (segment == null) continue;

    if (match.start > lastIndex) {
      segments.add(MentionSegment(content.substring(lastIndex, match.start)));
    }
    segments.add(segment);
    lastIndex = match.start + matchedLength;
  }

  if (lastIndex < content.length) {
    segments.add(MentionSegment(content.substring(lastIndex)));
  }
  return segments;
}

/// Whether [content] mentions [username] directly or via `@everyone`. Drives
/// the highlight on the message row and, later, the notification.
bool messageMentionsUser(String content, String username) {
  final lower = username.toLowerCase();
  for (final match in _mentionPattern.allMatches(content)) {
    final name = match.group(1);
    if (name != null && (name == everyoneMention || name.toLowerCase() == lower)) {
      return true;
    }
  }
  return false;
}

enum MentionTrigger {
  user('@'),
  channel('#');

  const MentionTrigger(this.character);

  final String character;
}

/// An `@query` or `#query` being typed right now.
@immutable
class MentionQuery {
  const MentionQuery({required this.trigger, required this.query, required this.start});

  final MentionTrigger trigger;

  /// Text typed after the trigger, used to filter candidates.
  final String query;

  /// Index in the field's value where the trigger character starts.
  final int start;

  @override
  bool operator ==(Object other) =>
      other is MentionQuery &&
      other.trigger == trigger &&
      other.query == query &&
      other.start == start;

  @override
  int get hashCode => Object.hash(trigger, query, start);
}

/// Detects an in-progress mention immediately before the cursor, if any.
MentionQuery? activeMentionQuery(String value, int cursor) {
  final upToCursor = value.substring(0, cursor.clamp(0, value.length));

  var start = -1;
  MentionTrigger? trigger;
  for (var i = upToCursor.length - 1; i >= 0; i--) {
    final ch = upToCursor[i];
    if (ch == '@' || ch == '#') {
      start = i;
      trigger = ch == '@' ? MentionTrigger.user : MentionTrigger.channel;
      break;
    }
    if (RegExp(r'\s').hasMatch(ch)) break;
  }
  if (start == -1 || trigger == null) return null;

  // Only at a word boundary — not mid-token, e.g. "foo@bar".
  if (start > 0) {
    final before = upToCursor[start - 1];
    if (RegExp(r'\w').hasMatch(before) || before == trigger.character) return null;
  }

  return MentionQuery(
    trigger: trigger,
    query: upToCursor.substring(start + 1),
    start: start,
  );
}

/// One row of the autocomplete list.
class MentionCandidate {
  const MentionCandidate({required this.key, required this.label, required this.insert});

  /// Null for `@everyone`, which is not a person — the list uses it to decide
  /// between an avatar and a glyph.
  final String key;
  final String label;
  final String insert;
}

/// Up to eight matches for what is being typed, prefix-matched and in the order
/// the web client offers them: `everyone` first, then users, or text channels
/// for `#`.
List<MentionCandidate> mentionCandidates(
  MentionTrigger trigger,
  String query,
  List<User> users,
  List<Channel> channels,
) {
  final lower = query.toLowerCase();

  if (trigger == MentionTrigger.channel) {
    return channels
        .where((c) => c.type == ChannelType.text && c.name.toLowerCase().startsWith(lower))
        .map((c) => MentionCandidate(key: c.id, label: c.name, insert: c.name))
        .take(8)
        .toList();
  }

  return [
    if (everyoneMention.startsWith(lower))
      const MentionCandidate(
        key: everyoneMention,
        label: everyoneMention,
        insert: everyoneMention,
      ),
    for (final user in users)
      if (user.username.toLowerCase().startsWith(lower))
        MentionCandidate(key: user.id, label: user.username, insert: user.username),
  ].take(8).toList();
}
