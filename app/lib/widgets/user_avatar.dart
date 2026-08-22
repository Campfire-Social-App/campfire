import 'package:campfire/state/api.dart';
import 'package:campfire/theme/theme.dart';
import 'package:campfire/theme/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Fire embers mixed with night-sky tones, so avatars stay distinguishable
/// without clashing with the campfire-orange the UI chrome already uses.
///
/// Same eight colours, same order, same hash as `UserAvatar.tsx` — a user has
/// to come out the same colour in both clients, or the two stop looking like
/// one product on the same screen.
const _palette = <Color>[
  Color(0xFFF0463F),
  Color(0xFFFBBF24),
  Color(0xFFFF9D42),
  Color(0xFF4ADE80),
  Color(0xFF38BDF8),
  Color(0xFF9C84EF),
  Color(0xFFF472B6),
  Color(0xFF2DD4BF),
];

/// The React client's `paletteIndex`: a 32-bit `hash * 31 + char` fold.
///
/// JavaScript's `<<` truncates to 32 bits and `Math.abs` is taken of the signed
/// result, so the Dart port has to do both by hand — `int` here is 64-bit, and
/// letting it grow would pick a different colour for the same name.
int paletteIndexFor(String username) {
  var hash = 0;
  for (final code in username.codeUnits) {
    hash = ((hash << 5) - hash + code).toSigned(32);
  }
  return hash.abs() % _palette.length;
}

/// The colour a username is written in, matching that user's avatar.
Color usernameColorFor(String username) => _palette[paletteIndexFor(username)];

/// Whether the dot on the avatar is green or grey. Absent means no dot at all —
/// the rail's own server button and the composer's avatar both want that.
enum PresenceDot { online, offline }

enum AvatarSize {
  sm(28, 11),
  md(36, 13),
  lg(48, 17),

  /// The two call-stage sizes: a grid tile with the camera off, and the focused
  /// tile, where the avatar carries the whole frame.
  xl(96, 34),
  xxl(160, 52);

  const AvatarSize(this.diameter, this.fontSize);

  final double diameter;
  final double fontSize;
}

/// Circle with the user's first two initials, their photo when they have one,
/// and the presence dot on the corner.
///
/// [speaking] draws the ember ring the voice channel uses to show who has the
/// floor — the same `ring-2 ring-primary` plus glow as the web client.
class UserAvatar extends ConsumerWidget {
  const UserAvatar({
    required this.username,
    this.avatarUrl,
    this.size = AvatarSize.md,
    this.status,
    this.speaking = false,
    super.key,
  });

  final String username;
  final String? avatarUrl;
  final AvatarSize size;
  final PresenceDot? status;
  final bool speaking;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = usernameColorFor(username);
    final initials = username.length >= 2
        ? username.substring(0, 2).toUpperCase()
        : username.toUpperCase();

    Widget avatar = Container(
      width: size.diameter,
      height: size.diameter,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      clipBehavior: Clip.antiAlias,
      child: Text(
        initials,
        style: TextStyle(
          fontFamily: 'Geist',
          fontSize: size.fontSize,
          fontWeight: FontWeights.semiBold,
          fontVariations: const [FontVariation('wght', 600)],
          color: Colors.white,
        ),
      ),
    );

    final url = avatarUrl;
    if (url != null && url.isNotEmpty) {
      avatar = ClipOval(
        child: SizedBox(
          width: size.diameter,
          height: size.diameter,
          // The initials stay underneath: they are what shows while the photo
          // is in flight and what stays if it 404s after the user was deleted.
          child: Stack(
            fit: StackFit.expand,
            children: [
              avatar,
              Image.network(
                ref.read(apiClientProvider).resolveAssetUrl(url),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      );
    }

    if (speaking) {
      avatar = Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: CampfireTokens.primary, width: 2),
          boxShadow: const [
            BoxShadow(color: CampfireTokens.primary, blurRadius: 12, spreadRadius: 1),
          ],
        ),
        child: avatar,
      );
    }

    if (status == null) return avatar;

    final dot = size.diameter * 0.3;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        avatar,
        Positioned(
          right: speaking ? -1 : 0,
          bottom: speaking ? -1 : 0,
          child: Container(
            width: dot,
            height: dot,
            decoration: BoxDecoration(
              color: status == PresenceDot.online
                  ? CampfireTokens.online
                  : CampfireTokens.offline,
              shape: BoxShape.circle,
              // Ringed in the backdrop colour so the dot reads as cut out of
              // the avatar rather than floating on top of it.
              border: Border.all(color: CampfireTokens.background, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}
