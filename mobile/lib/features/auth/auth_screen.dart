import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../core/session.dart';
import '../../ui/widgets.dart';
import 'brand_logo.dart';

/// Sign in / register with email, or continue with Google.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

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
          'Воридшавӣ бо Google нашуд. ${e.description ?? ''}'.trim(),
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
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
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
                    'Оилаи худро ором ва бехатар нигоҳ доред',
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
                                segments: const [
                                  ButtonSegment(
                                    value: false,
                                    label: Text('Ворид шудан'),
                                  ),
                                  ButtonSegment(
                                    value: true,
                                    label: Text('Бақайдгирӣ'),
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
                              const SizedBox(height: 18),
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
                                          decoration: const InputDecoration(
                                            labelText: 'Ном',
                                            prefixIcon: Icon(
                                              Icons.person_outline_rounded,
                                            ),
                                          ),
                                          validator: (v) =>
                                              (v ?? '').trim().isEmpty
                                              ? 'Номро нависед.'
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
                                decoration: const InputDecoration(
                                  labelText: 'Почтаи электронӣ',
                                  prefixIcon: Icon(Icons.mail_outline_rounded),
                                ),
                                validator: (v) {
                                  final value = (v ?? '').trim();
                                  if (value.isEmpty) return 'Почтаро нависед.';
                                  if (!_emailPattern.hasMatch(value)) {
                                    return 'Почтаи электронӣ нодуруст аст.';
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
                                  labelText: 'Рамз',
                                  prefixIcon: const Icon(
                                    Icons.lock_outline_rounded,
                                  ),
                                  suffixIcon: IconButton(
                                    tooltip: hidePassword
                                        ? 'Нишон додан'
                                        : 'Пинҳон кардан',
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
                                  if (value.isEmpty) return 'Рамзро нависед.';
                                  if (value.length < 8) {
                                    return 'Рамз бояд ақаллан 8 аломат бошад.';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 18),
                              FilledButton(
                                key: const Key('auth.submit'),
                                onPressed: busy || googleBusy ? null : submit,
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
                                            ? 'Сохтани аккаунт'
                                            : 'Ворид шудан',
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
                            'ё',
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
                      onPressed: busy || googleBusy ? null : google,
                      icon: googleBusy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.g_mobiledata_rounded, size: 30),
                      label: const Text('Идома бо Google'),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Агар пештар бо почта ворид мешудед, як бор аз нав бақайдгирӣ кунед.',
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
