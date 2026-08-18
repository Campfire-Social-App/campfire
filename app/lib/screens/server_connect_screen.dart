import 'package:campfire/api/client.dart';
import 'package:campfire/api/endpoints.dart';
import 'package:campfire/core/server_url.dart';
import 'package:campfire/state/api.dart';
import 'package:campfire/state/settings.dart';
import 'package:campfire/widgets/auth_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// First screen on a clean install: which self-hosted server to talk to.
///
/// The address is checked against `/health` before it is stored, so a typo
/// fails here with a clear message instead of surfacing as a mysterious login
/// failure two screens later.
class ServerConnectScreen extends ConsumerStatefulWidget {
  const ServerConnectScreen({super.key});

  @override
  ConsumerState<ServerConnectScreen> createState() => _ServerConnectScreenState();
}

class _ServerConnectScreenState extends ConsumerState<ServerConnectScreen> {
  final _url = TextEditingController();
  bool _checking = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _url.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final typed = _url.text.trim();
    if (typed.isEmpty || _checking) return;

    setState(() {
      _checking = true;
      _error = null;
    });

    final normalized = normalizeServerUrl(typed);
    // Probes the address the user typed, not the stored one — nothing is saved
    // until it answers.
    final probe = CampfireApi(
      ApiClient(
        tokens: ref.read(tokenHolderProvider),
        serverUrl: () => normalized,
        onSessionExpired: () async {},
      ),
    );

    final reachable = await probe.health();
    if (!mounted) return;

    if (!reachable) {
      setState(() {
        _checking = false;
        _error = "Couldn't connect to that server. Check the address.";
      });
      return;
    }

    await ref.read(settingsProvider.notifier).setServerUrl(normalized);
    // The router redirects away from here on the settings change; no pop.
  }

  @override
  Widget build(BuildContext context) {
    return AuthShell(
      title: 'Connect to a server',
      description:
          'Enter the address of the self-hosted Campfire server you want to connect to.',
      children: [
        LabelledField(
          label: 'Server address',
          controller: _url,
          hint: 'campfire.mydomain.com',
          autofocus: true,
          enabled: !_checking,
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.go,
          onSubmitted: (_) => _connect(),
        ),
        if (_error != null) FormError(_error!),
        const SizedBox(height: 24),
        SubmitButton(
          label: 'Connect',
          busy: _checking,
          onPressed: _url.text.trim().isEmpty ? null : _connect,
        ),
      ],
    );
  }
}
