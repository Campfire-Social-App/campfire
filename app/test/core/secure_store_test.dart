import 'package:campfire/core/secure_store.dart';
import 'package:campfire/models/user.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late InMemorySecureStore backing;
  late SessionStore store;

  setUp(() {
    backing = InMemorySecureStore();
    store = SessionStore(backing);
  });

  test('a restart sees what the previous run wrote', () async {
    await store.writeServerUrl('https://campfire.exemplo.com');
    await store.writeRefreshToken('refresh-abc');
    await store.writeUser(const User(id: 'u1', username: 'marcio', isAdmin: true));

    // Same backing keystore, fresh object graph — what relaunching the app does.
    final restarted = SessionStore(backing);

    expect(await restarted.readServerUrl(), 'https://campfire.exemplo.com');
    expect(await restarted.readRefreshToken(), 'refresh-abc');
    expect((await restarted.readUser())?.username, 'marcio');
  });

  test('reads back nothing on a clean install', () async {
    expect(await store.readServerUrl(), isNull);
    expect(await store.readRefreshToken(), isNull);
    expect(await store.readUser(), isNull);
    expect(await store.readNoiseSuppressionEnabled(), isTrue);
  });

  test('persists the noise suppression preference', () async {
    await store.writeNoiseSuppressionEnabled(enabled: false);
    expect(await SessionStore(backing).readNoiseSuppressionEnabled(), isFalse);
  });

  test('signing out keeps the server so the next login lands on it', () async {
    await store.writeServerUrl('https://campfire.exemplo.com');
    await store.writeRefreshToken('refresh-abc');
    await store.writeUser(const User(id: 'u1', username: 'marcio', isAdmin: false));

    await store.clearSession();

    expect(await store.readRefreshToken(), isNull);
    expect(await store.readUser(), isNull);
    expect(await store.readServerUrl(), 'https://campfire.exemplo.com');
  });

  test('drops a stored user an older build wrote in a shape that no longer parses', () async {
    await backing.write('campfire.user', 'not json');

    expect(await store.readUser(), isNull);
    expect(await backing.read('campfire.user'), isNull);
  });

  test('changing servers clears the URL but is a separate act from signing out', () async {
    await store.writeServerUrl('https://um.exemplo.com');
    await store.clearServerUrl();

    expect(await store.readServerUrl(), isNull);
  });
}
