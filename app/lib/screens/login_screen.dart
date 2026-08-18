import 'package:campfire/api/api_exception.dart';
import 'package:campfire/router.dart';
import 'package:campfire/state/auth.dart';
import 'package:campfire/state/settings.dart';
import 'package:campfire/theme/tokens.dart';
import 'package:campfire/widgets/auth_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _username.addListener(() => setState(() {}));
    _password.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  bool get _canSubmit => _username.text.isNotEmpty && _password.text.isNotEmpty;

  Future<void> _submit() async {
    if (!_canSubmit || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await ref.read(authProvider.notifier).login(_username.text, _password.text);
      // The router redirects on the auth state change.
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final serverUrl = ref.watch(settingsProvider).serverUrl ?? '';

    return AuthShell(
      title: 'Welcome back',
      description: serverUrl,
      children: [
        LabelledField(
          label: 'Username',
          controller: _username,
          autofocus: true,
          enabled: !_busy,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 16),
        LabelledField(
          label: 'Password',
          controller: _password,
          obscure: true,
          enabled: !_busy,
          textInputAction: TextInputAction.go,
          onSubmitted: (_) => _submit(),
        ),
        if (_error != null) FormError(_error!),
        const SizedBox(height: 24),
        SubmitButton(label: 'Sign in', busy: _busy, onPressed: _canSubmit ? _submit : null),
        const SizedBox(height: 16),
        _TextLink(
          'I have an invite — create an account',
          color: CampfireTokens.primary,
          onTap: _busy ? null : () => context.go(Routes.register),
        ),
        _TextLink(
          'Switch server',
          color: CampfireTokens.mutedForeground,
          onTap: _busy ? null : () => ref.read(settingsProvider.notifier).clearServerUrl(),
        ),
      ],
    );
  }
}

class _TextLink extends StatelessWidget {
  const _TextLink(this.label, {required this.color, this.onTap});

  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(foregroundColor: color),
      child: Text(label, textAlign: TextAlign.center),
    );
  }
}
