/// Turns whatever someone typed into a base URL the API client can concatenate
/// onto: no trailing slash, and a scheme assumed when none was given.
///
/// Ported from `state/settings.ts` — the two clients must agree, or the same
/// input produces two different servers.
String normalizeServerUrl(String url) {
  final trimmed = url.trim().replaceAll(RegExp(r'/+$'), '');
  if (RegExp('^https?://', caseSensitive: false).hasMatch(trimmed)) return trimmed;
  // Defaults to https: a self-hosted server reachable over plain http is the
  // exception, and typing the scheme is how you ask for it.
  return 'https://$trimmed';
}
