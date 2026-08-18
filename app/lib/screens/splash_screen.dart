import 'package:campfire/theme/icons.dart';
import 'package:campfire/theme/night_sky.dart';
import 'package:campfire/theme/tokens.dart';
import 'package:flutter/material.dart';

/// What the app shows while the keystore is read and the stored session is
/// traded for a fresh access token. The router leaves it as soon as it knows
/// where the user belongs.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return NightSky(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(CampfireIcons.brand, size: 56, color: CampfireTokens.primary),
              const SizedBox(height: 20),
              Text('Campfire', style: theme.textTheme.displaySmall),
              const SizedBox(height: 28),
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: CampfireTokens.ember,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
