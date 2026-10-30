import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../widgets/animations.dart';
import '../widgets/common.dart';
import 'auth_controller.dart';
import 'auth_screens.dart' show ShowPasswordButton, isEmail;

/// Forgot password: the email, then the 6-digit code we send and a new password. Signs in.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key, this.email});

  final String? email; // typed on the sign-in screen

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _form = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.email);
  final _code = TextEditingController();
  final _password = TextEditingController();
  bool _sent = false; // second step: the code and the new password
  bool _busy = false;
  bool _showPassword = false;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _send() => _run(() async {
    await ref.read(apiProvider).requestPasswordReset(_email.text.trim());
    if (!mounted) return;
    setState(() => _sent = true);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.codeSent)));
  });

  Future<void> _confirm() => _run(() async {
    final tokens = await ref
        .read(apiProvider)
        .confirmPasswordReset(_email.text.trim(), _code.text.trim(), _password.text);
    await ref.read(authProvider.notifier).signedIn(tokens); // the router takes it from here
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final muted = TextStyle(color: context.tokens.muted);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.forgotPassword)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Form(
            key: _form,
            child: AutofillGroup(
              child: FadeSlideIn(
                key: ValueKey(_sent),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 12,
                  children: [
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(shape: BoxShape.circle, color: context.tokens.tonal),
                        child: Icon(
                          _sent ? LucideIcons.mailCheck : LucideIcons.keyRound,
                          size: 40,
                          color: context.tokens.accent,
                        ),
                      ),
                    ),
                    Text(
                      _sent ? l10n.enterCodeTitle : l10n.forgotPasswordTitle,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall,
                    ),
                    Text(
                      _sent ? l10n.enterCodeHelp(_email.text.trim()) : l10n.forgotPasswordHelp,
                      textAlign: TextAlign.center,
                      style: muted,
                    ),
                    const SizedBox(height: 4),
                    if (!_sent) ...[
                      FieldLabel(l10n.email),
                      TextFormField(
                        controller: _email,
                        decoration: InputDecoration(prefixIcon: const Icon(LucideIcons.mail), hintText: l10n.emailHint),
                        keyboardType: TextInputType.emailAddress,
                        autocorrect: false,
                        autofillHints: const [AutofillHints.email],
                        onFieldSubmitted: (_) => _send(),
                        validator: (v) => isEmail(v ?? '') ? null : l10n.invalidEmail,
                      ),
                      FilledButton(
                        onPressed: _busy ? null : _send,
                        child: _busy ? const _Spinner() : Text(l10n.sendCode),
                      ),
                    ] else ...[
                      CodeField(controller: _code),
                      FieldLabel(l10n.newPassword),
                      TextFormField(
                        controller: _password,
                        obscureText: !_showPassword,
                        autocorrect: false,
                        enableSuggestions: false,
                        autofillHints: const [AutofillHints.newPassword],
                        decoration: InputDecoration(
                          prefixIcon: const Icon(LucideIcons.lock),
                          helperText: l10n.passwordTooShort,
                          suffixIcon: ShowPasswordButton(
                            shown: _showPassword,
                            onPressed: () => setState(() => _showPassword = !_showPassword),
                          ),
                        ),
                        onFieldSubmitted: (_) => _confirm(),
                        validator: (v) => (v ?? '').length < 8 ? l10n.passwordTooShort : null,
                      ),
                      FilledButton(
                        onPressed: _busy ? null : _confirm,
                        child: _busy ? const _Spinner() : Text(l10n.setPasswordAndSignIn),
                      ),
                      TextButton(onPressed: _busy ? null : _send, child: Text(l10n.sendNewCode)),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The 6 digits from the email: big, spaced, filled in by the keyboard's suggestion when it can.
class CodeField extends StatelessWidget {
  const CodeField({super.key, required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FieldLabel(l10n.code),
        TextFormField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofillHints: const [AutofillHints.oneTimeCode],
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: 8),
          decoration: const InputDecoration(hintText: '••••••'),
          validator: (v) => (v ?? '').length == 6 ? null : l10n.codeSixDigits,
        ),
      ],
    );
  }
}

class _Spinner extends StatelessWidget {
  const _Spinner();

  @override
  Widget build(BuildContext context) =>
      const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2));
}
