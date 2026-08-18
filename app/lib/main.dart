import 'dart:async';

import 'package:campfire/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Edge to edge, before the first frame: the night sky has to paint behind the
  // status and navigation bars, or the ember glow rising from the bottom of the
  // screen gets clipped by the nav bar — which is the one part of the backdrop
  // that most needs to reach the edge.
  unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));

  runApp(const ProviderScope(child: CampfireApp()));
}
