import 'package:campfire/theme/icons.dart';
import 'package:campfire/theme/night_sky.dart';
import 'package:campfire/theme/tokens.dart';
import 'package:flutter/material.dart';

/// Shared full-bleed starfield backdrop and glowing campfire badge for the
/// connect / login / register screens. Port of `AuthShell.tsx`.
class AuthShell extends StatelessWidget {
  const AuthShell({
    required this.title,
    required this.description,
    required this.children,
    super.key,
  });

  final String title;
  final String description;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Starfield(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: ConstrainedBox(
                // `max-w-sm`: the card stays a card on a tablet instead of
                // stretching into a banner.
                constraints: const BoxConstraints(maxWidth: 384),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    // Not quite opaque, so the starfield shows through the way
                    // `bg-card/90` does on the web.
                    color: CampfireTokens.card.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(CampfireTokens.radius * 1.8),
                    border: Border.all(color: CampfireTokens.border),
                    boxShadow: const [
                      BoxShadow(color: Color(0x80000000), blurRadius: 40, offset: Offset(0, 20)),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Center(child: _CampfireBadge()),
                        const SizedBox(height: 12),
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineSmall?.copyWith(fontSize: 18),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          description,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: CampfireTokens.mutedForeground,
                          ),
                        ),
                        const SizedBox(height: 24),
                        ...children,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The amber-to-red gradient tile with the flame, and the warm bloom around it.
class _CampfireBadge extends StatelessWidget {
  const _CampfireBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(CampfireTokens.radius * 1.8),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFBBF24), Color(0xFFF97316), Color(0xFFDC2626)],
        ),
        boxShadow: const [
          BoxShadow(color: Color(0x59FF7A3D), blurRadius: 45, spreadRadius: 8),
        ],
      ),
      child: const Icon(CampfireIcons.brand, size: 32, color: Colors.white),
    );
  }
}

/// Label + field pair, matching the `Label`/`Input` stack the web forms use.
class LabelledField extends StatelessWidget {
  const LabelledField({
    required this.label,
    required this.controller,
    this.hint,
    this.helper,
    this.obscure = false,
    this.autofocus = false,
    this.textInputAction,
    this.keyboardType,
    this.onSubmitted,
    this.enabled = true,
    super.key,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final String? helper;
  final bool obscure;
  final bool autofocus;
  final TextInputAction? textInputAction;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.labelLarge),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscure,
          autofocus: autofocus,
          enabled: enabled,
          textInputAction: textInputAction,
          keyboardType: keyboardType,
          onSubmitted: onSubmitted,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(hintText: hint),
        ),
        if (helper != null) ...[
          const SizedBox(height: 6),
          Text(
            helper!,
            style: theme.textTheme.labelMedium?.copyWith(
              color: CampfireTokens.mutedForeground,
            ),
          ),
        ],
      ],
    );
  }
}

/// Primary action with the inline spinner the web buttons show while pending.
class SubmitButton extends StatelessWidget {
  const SubmitButton({
    required this.label,
    required this.onPressed,
    this.busy = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: busy ? null : onPressed,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (busy) ...[
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 8),
          ],
          Text(label),
        ],
      ),
    );
  }
}

/// Inline form error, instead of a toast: on a phone a toast can be missed, and
/// on these screens the message is the only thing standing between the user and
/// the app.
class FormError extends StatelessWidget {
  const FormError(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Text(
        message,
        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
      ),
    );
  }
}
