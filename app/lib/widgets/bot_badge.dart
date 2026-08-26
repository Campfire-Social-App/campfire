import 'package:campfire/theme/tokens.dart';
import 'package:flutter/material.dart';

/// Marks an account driven by the bots service rather than by a person.
///
/// Same pill as the `admin` label in the member list, so a row reads the same
/// whichever badge it carries. Port of `BotBadge.tsx`.
class BotBadge extends StatelessWidget {
  const BotBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: CampfireTokens.emberTint,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        'bot',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontSize: 10,
              color: CampfireTokens.ember,
            ),
      ),
    );
  }
}
