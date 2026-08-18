import 'package:campfire/api/client.dart';
import 'package:campfire/api/endpoints.dart';
import 'package:campfire/api/token_holder.dart';
import 'package:campfire/state/auth.dart';
import 'package:campfire/state/settings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Lives outside the auth notifier so the API client can read and rotate the
/// access token without the two providers depending on each other's build.
final tokenHolderProvider = Provider<TokenHolder>((ref) => TokenHolder());

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    tokens: ref.watch(tokenHolderProvider),
    // `read`, deliberately: the client must see the current server on each
    // request, not pin the one that happened to be set when it was built.
    serverUrl: () => ref.read(settingsProvider).serverUrl,
    onSessionExpired: () => ref.read(authProvider.notifier).onSessionExpired(),
  );
});

final apiProvider = Provider<CampfireApi>(
  (ref) => CampfireApi(ref.watch(apiClientProvider)),
);
