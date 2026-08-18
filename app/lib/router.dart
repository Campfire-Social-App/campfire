import 'package:campfire/screens/login_screen.dart';
import 'package:campfire/screens/register_screen.dart';
import 'package:campfire/screens/server_connect_screen.dart';
import 'package:campfire/screens/shell_screen.dart';
import 'package:campfire/screens/splash_screen.dart';
import 'package:campfire/state/auth.dart';
import 'package:campfire/state/settings.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

abstract final class Routes {
  static const splash = '/splash';
  static const connect = '/connect';
  static const login = '/login';
  static const register = '/register';
  static const home = '/';
}

/// Bridges the two providers the redirect reads into something `GoRouter` will
/// listen to — without it the router would only re-evaluate on navigation, and
/// a session expiring mid-session would leave the user staring at a shell with
/// no data behind it.
final _routerRefreshProvider = Provider<Listenable>((ref) {
  final notifier = ValueNotifier(0);
  ref
    ..onDispose(notifier.dispose)
    ..listen(authProvider, (_, _) => notifier.value++)
    ..listen(settingsProvider, (_, _) => notifier.value++);
  return notifier;
});

/// The `switch` that `App.tsx` performs on state, expressed as a redirect:
/// restore -> connect -> auth -> shell.
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: Routes.splash,
    refreshListenable: ref.watch(_routerRefreshProvider),
    redirect: (context, state) {
      final settings = ref.read(settingsProvider);
      final auth = ref.read(authProvider);
      final here = state.matchedLocation;

      // Still reading the keystore. Anything else would flash a screen that the
      // stored session is about to replace.
      if (!settings.loaded || auth is AuthRestoring) {
        return here == Routes.splash ? null : Routes.splash;
      }

      if (!settings.hasServer) {
        return here == Routes.connect ? null : Routes.connect;
      }

      if (auth is AuthUnauthenticated) {
        // Register is a peer of login, not a step past it.
        const authScreens = {Routes.login, Routes.register};
        return authScreens.contains(here) ? null : Routes.login;
      }

      return here == Routes.home ? null : Routes.home;
    },
    routes: [
      GoRoute(path: Routes.splash, builder: (_, _) => const SplashScreen()),
      GoRoute(path: Routes.connect, builder: (_, _) => const ServerConnectScreen()),
      GoRoute(path: Routes.login, builder: (_, _) => const LoginScreen()),
      GoRoute(path: Routes.register, builder: (_, _) => const RegisterScreen()),
      GoRoute(path: Routes.home, builder: (_, _) => const ShellScreen()),
    ],
  );
});
