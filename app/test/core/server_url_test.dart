import 'package:campfire/core/server_url.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizeServerUrl', () {
    test('assumes https when no scheme was typed', () {
      expect(normalizeServerUrl('dominio.com'), 'https://dominio.com');
    });

    test('keeps an explicit scheme, including plain http', () {
      expect(normalizeServerUrl('http://192.168.0.10:8000'), 'http://192.168.0.10:8000');
      expect(normalizeServerUrl('HTTPS://Dominio.com'), 'HTTPS://Dominio.com');
    });

    test('strips trailing slashes so paths concatenate cleanly', () {
      expect(normalizeServerUrl('https://dominio.com/'), 'https://dominio.com');
      expect(normalizeServerUrl('https://dominio.com///'), 'https://dominio.com');
    });

    test('trims what someone pasted with whitespace around it', () {
      expect(normalizeServerUrl('  dominio.com  '), 'https://dominio.com');
    });

    test('leaves a sub-path alone', () {
      expect(normalizeServerUrl('dominio.com/campfire'), 'https://dominio.com/campfire');
    });
  });
}
