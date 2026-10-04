// Файл: экрани бақайдгирӣ ва воридшавӣ.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../core/session.dart';
import '../../ui/github_mark.dart';
import '../../ui/widgets.dart';
import 'otp_sheets.dart';
import 'brand_logo.dart';
import '../../l10n/l10n.dart';
import '../../ui/language_picker.dart';

/// Экрани AuthScreen-ро барои экрани бақайдгирӣ ва воридшавӣ месозад.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  /// Ҳолати AuthScreen-ро барои воридшавӣ бо почта ва OAuth месозад.
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

/// Ҳолат ва рафтори AuthScreenState-ро барои навсозии интерфейс идора мекунад.
class _AuthScreenState extends State<AuthScreen> with WidgetsBindingObserver {
  final form = GlobalKey<FormState>();
  final name = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  bool register = false;
  bool hidePassword = true;
  bool busy = false;
  bool googleBusy = false;
  bool appleBusy = false;

  /// Қимати appleEnabled-ро барои экрани бақайдгирӣ ва воридшавӣ нигоҳ медорад.
  bool appleEnabled = false;

  /// Қимати _appleAttempt-ро барои экрани бақайдгирӣ ва воридшавӣ нигоҳ медорад.
  int _appleAttempt = 0;

  /// Қимати _awaitingAppleCredential-ро барои экрани бақайдгирӣ ва воридшавӣ нигоҳ медорад.
  bool _awaitingAppleCredential = false;

  /// Қимати _appleResumeTimer-ро барои экрани бақайдгирӣ ва воридшавӣ нигоҳ медорад.
  Timer? _appleResumeTimer;

  /// Қимати githubBusy-ро барои экрани бақайдгирӣ ва воридшавӣ нигоҳ медорад.
  bool githubBusy = false;

  /// Қимати githubEnabled-ро барои экрани бақайдгирӣ ва воридшавӣ нигоҳ медорад.
  bool githubEnabled = false;

  /// Воридшавӣ бо рамз ба почта дар сервер фаъол аст ё не.
  bool emailCodeEnabled = false;

  /// Қимати ҳисобшудаи anyBusy-ро аз ҳолати ҷорӣ бармегардонад.
  bool get anyBusy => busy || googleBusy || appleBusy || githubBusy;

  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  /// Пас аз frame-и аввал танзимоти воридшавии Apple ва GitHub-ро аз сервер мегирад.
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAppleConfig();
      _loadGitHubConfig();
      _loadOtpConfig();
    });
  }

  /// Аз сервер мепурсад, ки воридшавӣ бо рамз ба почта фаъол аст ё не.
  Future<void> _loadOtpConfig() async {
    try {
      final config = await SessionScope.read(context).api.otpConfig();
      if (mounted) setState(() => emailCodeEnabled = config.email);
    } catch (_) {
      if (mounted) setState(() => emailCodeEnabled = false);
    }
  }

  /// loadAppleConfig додаҳоро мехонад ва ҳолати экранро нав мекунад.
  Future<void> _loadAppleConfig() async {
    if (!mounted) return;
    try {
      final config = await SessionScope.read(context).api.appleConfig();
      if (mounted) setState(() => appleEnabled = config.enabled);
    } catch (_) {
      if (mounted) setState(() => appleEnabled = false);
    }
  }

  /// loadGitHubConfig додаҳоро мехонад ва ҳолати экранро нав мекунад.
  Future<void> _loadGitHubConfig() async {
    try {
      final config = await SessionScope.read(context).api.githubConfig();
      if (mounted) setState(() => githubEnabled = config.enabled);
    } catch (_) {
      if (mounted) setState(() => githubEnabled = false);
    }
  }

  /// Ба тағйири lifecycle-и AuthScreen ҷавоб медиҳад.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !appleBusy) return;
    _appleResumeTimer?.cancel();
    _appleResumeTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && appleBusy && _awaitingAppleCredential) {
        setState(() => appleBusy = false);
      }
    });
  }

  /// Controller ва listener-ҳои AuthScreen-ро озод мекунад.
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _appleResumeTimer?.cancel();
    name.dispose();
    email.dispose();
    password.dispose();
    super.dispose();
  }

  /// submit дархости воридшавӣ-ро ба API мефиристад ва натиҷаро коркард мекунад.
  Future<void> submit() async {
    if (anyBusy) return;
    if (!(form.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    final session = SessionScope.read(context);
    setState(() => busy = true);
    try {
      if (register) {
        await session.register(email.text, password.text, name.text);
      } else {
        final signedIn = await session.login(email.text, password.text);
        // Бо ҳимояи дуқабата парол кифоя нест: рамзи Authenticator лозим.
        if (!signedIn && mounted) {
          setState(() => busy = false);
          await showOtpSheet(context, session);
        }
      }
    } catch (e) {
      if (mounted) showMessage(context, e, error: true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  /// google экран, dialog ё танзимоти мувофиқро мекушояд.
  Future<void> google() async {
    if (anyBusy) return;
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

  /// github мантиқи зарурии экрани бақайдгирӣ ва воридшавӣро иҷро мекунад.
  Future<void> github() async {
    if (anyBusy) return;
    final session = SessionScope.read(context);
    setState(() => githubBusy = true);
    try {
      await session.signInWithGitHub();
    } on GitHubSignInCancelled {
      // Қадами дохилии экрани бақайдгирӣ ва воридшавӣ.
    } catch (e) {
      if (mounted) showMessage(context, e, error: true);
    } finally {
      if (mounted) setState(() => githubBusy = false);
    }
  }

  /// apple мантиқи зарурии экрани бақайдгирӣ ва воридшавӣро иҷро мекунад.
  Future<void> apple() async {
    if (anyBusy) return;
    final session = SessionScope.read(context);
    final attempt = ++_appleAttempt;
    setState(() {
      appleBusy = true;
      _awaitingAppleCredential = true;
    });
    try {
      await session.signInWithApple(
        onCredential: () {
          if (attempt == _appleAttempt) _awaitingAppleCredential = false;
        },
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code != AuthorizationErrorCode.canceled &&
          mounted &&
          attempt == _appleAttempt) {
        showMessage(
          context,
          tr('Воридшавӣ бо Apple нашуд. {details}', {
            'details': e.message,
          }).trim(),
          error: true,
        );
      }
    } on SignInWithAppleException {
      if (mounted && attempt == _appleAttempt) {
        showMessage(
          context,
          tr('Воридшавӣ бо Apple нашуд. {details}', {'details': ''}).trim(),
          error: true,
        );
      }
    } catch (e) {
      if (mounted && attempt == _appleAttempt) {
        showMessage(context, e, error: true);
      }
    } finally {
      if (mounted && attempt == _appleAttempt) {
        _appleResumeTimer?.cancel();
        setState(() {
          appleBusy = false;
          _awaitingAppleCredential = false;
        });
      }
    }
  }

  /// Экрани воридшавиро бо формаи почта ва тугмаҳои Google, Apple ва GitHub месозад.
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
                                onSelectionChanged: anyBusy
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
                                onPressed: anyBusy ? null : submit,
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
                              if (!register && emailCodeEnabled)
                                TextButton(
                                  key: const Key('auth.email-code'),
                                  onPressed: anyBusy
                                      ? null
                                      : () => showEmailCodeSheet(
                                          context,
                                          SessionScope.read(context),
                                          initialEmail: email.text.trim(),
                                        ),
                                  child: Text(
                                    tr('Ворид шудан бо рамз ба почта'),
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
                      onPressed: anyBusy ? null : google,
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
                  if (appleEnabled) ...[
                    const SizedBox(height: 12),
                    FadeIn(
                      index: 2,
                      child: FilledButton.icon(
                        key: const Key('auth.apple'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.black54,
                          disabledForegroundColor: Colors.white70,
                        ),
                        onPressed: anyBusy ? null : apple,
                        icon: appleBusy
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.apple, size: 24),
                        label: Text(tr('Идома бо Apple')),
                      ),
                    ),
                  ],
                  if (githubEnabled) ...[
                    const SizedBox(height: 12),
                    FadeIn(
                      index: 3,
                      child: FilledButton.icon(
                        key: const Key('auth.github'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                          backgroundColor: const Color(0xFF24292F),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: const Color(0x9924292F),
                          disabledForegroundColor: Colors.white70,
                        ),
                        onPressed: anyBusy ? null : github,
                        icon: githubBusy
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const GitHubMark(size: 20),
                        label: Text(tr('Идома бо GitHub')),
                      ),
                    ),
                  ],
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
