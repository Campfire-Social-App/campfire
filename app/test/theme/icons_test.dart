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
    // The client imports 61 names from lucide-react, two pairs of which are the
    // same glyph under an alias (`X`/`XIcon`, `Loader2`/`Loader2Icon`), leaving
    // 59 distinct roles — plus `switchCamera`, which has no counterpart there
    // because a desktop has one camera to point at you.
    expect(CampfireIcons.all, hasLength(60));

    // Roles map onto glyphs almost one to one; the speaker is deliberately
    // shared, marking both a voice channel and the media player's volume.
    expect(CampfireIcons.all.toSet(), hasLength(59));
    expect(CampfireIcons.voiceChannel, CampfireIcons.volumeHigh);
  });
}
