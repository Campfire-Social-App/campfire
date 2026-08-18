import 'package:campfire/api/client.dart';
import 'package:campfire/app.dart';
import 'package:campfire/core/secure_store.dart';
import 'package:campfire/models/user.dart';
import 'package:campfire/screens/login_screen.dart';
import 'package:campfire/screens/register_screen.dart';
import 'package:campfire/screens/server_connect_screen.dart';
import 'package:campfire/screens/shell_screen.dart';
import 'package:campfire/screens/splash_screen.dart';
import 'package:campfire/state/api.dart';
import 'package:campfire/state/auth.dart';
import 'package:campfire/state/settings.dart';
import 'package:campfire/theme/night_sky.dart';
import 'package:campfire/theme/tokens.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'api/fake_adapter.dart';

void main() {
  late InMemorySecureStore store;

  /// Boots the real app against an in-memory keystore and a fake network.
  Future<void> pumpApp(
    WidgetTester tester, {
    (int, Object?) Function(RequestOptions)? handle,
  }) async {
    final adapter = FakeAdapter(handle ?? (_) => (200, <String, dynamic>{}));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          secureStoreProvider.overrideWithValue(store),
          apiClientProvider.overrideWith(
            (ref) => ApiClient(
              tokens: ref.watch(tokenHolderProvider),
              serverUrl: () => ref.read(settingsProvider).serverUrl,
              onSessionExpired: () => ref.read(authProvider.notifier).onSessionExpired(),
              dio: Dio()..httpClientAdapter = adapter,
              refreshDio: Dio()..httpClientAdapter = adapter,
            ),
          ),
        ],
        child: const CampfireApp(),
      ),
    );
  }

  setUp(() => store = InMemorySecureStore());

  group('identity', () {
    testWidgets('opens onto the night sky with the ember accent', (tester) async {
      await pumpApp(tester);

      expect(find.byType(NightSky), findsOneWidget);
      expect(find.text('Campfire'), findsOneWidget);

      final theme = Theme.of(tester.element(find.text('Campfire')));
      // The wordmark is set in Fraunces; everything else in Geist.
      expect(theme.textTheme.displaySmall?.fontFamily, 'Fraunces');
      expect(theme.textTheme.bodyMedium?.fontFamily, 'Geist');
      expect(theme.colorScheme.primary, CampfireTokens.primary);
      // Nothing but the backdrop paints a background — see NightSky.
      expect(theme.scaffoldBackgroundColor, Colors.transparent);
    });

    testWidgets('the ember keeps breathing frame after frame', (tester) async {
      await pumpApp(tester);

      // A finished animation would settle; the glow is meant to loop for as
      // long as the app is open.
      await tester.pump(const Duration(seconds: 1));
      expect(tester.hasRunningAnimations, isTrue);
      await tester.pump(const Duration(seconds: 8));
      expect(tester.hasRunningAnimations, isTrue);

      // Leaves the animation mid-cycle rather than mid-frame.
      await tester.pump(const Duration(seconds: 7));
    });
  });

  group('boot routing', () {
    testWidgets('starts on the splash while the keystore is being read', (tester) async {
      await pumpApp(tester);

      // Not yet pumped past the first frame: nothing has been read.
      expect(find.byType(SplashScreen), findsOneWidget);
      await tester.pump(const Duration(seconds: 7));
    });

    testWidgets('a clean install lands on the connect screen', (tester) async {
      await pumpApp(tester);
      await tester.pump();
      await tester.pump();

      expect(find.byType(ServerConnectScreen), findsOneWidget);
      expect(find.text('Connect to a server'), findsOneWidget);
      await tester.pump(const Duration(seconds: 7));
    });

    testWidgets('a stored server with no session lands on login', (tester) async {
      await SessionStore(store).writeServerUrl('https://campfire.exemplo.com');

      await pumpApp(tester);
      await tester.pump();
      await tester.pump();

      expect(find.byType(LoginScreen), findsOneWidget);
      // The card's subtitle is the server you are signing in to.
      expect(find.text('https://campfire.exemplo.com'), findsOneWidget);
      await tester.pump(const Duration(seconds: 7));
    });

    testWidgets('a stored session goes straight through to the shell', (tester) async {
      // The point of D4: reopening the app does not show a login screen.
      final session = SessionStore(store);
      await session.writeServerUrl('https://campfire.exemplo.com');
      await session.writeRefreshToken('refresh-abc');
      await session.writeUser(const User(id: 'u1', username: 'marcio', isAdmin: true));

      await pumpApp(
        tester,
        handle: (_) => (200, {'access_token': 'novo', 'token_type': 'bearer'}),
      );
      // Not `pumpAndSettle`: the shell's ember animation never settles, by
      // design, so settling would wait forever.
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }

      expect(find.byType(ShellScreen), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
      expect(find.text('marcio'), findsOneWidget);
      await tester.pump(const Duration(seconds: 7));
    });

    testWidgets('login reaches the register screen and back', (tester) async {
      await SessionStore(store).writeServerUrl('https://campfire.exemplo.com');
      await pumpApp(tester);
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('I have an invite — create an account'));
      await tester.pumpAndSettle();
      expect(find.byType(RegisterScreen), findsOneWidget);

      await tester.tap(find.text('I already have an account'));
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      await tester.pump(const Duration(seconds: 7));
    });

    testWidgets('switching server from login goes back to connect', (tester) async {
      await SessionStore(store).writeServerUrl('https://campfire.exemplo.com');
      await pumpApp(tester);
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('Switch server'));
      await tester.pumpAndSettle();

      expect(find.byType(ServerConnectScreen), findsOneWidget);
      await tester.pump(const Duration(seconds: 7));
    });
  });
}
