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
import 'package:campfire/state/dms.dart';
import 'package:campfire/state/gateway.dart';
import 'package:campfire/state/presence.dart';
import 'package:campfire/state/settings.dart';
import 'package:campfire/theme/night_sky.dart';
import 'package:campfire/theme/tokens.dart';
import 'package:campfire/ws/gateway.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'api/fake_adapter.dart';
import 'fixtures/gateway.dart';
import 'ws/fake_socket.dart';

void main() {
  late InMemorySecureStore store;

  /// Boots the real app against an in-memory keystore and a fake network.
  ///
  /// Pass [sockets] to stand in for the gateway: every connection attempt
  /// appends a fresh [FakeSocket] to it, which the test then pushes frames
  /// through. A list rather than one socket because a reconnect opens another
  /// one, and a single-subscription stream cannot be listened to twice.
  Future<void> pumpApp(
    WidgetTester tester, {
    (int, Object?) Function(RequestOptions)? handle,
    List<FakeSocket>? sockets,
  }) async {
    final adapter = FakeAdapter(handle ?? (_) => (200, <String, dynamic>{}));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          secureStoreProvider.overrideWithValue(store),
          if (sockets != null)
            gatewayProvider.overrideWith(
              (ref) => GatewayClient(
                serverUrl: () => ref.read(settingsProvider).serverUrl,
                accessToken: () => ref.read(tokenHolderProvider).accessToken,
                onAuthRejected: () => ref.read(authProvider.notifier).restoreSession(),
                connector: (_) {
                  final socket = FakeSocket();
                  sockets.add(socket);
                  return socket;
                },
              ),
            ),
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

      // Landing on the shell at all *is* the proof: the router only lets an
      // authenticated state through. The signed-in name used to be asserted
      // here, but it moved into the channel drawer with the adaptive shell, and
      // there is no drawer to open until READY brings channels.
      expect(find.byType(ShellScreen), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
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
  group('gateway wiring', () {
    /// Signs in ahead of the pump, so the shell is what the router lands on.
    Future<FakeSocket> bootIntoShell(WidgetTester tester) async {
      final session = SessionStore(store);
      await session.writeServerUrl('https://campfire.exemplo.com');
      await session.writeRefreshToken('refresh-abc');
      await session.writeUser(const User(id: 'u1', username: 'marcio', isAdmin: true));

      final sockets = <FakeSocket>[];
      await pumpApp(
        tester,
        handle: (_) => (200, {'access_token': 'novo', 'token_type': 'bearer'}),
        sockets: sockets,
      );
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(find.byType(ShellScreen), findsOneWidget);
      return sockets.single;
    }

    testWidgets('READY seeds the providers nothing is showing yet', (tester) async {
      // The regression: presence was first watched by the app bar and the DM
      // list by the drawer — both built *after* READY had already gone past on
      // a broadcast stream, so they stayed empty until something else moved.
      final socket = await bootIntoShell(tester);

      socket.deliver(readyFrame);
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }

      // Straight off READY, with the drawer never opened: the channel is on
      // screen and the header knows who is online.
      expect(find.text('geral'), findsOneWidget);
      expect(find.text('1 online'), findsOneWidget);

      // And the conversation READY carried is in state, badge and all.
      final container = ProviderScope.containerOf(
        tester.element(find.byType(ShellScreen)),
      );
      expect(container.read(dmsProvider).single.recipient.username, 'ana');
      expect(container.read(dmsProvider).single.unreadCount, 3);
      expect(container.read(presenceProvider), hasLength(1));

      // The socket keeps a heartbeat running for as long as it is up, so the
      // test has to put it down or the binding fails on the pending timer.
      container.read(gatewayProvider).disconnect();
      await tester.pump(const Duration(seconds: 7));
    });

    testWidgets('a session restored offline still gets a socket', (tester) async {
      // Reopening the app while the server is unreachable keeps the stored user
      // but leaves no access token behind (`restoreSession`). The socket used to
      // give up silently on that and strand the shell on "Connecting…"; now it
      // asks for a fresh token and retries.
      var refreshes = 0;
      final session = SessionStore(store);
      await session.writeServerUrl('https://campfire.exemplo.com');
      await session.writeRefreshToken('refresh-abc');
      await session.writeUser(const User(id: 'u1', username: 'marcio', isAdmin: true));

      final sockets = <FakeSocket>[];
      await pumpApp(
        tester,
        handle: (request) {
          if (!request.path.contains('refresh')) return (200, <String, dynamic>{});
          refreshes++;
          // First attempt: the network is down. Second: the server is back.
          return refreshes == 1
              ? (0, null)
              : (200, {'access_token': 'novo', 'token_type': 'bearer'});
        },
        sockets: sockets,
      );
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }

      // Signed in from the stored user, and the gateway has already asked for
      // the token it did not get — the first refresh is the failed restore, the
      // second is the socket refusing to give up quietly.
      expect(find.byType(ShellScreen), findsOneWidget);
      expect(refreshes, 2);

      // With a token in hand the session lands again, the lifecycle listener
      // reconnects, and the socket that used to never exist is open.
      expect(sockets, hasLength(1));

      sockets.single.deliver(readyFrame);
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(find.text('geral'), findsOneWidget);

      ProviderScope.containerOf(tester.element(find.byType(ShellScreen)))
          .read(gatewayProvider)
          .disconnect();
      await tester.pump(const Duration(seconds: 7));
    });
  });
}
