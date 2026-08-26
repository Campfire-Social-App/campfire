import 'package:campfire/theme/icons.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every icon resolves to the bundled Lucide font', () {
    // A Lucide upgrade that renames or drops a glyph would otherwise show up as
    // a blank square at runtime, on whichever screen happens to use it.
    for (final icon in CampfireIcons.all) {
      expect(icon.fontFamily, 'Lucide', reason: 'icon ${icon.codePoint}');
      expect(icon.fontPackage, 'lucide_icons_flutter');
      expect(icon.codePoint, greaterThan(0));
    }
  });

  test('covers the icons the React client draws, without duplicating a role', () {
    // One name per role the React client draws, plus `switchCamera`, which has
    // no counterpart there because a desktop has one camera to point at you.
    // The count is a tripwire: dropping a role here means a screen that quietly
    // stops matching the other client.
    expect(CampfireIcons.all, hasLength(61));

    // Roles map onto glyphs almost one to one; the speaker is deliberately
    // shared, marking both a voice channel and the media player's volume.
    expect(CampfireIcons.all.toSet(), hasLength(60));
    expect(CampfireIcons.voiceChannel, CampfireIcons.volumeHigh);
  });
}
