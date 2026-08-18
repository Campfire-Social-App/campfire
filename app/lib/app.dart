import 'package:campfire/router.dart';
import 'package:campfire/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Root of the app: theme, system bars, and the router that stands in for
/// `App.tsx`'s switch over auth state.
class CampfireApp extends ConsumerWidget {
  const CampfireApp({super.key});

  /// Light glyphs on transparent bars. Declared through [AnnotatedRegion] rather
  /// than a one-off `SystemChrome` call so it is reapplied whenever the route
  /// stack changes — a pushed screen that sets its own style would otherwise
  /// leave the bars wrong on the way back.
  static const _systemBars = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarBrightness: Brightness.dark,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.light,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _systemBars,
      child: MaterialApp.router(
        title: 'Campfire',
        debugShowCheckedModeBanner: false,
        theme: buildCampfireTheme(),
        routerConfig: ref.watch(routerProvider),
      ),
    );
  }
}
