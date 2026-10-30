import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/models.dart';
import '../api/providers.dart';
import '../auth/auth_controller.dart';
import '../auth/auth_screens.dart' show ShowPasswordButton;
import '../auth/forgot_password_screen.dart' show CodeField;
import '../reports/lost_report_detail_screen.dart' show confirm;
import '../theme.dart';
import '../widgets/animations.dart';
import '../widgets/common.dart';
import 'admin_screen.dart' show UserAvatar;

/// The user's own account: name, password, signing out (here or everywhere), deleting it.
class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  Future<void> _rename(BuildContext context, WidgetRef ref, User me) async {
    final l10n = context.l10n;
    final name = await showDialog<String>(context: context, builder: (_) => _RenameDialog(me.displayName));
    if (name == null || name == me.displayName || !context.mounted) return;
    try {
      await ref.read(apiProvider).rename(name);
      ref.invalidate(meProvider);
      if (context.mounted) _say(context, l10n.nameChanged);
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }

  Future<void> _changePassword(BuildContext context, User me) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _PasswordSheet(hasPassword: me.hasPassword),
    );
    if (changed == true && context.mounted) _say(context, context.l10n.passwordChanged);
  }

  Future<void> _verify(BuildContext context, User me) async {
    final verified = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _VerifySheet(email: me.email),
    );
    if (verified == true && context.mounted) _say(context, context.l10n.emailConfirmed);
  }

  Future<void> _signOutEverywhere(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    if (!await confirm(context, l10n.signOutEverywhereQuestion, l10n.signOutEverywhere)) return;
    try {
      await ref.read(apiProvider).signOutEverywhere();
      await ref.read(authProvider.notifier).logout(expired: true); // this session ended too
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }

  Future<void> _delete(BuildContext context, User me) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _DeleteSheet(hasPassword: me.hasPassword),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final danger = tokens.tone(Tone.lost).$2;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.account)),
      body: switch (ref.watch(meProvider)) {
        AsyncData(:final value) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            FadeSlideIn(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    spacing: 14,
                    children: [
                      UserAvatar(value.displayName, radius: 28),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(value.displayName, style: theme.textTheme.titleLarge),
                            Text(value.email, style: theme.textTheme.bodyMedium?.copyWith(color: tokens.muted)),
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: value.emailVerified
                                  ? StatusPill(l10n.emailConfirmedPill, tone: Tone.found, icon: LucideIcons.mailCheck)
                                  : StatusPill(l10n.emailNotConfirmed, tone: Tone.stray, icon: LucideIcons.mailWarning),
                            ),
                            if (value.google)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: StatusPill(
                                  l10n.signedInWithGoogle,
                                  tone: Tone.info,
                                  icon: LucideIcons.badgeCheck,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (!value.emailVerified) ...[
              const SizedBox(height: 12),
              FadeSlideIn(
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    leading: const Icon(LucideIcons.mailCheck),
                    title: Text(l10n.confirmEmail),
                    subtitle: Text(l10n.confirmEmailHelp),
                    trailing: const Icon(LucideIcons.chevronRight),
                    onTap: () => _verify(context, value),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            FadeSlideIn(
              index: 1,
              child: Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(LucideIcons.pencil),
                      title: Text(l10n.changeName),
                      subtitle: Text(l10n.nameHelp),
                      onTap: () => _rename(context, ref, value),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(LucideIcons.keyRound),
                      title: Text(value.hasPassword ? l10n.changePassword : l10n.setPassword),
                      subtitle: value.hasPassword ? null : Text(l10n.setPasswordHelp),
                      onTap: () => _changePassword(context, value),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            FadeSlideIn(
              index: 2,
              child: Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(LucideIcons.logOut),
                      title: Text(l10n.signOut),
                      onTap: () => ref.read(authProvider.notifier).logout(),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(LucideIcons.monitorSmartphone),
                      title: Text(l10n.signOutEverywhere),
                      subtitle: Text(l10n.signOutEverywhereHelp),
                      onTap: () => _signOutEverywhere(context, ref),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            FadeSlideIn(
              index: 3,
              child: Card(
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  leading: Icon(LucideIcons.trash2, color: danger),
                  title: Text(l10n.deleteAccount, style: TextStyle(color: danger)),
                  subtitle: Text(l10n.deleteAccountHelp),
                  onTap: () => _delete(context, value),
                ),
              ),
            ),
          ],
        ),
        AsyncError(:final error) => ErrorView(error: error, onRetry: () => ref.invalidate(meProvider)),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

void _say(BuildContext context, String text) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

class _RenameDialog extends StatefulWidget {
  const _RenameDialog(this.name);

  final String name;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final _name = TextEditingController(text: widget.name);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    if (_name.text.trim().isNotEmpty) Navigator.pop(context, _name.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.changeName),
      content: TextField(
        controller: _name,
        autofocus: true,
        maxLength: 80,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(helperText: l10n.nameHelp),
        onSubmitted: (_) => _save(),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
        FilledButton(onPressed: _save, child: Text(l10n.save)),
      ],
    );
  }
}

/// A password field with its eye, for the sheets below.
class _PasswordField extends StatefulWidget {
  const _PasswordField({required this.controller, required this.label, this.validator, this.newPassword = false});

  final TextEditingController controller;
  final String label;
  final FormFieldValidator<String>? validator;
  final bool newPassword;

  @override
  State<_PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<_PasswordField> {
  bool _shown = false;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      FieldLabel(widget.label),
      TextFormField(
        controller: widget.controller,
        obscureText: !_shown,
        autocorrect: false,
        enableSuggestions: false,
        autofillHints: [widget.newPassword ? AutofillHints.newPassword : AutofillHints.password],
        decoration: InputDecoration(
          prefixIcon: const Icon(LucideIcons.lock),
          helperText: widget.newPassword ? context.l10n.passwordTooShort : null,
          suffixIcon: ShowPasswordButton(shown: _shown, onPressed: () => setState(() => _shown = !_shown)),
        ),
        validator: widget.validator,
      ),
    ],
  );
}

class _PasswordSheet extends ConsumerStatefulWidget {
  const _PasswordSheet({required this.hasPassword});

  final bool hasPassword; // false: the first password of an account made with Google

  @override
  ConsumerState<_PasswordSheet> createState() => _PasswordSheetState();
}

class _PasswordSheetState extends ConsumerState<_PasswordSheet> {
  final _form = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final current = widget.hasPassword ? _current.text : null;
      final tokens = await ref.read(apiProvider).changePassword(current, _next.text);
      await ref.read(authProvider.notifier).replaceTokens(tokens);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        showError(context, e);
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _Sheet(
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 12,
          children: [
            Text(
              widget.hasPassword ? l10n.changePassword : l10n.setPassword,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(
              widget.hasPassword ? l10n.changePasswordHelp : l10n.setPasswordHelp,
              style: TextStyle(color: context.tokens.muted),
            ),
            if (widget.hasPassword)
              _PasswordField(
                controller: _current,
                label: l10n.currentPassword,
                validator: (v) => (v ?? '').isEmpty ? l10n.required : null,
              ),
            _PasswordField(
              controller: _next,
              label: l10n.newPassword,
              newPassword: true,
              validator: (v) => (v ?? '').length < 8 ? l10n.passwordTooShort : null,
            ),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: _busy
                  ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(widget.hasPassword ? l10n.changePassword : l10n.setPassword),
            ),
          ],
        ),
      ),
    );
  }
}

/// What goes, and the password to be sure it's them.
class _DeleteSheet extends ConsumerStatefulWidget {
  const _DeleteSheet({required this.hasPassword});

  final bool hasPassword; // an account made with Google has none to type

  @override
  ConsumerState<_DeleteSheet> createState() => _DeleteSheetState();
}

class _DeleteSheetState extends ConsumerState<_DeleteSheet> {
  final _form = GlobalKey<FormState>();
  final _password = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final done = context.l10n.accountDeleted;
    try {
      await ref.read(apiProvider).deleteAccount(widget.hasPassword ? _password.text : null);
      if (mounted) Navigator.pop(context);
      await ref.read(authProvider.notifier).logout(expired: true); // the account is gone
      messenger.showSnackBar(SnackBar(content: Text(done)));
    } catch (e) {
      if (mounted) {
        showError(context, e);
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _Sheet(
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 12,
          children: [
            Text(l10n.deleteAccountQuestion, style: Theme.of(context).textTheme.titleLarge),
            Note(l10n.deleteAccountWarning, tone: Tone.lost, icon: LucideIcons.triangleAlert),
            if (widget.hasPassword)
              _PasswordField(
                controller: _password,
                label: l10n.password,
                validator: (v) => (v ?? '').isEmpty ? l10n.required : null,
              ),
            FilledButton.icon(
              onPressed: _busy ? null : _delete,
              // The deep coral of the "lost" button, so the white label stays readable
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFFBE123C), foregroundColor: Colors.white),
              icon: _busy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(LucideIcons.trash2),
              label: Text(l10n.deleteAccountForGood),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sends a code (on request: one was emailed at sign-up) and checks it.
class _VerifySheet extends ConsumerStatefulWidget {
  const _VerifySheet({required this.email});

  final String email;

  @override
  ConsumerState<_VerifySheet> createState() => _VerifySheetState();
}

class _VerifySheetState extends ConsumerState<_VerifySheet> {
  final _form = GlobalKey<FormState>();
  final _code = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() => _busy = true);
    try {
      await ref.read(apiProvider).requestEmailVerification();
      if (mounted) _say(context, context.l10n.codeSent);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirm() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await ref.read(apiProvider).confirmEmailVerification(_code.text.trim());
      ref.invalidate(meProvider);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        showError(context, e);
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _Sheet(
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 12,
          children: [
            Text(l10n.confirmEmail, style: Theme.of(context).textTheme.titleLarge),
            Text(l10n.enterCodeHelp(widget.email), style: TextStyle(color: context.tokens.muted)),
            CodeField(controller: _code),
            FilledButton(
              onPressed: _busy ? null : _confirm,
              child: _busy
                  ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(l10n.confirmEmail),
            ),
            TextButton(onPressed: _busy ? null : _send, child: Text(l10n.sendNewCode)),
          ],
        ),
      ),
    );
  }
}

class _Sheet extends StatelessWidget {
  const _Sheet({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom), // above the keyboard
    child: SafeArea(
      child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 16), child: child),
    ),
  );
}
