// Файл: равзанаҳои қадами дуюми воридшавӣ — рамзи Authenticator ва воридшавӣ бо рамз ба почта.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/session.dart';
import '../../l10n/l10n.dart';
import '../../ui/widgets.dart';

/// Равзанаи рамзи Authenticator-ро нишон медиҳад; true — агар корбар ворид шуд.
Future<bool> showOtpSheet(BuildContext context, Session session) async {
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => OtpCodeSheet(session: session),
  );
  return ok ?? false;
}

/// Равзанаи «рамз ба почта»-ро нишон медиҳад; агар Authenticator лозим бошад, онро мекушояд.
Future<void> showEmailCodeSheet(
  BuildContext context,
  Session session, {
  String initialEmail = '',
}) async {
  final needsOtp = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) =>
        EmailCodeSheet(session: session, initialEmail: initialEmail),
  );
  if (needsOtp == true && context.mounted) {
    await showOtpSheet(context, session);
  }
}

/// Майдони рамзи 6-рақама бо ҳарфҳои калон ва клавиатураи рақамӣ.
class _CodeField extends StatelessWidget {
  const _CodeField({
    required this.controller,
    required this.onSubmit,
    this.allowRecovery = false,
    this.fieldKey,
  });

  final TextEditingController controller;
  final VoidCallback onSubmit;
  final bool allowRecovery;
  final Key? fieldKey;

  /// Майдонро бо форматкунии рамз месозад.
  @override
  Widget build(BuildContext context) {
    return TextField(
      key: fieldKey,
      controller: controller,
      autofocus: true,
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 26, letterSpacing: 6),
      keyboardType: allowRecovery
          ? TextInputType.visiblePassword
          : TextInputType.number,
      autofillHints: const [AutofillHints.oneTimeCode],
      maxLength: allowRecovery ? 9 : 6,
      inputFormatters: [
        FilteringTextInputFormatter.allow(
          allowRecovery ? RegExp(r'[0-9A-Za-z-]') : RegExp(r'[0-9]'),
        ),
      ],
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => onSubmit(),
      decoration: const InputDecoration(counterText: ''),
    );
  }
}

/// Равзанаи ворид кардани рамзи Authenticator пас аз парол.
class OtpCodeSheet extends StatefulWidget {
  const OtpCodeSheet({super.key, required this.session});

  final Session session;

  /// Ҳолати OtpCodeSheet-ро месозад.
  @override
  State<OtpCodeSheet> createState() => _OtpCodeSheetState();
}

/// Майдони рамз ва ҳолати фиристодан.
class _OtpCodeSheetState extends State<OtpCodeSheet> {
  final code = TextEditingController();
  bool busy = false;

  /// Майдонро озод мекунад.
  @override
  void dispose() {
    code.dispose();
    super.dispose();
  }

  /// Рамзро месанҷад; пас аз муваффақият равзанаро мебандад.
  Future<void> _verify() async {
    if (busy || code.text.trim().length < 6) return;
    setState(() => busy = true);
    try {
      await widget.session.verifyOtp(code.text);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => busy = false);
      showMessage(context, e, error: true);
      code.clear();
      // Агар чипта беэътибор шуда бошад (қулф ё мӯҳлат), равзана баста мешавад.
      if (widget.session.otpTicket == null) Navigator.pop(context, false);
    }
  }

  /// Равзанаро бо шарҳ, майдони рамз ва тугма месозад.
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          0,
          24,
          24 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(Icons.verified_user_rounded, size: 40, color: scheme.primary),
            const SizedBox(height: 10),
            Text(
              tr('Рамзи тасдиқ'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              tr(
                'Рамзи 6-рақамаро аз барномаи Authenticator ё рамзи эҳтиётиро ворид кунед.',
              ),
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            _CodeField(
              fieldKey: const ValueKey('otp-code'),
              controller: code,
              onSubmit: _verify,
              allowRecovery: true,
            ),
            const SizedBox(height: 16),
            FilledButton(
              key: const ValueKey('otp-verify'),
              onPressed: busy ? null : _verify,
              child: busy
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(tr('Тасдиқ')),
            ),
          ],
        ),
      ),
    );
  }
}

/// Равзанаи воридшавӣ бо рамз ба почта: аввал почта, баъд рамз.
class EmailCodeSheet extends StatefulWidget {
  const EmailCodeSheet({
    super.key,
    required this.session,
    this.initialEmail = '',
  });

  final Session session;
  final String initialEmail;

  /// Ҳолати EmailCodeSheet-ро месозад.
  @override
  State<EmailCodeSheet> createState() => _EmailCodeSheetState();
}

/// Почта, рамз ва қадами ҷорӣ.
class _EmailCodeSheetState extends State<EmailCodeSheet> {
  late final email = TextEditingController(text: widget.initialEmail);
  final code = TextEditingController();
  bool sent = false;
  bool busy = false;

  /// Майдонҳоро озод мекунад.
  @override
  void dispose() {
    email.dispose();
    code.dispose();
    super.dispose();
  }

  /// Рамзро ба почта мефиристад.
  Future<void> _send() async {
    final value = email.text.trim();
    if (busy || !value.contains('@')) return;
    setState(() => busy = true);
    try {
      await widget.session.requestEmailCode(value);
      if (!mounted) return;
      setState(() => sent = true);
      showMessage(
        context,
        tr('Агар ин почта сабт шуда бошад, рамз фиристода шуд.'),
      );
    } catch (e) {
      if (mounted) showMessage(context, e, error: true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  /// Рамзи почтаро месанҷад; агар Authenticator лозим бошад, true бо Navigator бармегардонад.
  Future<void> _verify() async {
    if (busy || code.text.trim().length != 6) return;
    setState(() => busy = true);
    try {
      final signedIn = await widget.session.verifyEmailCode(
        email.text,
        code.text,
      );
      if (mounted) Navigator.pop(context, !signedIn);
    } catch (e) {
      if (!mounted) return;
      setState(() => busy = false);
      code.clear();
      showMessage(context, e, error: true);
    }
  }

  /// Равзанаро бо почта ва, пас аз фиристодан, майдони рамз месозад.
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          24,
          0,
          24,
          24 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              tr('Рамз ба почта'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              tr(
                'Почтаи худро нависед — мо рамзи 6-рақама мефиристем. Он 10 дақиқа эътибор дорад.',
              ),
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const ValueKey('email-code-email'),
              controller: email,
              enabled: !sent,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: InputDecoration(
                labelText: tr('Почта'),
                prefixIcon: const Icon(Icons.mail_outline_rounded),
              ),
              onSubmitted: (_) => _send(),
            ),
            if (sent) ...[
              const SizedBox(height: 12),
              _CodeField(
                fieldKey: const ValueKey('email-code-code'),
                controller: code,
                onSubmit: _verify,
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              key: const ValueKey('email-code-submit'),
              onPressed: busy ? null : (sent ? _verify : _send),
              child: busy
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(sent ? tr('Тасдиқ') : tr('Фиристодани рамз')),
            ),
            if (sent)
              TextButton(
                key: const ValueKey('email-code-resend'),
                onPressed: busy ? null : _send,
                child: Text(tr('Рамзи нав')),
              ),
          ],
        ),
      ),
    );
  }
}
