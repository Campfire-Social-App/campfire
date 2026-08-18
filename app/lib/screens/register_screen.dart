import 'package:campfire/api/api_exception.dart';
import 'package:campfire/router.dart';
import 'package:campfire/state/auth.dart';
import 'package:campfire/theme/tokens.dart';
import 'package:campfire/widgets/auth_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Registration is invite-only — the server has no open sign-up.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _inviteCode = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  /// Matches the server's own floor (`RegisterRequest.password`), so an
  /// obviously-too-short password never costs a round trip.
  static const _minPasswordLength = 8;

  @override
  void initState() {
    super.initState();
    for (final controller in [_inviteCode, _username, _password]) {
      controller.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _inviteCode.dispose();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      _inviteCode.text.isNotEmpty &&
      _username.text.isNotEmpty &&
      _password.text.length >= _minPasswordLength;

  Future<void> _submit() async {
    if (!_canSubmit || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await ref
          .read(authProvider.notifier)
          .register(_inviteCode.text, _username.text, _password.text);
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
    return AuthShell(
      title: 'Create account',
      description: 'You need an invite to join.',
      children: [
        LabelledField(
          label: 'Invite code',
          controller: _inviteCode,
          autofocus: true,
          enabled: !_busy,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 16),
        LabelledField(
          label: 'Username',
          controller: _username,
          enabled: !_busy,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 16),
        LabelledField(
          label: 'Password',
          controller: _password,
          obscure: true,
          enabled: !_busy,
          helper: 'At least $_minPasswordLength characters.',
          textInputAction: TextInputAction.go,
          onSubmitted: (_) => _submit(),
        ),
        if (_error != null) FormError(_error!),
        const SizedBox(height: 24),
        SubmitButton(
          label: 'Create account',
          busy: _busy,
          onPressed: _canSubmit ? _submit : null,
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _busy ? null : () => context.go(Routes.login),
          style: TextButton.styleFrom(foregroundColor: CampfireTokens.primary),
          child: const Text('I already have an account'),
        ),
      ],
    );
  }
}
