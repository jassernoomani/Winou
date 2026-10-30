import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme.dart';
import '../widgets/animations.dart';
import '../widgets/common.dart';
import '../widgets/server_settings.dart';
import 'auth_controller.dart';
import 'google_button.dart';

/// Good enough to catch typos; the server checks it properly.
bool isEmail(String value) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]{2,}$').hasMatch(value.trim());

/// The eye in a password field.
class ShowPasswordButton extends StatelessWidget {
  const ShowPasswordButton({super.key, required this.shown, required this.onPressed});

  final bool shown;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: shown ? context.l10n.hidePassword : context.l10n.showPassword,
    onPressed: onPressed,
    icon: Icon(shown ? LucideIcons.eyeOff : LucideIcons.eye),
  );
}

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, this.register = false});

  final bool register;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  bool _busy = false;
  bool _googleBusy = false;
  bool _showPassword = false;

  Future<void> _google() async {
    setState(() => _googleBusy = true);
    try {
      await ref.read(authProvider.notifier).google(); // the router moves on once signed in
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _googleBusy = false);
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final auth = ref.read(authProvider.notifier);
    try {
      if (widget.register) {
        await auth.register(_email.text, _password.text, _name.text);
      } else {
        await auth.login(_email.text, _password.text);
      }
      // The router redirects to the map once signed in
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final register = widget.register;
    final theme = Theme.of(context);
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: Brand.gradient),
        child: SafeArea(
          bottom: false,
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                // The sheet fills the rest of the screen, however tall the phone
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      Align(
                        alignment: Alignment.centerRight,
                        child: IconButton(
                          tooltip: l10n.serverAddress,
                          color: Colors.white70,
                          onPressed: () => editServerAddress(context),
                          icon: const Icon(LucideIcons.server),
                        ),
                      ),
                      const FadeSlideIn(
                        scale: 0.7,
                        offset: Offset.zero,
                        child: Bob(child: AppLogo(size: 72)),
                      ),
                      const SizedBox(height: 14),
                      FadeSlideIn(index: 2, child: const Wordmark(size: 36, color: Colors.white)),
                      FadeSlideIn(
                        index: 3,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                          child: Text(
                            l10n.tagline,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyLarge?.copyWith(color: Colors.white70),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Expanded(
                        child: FadeSlideIn(
                          index: 4,
                          offset: const Offset(0, 0.25),
                          child: Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                            ),
                            padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                            alignment: Alignment.topCenter,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 420),
                              child: _fields(context, register),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _fields(BuildContext context, bool register) {
    final l10n = context.l10n;
    return Form(
      key: _form,
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(register ? l10n.createAccount : l10n.signIn, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 20),
            if (register) ...[
              FieldLabel(l10n.displayName),
              TextFormField(
                controller: _name,
                decoration: InputDecoration(
                  prefixIcon: const Icon(LucideIcons.user),
                  helperText: l10n.nameHelp,
                  counterText: '', // the limit is generous
                ),
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.words,
                maxLength: 80,
                autofillHints: const [AutofillHints.name],
                validator: (v) => (v ?? '').trim().isEmpty ? l10n.required : null,
              ),
              const SizedBox(height: 12),
            ],
            FieldLabel(l10n.email),
            TextFormField(
              controller: _email,
              decoration: InputDecoration(prefixIcon: const Icon(LucideIcons.mail), hintText: l10n.emailHint),
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              autocorrect: false,
              validator: (v) => isEmail(v ?? '') ? null : l10n.invalidEmail,
            ),
            const SizedBox(height: 12),
            FieldLabel(l10n.password),
            TextFormField(
              controller: _password,
              decoration: InputDecoration(
                prefixIcon: const Icon(LucideIcons.lock),
                helperText: register ? l10n.passwordTooShort : null,
                suffixIcon: ShowPasswordButton(
                  shown: _showPassword,
                  onPressed: () => setState(() => _showPassword = !_showPassword),
                ),
              ),
              obscureText: !_showPassword,
              autocorrect: false,
              enableSuggestions: false,
              autofillHints: [register ? AutofillHints.newPassword : AutofillHints.password],
              onFieldSubmitted: (_) => _submit(),
              validator: (v) => register && (v ?? '').length < 8 ? l10n.passwordTooShort : null,
            ),
            if (!register)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => context.push('/forgot-password', extra: _email.text.trim()),
                  child: Text(l10n.forgotPassword),
                ),
              ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _busy
                    ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(register ? l10n.createAccount : l10n.signIn),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              spacing: 12,
              children: [
                const Expanded(child: Divider()),
                Text(l10n.or, style: TextStyle(color: context.tokens.muted)),
                const Expanded(child: Divider()),
              ],
            ),
            const SizedBox(height: 16),
            GoogleButton(label: l10n.continueWithGoogle, busy: _googleBusy, onPressed: _busy ? null : _google),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => context.go(register ? '/login' : '/register'),
              child: Text(register ? l10n.haveAccount : l10n.noAccount),
            ),
          ],
        ),
      ),
    );
  }
}
