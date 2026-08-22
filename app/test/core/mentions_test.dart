import 'package:campfire/core/mentions.dart';
import 'package:campfire/models/channel.dart';
import 'package:campfire/models/user.dart';
import 'package:flutter_test/flutter_test.dart';

/// The cases `lib/mentions.ts` is written around. Both clients have to linkify
/// the same text the same way, so these are the contract for that.
void main() {
  const geral = Channel(
    id: 'c1',
    name: 'geral',
    type: ChannelType.text,
    position: 0,
  );
  const voz = Channel(
    id: 'c2',
    name: 'voz',
    type: ChannelType.voice,
    position: 1,
  );

  final knownUsernames = {'ana', 'marcio'};
  final channelsByName = {'geral': geral, 'voz': voz};

  List<MentionSegment> split(String content) =>
      splitMentions(content, knownUsernames, channelsByName);

  group('splitMentions', () {
    test('leaves text with no mentions in one piece', () {
      expect(split('bom dia'), [const MentionSegment('bom dia')]);
    });

    test('picks out a known user, keeping the trigger in the segment', () {
      expect(split('oi @ana tudo bem'), [
        const MentionSegment('oi '),
        const MentionSegment('@ana', mention: MentionKind.user),
        const MentionSegment(' tudo bem'),
      ]);
    });

    test('treats @everyone as its own kind', () {
      expect(split('@everyone atenção').first,
          const MentionSegment('@everyone', mention: MentionKind.everyone));
    });

    test('leaves an unknown handle as plain text', () {
      // Nobody is called "ninguem", so highlighting it would be a lie.
      expect(split('oi @ninguem'), [const MentionSegment('oi @ninguem')]);
    });

    test('does not read an email address as a mention', () {
      expect(split('escreve pra ana@exemplo.com'),
          [const MentionSegment('escreve pra ana@exemplo.com')]);
    });

    test('links a channel and carries its id', () {
      expect(split('vai pro #geral'), [
        const MentionSegment('vai pro '),
        const MentionSegment('#geral', mention: MentionKind.channel, channelId: 'c1'),
      ]);
    });

    test('does not swallow punctuation after a channel name', () {
      expect(split('vai pro #geral, agora'), [
        const MentionSegment('vai pro '),
        const MentionSegment('#geral', mention: MentionKind.channel, channelId: 'c1'),
        const MentionSegment(', agora'),
      ]);
    });

    test('leaves a # that is not a channel alone', () {
      expect(split('bug #42'), [const MentionSegment('bug #42')]);
    });

    test('handles several mentions in one line', () {
      expect(split('@ana e @marcio no #voz'), [
        const MentionSegment('@ana', mention: MentionKind.user),
        const MentionSegment(' e '),
        const MentionSegment('@marcio', mention: MentionKind.user),
        const MentionSegment(' no '),
        const MentionSegment('#voz', mention: MentionKind.channel, channelId: 'c2'),
      ]);
    });
  });

  group('messageMentionsUser', () {
    test('matches the name regardless of case', () {
      expect(messageMentionsUser('oi @Ana', 'ana'), isTrue);
    });

    test('matches @everyone for anyone', () {
      expect(messageMentionsUser('@everyone', 'marcio'), isTrue);
    });

    test('does not match a different name', () {
      expect(messageMentionsUser('oi @ana', 'marcio'), isFalse);
    });

    test('does not match a name inside a word', () {
      expect(messageMentionsUser('banana@ana', 'ana'), isFalse);
    });
  });

  group('activeMentionQuery', () {
    test('finds the token being typed at the cursor', () {
      final query = activeMentionQuery('oi @an', 6);
      expect(query?.trigger, MentionTrigger.user);
      expect(query?.query, 'an');
      expect(query?.start, 3);
    });

    test('finds a channel token', () {
      expect(activeMentionQuery('vai pro #ge', 11)?.trigger, MentionTrigger.channel);
    });

    test('is null with no trigger before the cursor', () {
      expect(activeMentionQuery('bom dia', 7), isNull);
    });

    test('is null mid-word, so an email is not an autocomplete', () {
      expect(activeMentionQuery('ana@exemplo', 11), isNull);
    });

    test('stops at whitespace rather than reaching back a whole sentence', () {
      expect(activeMentionQuery('@ana bom dia', 12), isNull);
    });

    test('reads the trigger alone as an empty query, which lists everyone', () {
      expect(activeMentionQuery('@', 1)?.query, '');
    });
  });

  group('mentionCandidates', () {
    final users = [
      const User(id: 'u1', username: 'ana', isAdmin: false),
      const User(id: 'u2', username: 'marcio', isAdmin: true),
    ];
    final channels = [geral, voz];

    test('offers everyone first, then matching users', () {
      final candidates = mentionCandidates(MentionTrigger.user, '', users, channels);
      expect(candidates.map((c) => c.label), ['everyone', 'ana', 'marcio']);
    });

    test('filters users by prefix', () {
      final candidates = mentionCandidates(MentionTrigger.user, 'ma', users, channels);
      expect(candidates.map((c) => c.label), ['marcio']);
    });

    test('offers only text channels for #', () {
      // A voice channel has nothing to link to — you cannot post in it.
      final candidates = mentionCandidates(MentionTrigger.channel, '', users, channels);
      expect(candidates.map((c) => c.label), ['geral']);
    });

    test('caps the list at eight', () {
      final many = [
        for (var i = 0; i < 20; i++)
          User(id: 'u$i', username: 'user$i', isAdmin: false),
      ];
      expect(
        mentionCandidates(MentionTrigger.user, 'user', many, channels),
        hasLength(8),
      );
    });
  });
}
