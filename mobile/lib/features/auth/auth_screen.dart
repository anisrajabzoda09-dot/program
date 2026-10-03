// Sign-in / registration screen: email and password form plus "Continue
// with Google".

import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../core/session.dart';
import '../../ui/widgets.dart';
import 'brand_logo.dart';
import '../../l10n/l10n.dart';
import '../../ui/language_picker.dart';

/// Sign in / register with email, or continue with Google.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

/// Form state of [AuthScreen]: switches between sign-in and register and runs
/// the chosen sign-in method with progress and error messages.
class _AuthScreenState extends State<AuthScreen> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  bool register = false;
  bool hidePassword = true;
  bool busy = false;
  bool googleBusy = false;

  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    password.dispose();
    super.dispose();
  }

  /// Validates the form and signs in or registers with email and password.
  Future<void> submit() async {
    if (busy || googleBusy) return;
    if (!(form.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    final session = SessionScope.read(context);
    setState(() => busy = true);
    try {
      if (register) {
        await session.register(email.text, password.text, name.text);
      } else {
        await session.login(email.text, password.text);
      }
    } catch (e) {
      if (mounted) showMessage(context, e, error: true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  /// Runs Google sign-in; a user cancel is silent, other errors are shown.
  Future<void> google() async {
    if (busy || googleBusy) return;
    final session = SessionScope.read(context);
    setState(() => googleBusy = true);
    try {
      await session.signInWithGoogle();
    } on GoogleSignInException catch (e) {
      if (e.code != GoogleSignInExceptionCode.canceled && mounted) {
        showMessage(
          context,
          tr('Воридшавӣ бо Google нашуд. {details}', {
            'details': e.description ?? '',
          }).trim(),
          error: true,
        );
      }
    } catch (e) {
      if (mounted) showMessage(context, e, error: true);
    } finally {
      if (mounted) setState(() => googleBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        toolbarHeight: 52,
        actions: const [LanguageButton(), SizedBox(width: 8)],
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const FadeIn(child: Center(child: BrandLogo(size: 76))),
                  const SizedBox(height: 18),
                  const Text(
                    'NIGOH Family',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    tr('Оилаи худро ором ва бехатар нигоҳ доред'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 28),
                  FadeIn(
                    index: 1,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Form(
                          key: form,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SegmentedButton<bool>(
                                showSelectedIcon: false,
                                segments: [
                                  ButtonSegment(
                                    value: false,
                                    label: Text(tr('Ворид шудан')),
                                  ),
                                  ButtonSegment(
                                    value: true,
                                    label: Text(tr('Бақайдгирӣ')),
                                  ),
                                ],
                                selected: {register},
                                onSelectionChanged: busy
                                    ? null
                                    : (value) {
                                        form.currentState?.reset();
                                        setState(() => register = value.first);
                                      },
                              ),
                              const SizedBox(height: 14),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 220),
                                child: Text(
                                  register
                                      ? tr(
                                          'Аккаунти нави оила месозед. Баъд интихоб мекунед: волидайн ё фарзанд.',
                                        )
                                      : tr(
                                          'Бо почта ва рамзи аккаунти худ ворид шавед.',
                                        ),
                                  key: ValueKey(register),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 13,
                                    height: 1.4,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              AnimatedSize(
                                duration: const Duration(milliseconds: 220),
                                curve: Curves.easeOutCubic,
                                child: register
                                    ? Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 12,
                                        ),
                                        child: TextFormField(
                                          key: const Key('auth.name'),
                                          controller: name,
                                          textInputAction: TextInputAction.next,
                                          textCapitalization:
                                              TextCapitalization.words,
                                          autofillHints: const [
                                            AutofillHints.name,
                                          ],
                                          decoration: InputDecoration(
                                            labelText: tr('Ном'),
                                            prefixIcon: Icon(
                                              Icons.person_outline_rounded,
                                            ),
                                          ),
                                          validator: (v) =>
                                              (v ?? '').trim().isEmpty
                                              ? tr('Номро нависед.')
                                              : null,
                                        ),
                                      )
                                    : const SizedBox(width: double.infinity),
                              ),
                              TextFormField(
                                key: const Key('auth.email'),
                                controller: email,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                autocorrect: false,
                                autofillHints: const [AutofillHints.email],
                                decoration: InputDecoration(
                                  labelText: tr('Почтаи электронӣ'),
                                  prefixIcon: Icon(Icons.mail_outline_rounded),
                                ),
                                validator: (v) {
                                  final value = (v ?? '').trim();
                                  if (value.isEmpty) {
                                    return tr('Почтаро нависед.');
                                  }
                                  if (!_emailPattern.hasMatch(value)) {
                                    return tr('Почтаи электронӣ нодуруст аст.');
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                key: const Key('auth.password'),
                                controller: password,
                                obscureText: hidePassword,
                                textInputAction: TextInputAction.done,
                                autofillHints: [
                                  register
                                      ? AutofillHints.newPassword
                                      : AutofillHints.password,
                                ],
                                onFieldSubmitted: (_) => submit(),
                                decoration: InputDecoration(
                                  labelText: tr('Рамз'),
                                  prefixIcon: const Icon(
                                    Icons.lock_outline_rounded,
                                  ),
                                  suffixIcon: IconButton(
                                    tooltip: hidePassword
                                        ? tr('Нишон додан')
                                        : tr('Пинҳон кардан'),
                                    onPressed: () => setState(
                                      () => hidePassword = !hidePassword,
                                    ),
                                    icon: Icon(
                                      hidePassword
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                    ),
                                  ),
                                ),
                                validator: (v) {
                                  final value = v ?? '';
                                  if (value.isEmpty) {
                                    return tr('Рамзро нависед.');
                                  }
                                  if (value.length < 8) {
                                    return tr(
                                      'Рамз бояд ақаллан 8 аломат бошад.',
                                    );
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 18),
                              FilledButton(
                                key: const Key('auth.submit'),
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size.fromHeight(52),
                                  textStyle: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                onPressed: busy || googleBusy ? null : submit,
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 200),
                                  child: busy
                                      ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.4,
                                          ),
                                        )
                                      : Text(
                                          register
                                              ? tr('Сохтани аккаунт')
                                              : tr('Ворид шудан'),
                                          key: ValueKey(register),
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FadeIn(
                    index: 2,
                    child: Row(
                      children: [
                        const Expanded(child: Divider()),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            tr('ё'),
                            style: TextStyle(color: scheme.onSurfaceVariant),
                          ),
                        ),
                        const Expanded(child: Divider()),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  FadeIn(
                    index: 2,
                    child: OutlinedButton.icon(
                      key: const Key('auth.google'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                      ),
                      onPressed: busy || googleBusy ? null : google,
                      icon: googleBusy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.g_mobiledata_rounded, size: 30),
                      label: Text(tr('Идома бо Google')),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    tr(
                      'Агар пештар бо почта ворид мешудед, як бор аз нав бақайдгирӣ кунед.',
                    ),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
