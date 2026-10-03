// Файл: оғози барнома, session, notification ва экрани аввал.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/child_profile.dart';
import 'core/home_target.dart';
import 'core/notify_bridge.dart';
import 'core/session.dart';
import 'features/auth/auth_screen.dart';
import 'features/auth/brand_logo.dart';
import 'features/call/call_screen.dart';
import 'features/child/child_home.dart';
import 'features/onboarding/child_setup_screen.dart';
import 'features/onboarding/permissions_wizard.dart';
import 'features/onboarding/role_screen.dart';
import 'features/parent/parent_home.dart';
import 'features/settings/app_update.dart';
import 'features/settings/theme_mode.dart';
import 'ui/theme.dart';
import 'ui/widgets.dart';
import 'l10n/l10n.dart';

/// Қимати navigatorKey-ро барои оғози барнома, session, notification ва экрани аввал нигоҳ медорад.
final navigatorKey = GlobalKey<NavigatorState>();

/// main мантиқи зарурии оғози барнома, session, notification ва экрани аввалро иҷро мекунад.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final session = Session();
  await Future.wait([
    session.load(),
    themeModeSetting.load(),
    appLanguage.load(),
  ]);
  runApp(NigohApp(session: session));
}

/// Додаҳо ва рафтори марбут ба оғози барнома, session, notification ва экрани аввалро ифода мекунад.
class NigohApp extends StatefulWidget {
  const NigohApp({super.key, required this.session});
  final Session session;

  /// Ҳолати NigohApp-ро барои оғоз, session ва масири аввали барнома месозад.
  @override
  State<NigohApp> createState() => _NigohAppState();
}

/// Ҳолат ва рафтори NigohAppState-ро барои навсозии интерфейс идора мекунад.
class _NigohAppState extends State<NigohApp> {
  /// Тағйири забони барномаро мешунавад, то тамоми интерфейс аз нав сохта шавад.
  @override
  void initState() {
    super.initState();
    appLanguage.addListener(rebuildAll);
  }

  /// Controller ва listener-ҳои NigohApp-ро озод мекунад.
  @override
  void dispose() {
    appLanguage.removeListener(rebuildAll);
    super.dispose();
  }

  /// rebuildAll мантиқи зарурии оғози барнома, session, notification ва экрани аввалро иҷро мекунад.
  void rebuildAll() {
    /// mark дархостро ба API мефиристад ва натиҷаро коркард мекунад.
    void mark(Element element) {
      element.markNeedsBuild();
      element.visitChildren(mark);
    }

    if (mounted) (context as Element).visitChildren(mark);
  }

  /// Қимати ҳисобшудаи session-ро аз ҳолати ҷорӣ бармегардонад.
  Session get session => widget.session;

  /// Барномаро бо session, забон ва мавзӯи интихобшуда месозад.
  @override
  Widget build(BuildContext context) => SessionScope(
    session: session,
    child: ValueListenableBuilder<String>(
      valueListenable: appLanguage,
      builder: (_, _, _) => ValueListenableBuilder<ThemeMode>(
        valueListenable: themeModeSetting,
        builder: (_, mode, _) => MaterialApp(
          title: 'NIGOH Family',
          navigatorKey: navigatorKey,
          debugShowCheckedModeBanner: false,
          theme: NigohTheme.light(),
          darkTheme: NigohTheme.dark(),
          themeMode: mode,
          locale: appLanguage.materialLocale,
          supportedLocales: const [Locale('ru'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const RootGate(),
        ),
      ),
    ),
  );
}

/// Додаҳо ва рафтори марбут ба оғози барнома, session, notification ва экрани аввалро ифода мекунад.
class RootGate extends StatefulWidget {
  const RootGate({super.key});

  /// Ҳолати RootGate-ро барои оғоз, session ва масири аввали барнома месозад.
  @override
  State<RootGate> createState() => _RootGateState();
}

/// Ҳолат ва рафтори RootGateState-ро барои навсозии интерфейс идора мекунад.
class _RootGateState extends State<RootGate> {
  ChildProfile? childProfile;
  bool profileLoaded = false;
  bool profileLoading = false;
  bool updateChecked = false;

  /// Қимати wizardRole-ро барои оғози барнома, session, notification ва экрани аввал нигоҳ медорад.
  String? wizardRole;
  bool wizardDone = false;
  bool wizardLoading = false;

  /// Қимати notifyKey-ро барои оғози барнома, session, notification ва экрани аввал нигоҳ медорад.
  String? notifyKey;
  bool notifyPermissionsAsked = false;

  /// Амали огоҳиномаи оғози Android-ро мешунавад ва дархости интизорро коркард мекунад.
  @override
  void initState() {
    super.initState();
    NotifyBridge.launch.addListener(onLaunch);
    if (NotifyBridge.launch.value != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => onLaunch());
    }
  }

  /// Controller ва listener-ҳои RootGate-ро озод мекунад.
  @override
  void dispose() {
    NotifyBridge.launch.removeListener(onLaunch);
    super.dispose();
  }

  /// syncNotifications додаҳоро бо server ҳамоҳанг мекунад ва метавонад API-ро нависад.
  void syncNotifications(Session session, {required bool home}) {
    final token = session.api.token;
    final key = session.signedIn && session.role != null
        ? '$token|${session.role}'
        : null;
    if (key != notifyKey) {
      final wasStarted = notifyKey != null;
      notifyKey = key;
      if (key != null) {
        NotifyBridge.start(session.api);
      } else if (wasStarted) {
        NotifyBridge.stop();
        notifyPermissionsAsked = false;
      }
    }
    if (key != null && home && !notifyPermissionsAsked) {
      notifyPermissionsAsked = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) NotifyBridge.ensurePermissions(context);
      });
    }
  }

  /// onLaunch рӯйдодро коркард карда, ҳолати вобастаро нав мекунад.
  void onLaunch() {
    final action = NotifyBridge.launch.value;
    if (action == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || NotifyBridge.launch.value != action) return;
      NotifyBridge.launch.value = null;
      handleLaunch(action);
    });
  }

  /// handleLaunch рӯйдодро коркард карда, ҳолати вобастаро нав мекунад.
  Future<void> handleLaunch(LaunchAction action) async {
    final navigator = navigatorKey.currentState;
    if (action.kind == 'call') {
      final callId = action.callId;
      if (callId == null || navigator == null) return;
      await CallScreen.openIncoming(
        navigator,
        callId: callId,
        childId: action.childId ?? 0,
        peerName: action.peerName ?? 'NIGOH Family',
        acceptNow: action.acceptCall,
      );
      return;
    }
    homeTarget.value = HomeTarget.forEvent(action.kind, action.childId);
    if (action.kind == 'sos' && action.fullScreen && navigator != null) {
      // Қадами дохилии оғози барнома, session, notification ва экрани аввал.
      await showDialog<void>(
        context: navigator.context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(Icons.sos_rounded, color: Colors.red, size: 40),
          title: const Text('SOS'),
          content: Text(
            action.peerName == null
                ? tr('Фарзанд ёрӣ мехоҳад. Ҷойгиршавиро бинед.')
                : tr('{name} ёрӣ мехоҳад. Ҷойгиршавиро бинед.', {
                    'name': action.peerName,
                  }),
          ),
          actions: [
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(tr('Хомӯш кардан')),
            ),
          ],
        ),
      );
      await NotifyBridge.stopRinging();
    }
  }

  /// loadProfile додаҳоро мехонад ва ҳолати экранро нав мекунад.
  Future<void> loadProfile() async {
    profileLoading = true;
    ChildProfile? profile;
    try {
      profile = await ChildProfile.load();
    } catch (_) {
      profile = null; // Агар хонда нашавад, маълумот аз нав пурсида мешавад.
    }
    if (!mounted) return;
    setState(() {
      childProfile = profile;
      profileLoaded = true;
      profileLoading = false;
    });
  }

  /// loadWizardFlag додаҳоро мехонад ва ҳолати экранро нав мекунад.
  Future<void> loadWizardFlag(String role) async {
    wizardRole = role;
    wizardLoading = true;
    var done = false;
    try {
      done = await PermissionsWizard.isDone(role);
    } catch (_) {
      done = false; // Агар flag хонда нашавад, роҳнамо аз нав нишон дода мешавад.
    }
    if (!mounted || wizardRole != role) return;
    setState(() {
      wizardDone = done;
      wizardLoading = false;
    });
  }

  /// onWizardDone рӯйдодро коркард карда, ҳолати вобастаро нав мекунад.
  void onWizardDone() {
    // Огоҳиномаи воридшударо дар RootGate ба амали мувофиқ равона мекунад.
    notifyPermissionsAsked = true;
    setState(() => wizardDone = true);
  }

  /// scheduleUpdateCheck раванди лозимро оғоз ва захираҳои вобастаро фаъол мекунад.
  void scheduleUpdateCheck(Session session) {
    if (updateChecked) return;
    updateChecked = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) AppUpdate.check(context, session.api, silent: true);
    });
  }

  /// Аз рӯи session экрани воридшавӣ, интихоби нақш ё саҳифаи асосиро нишон медиҳад.
  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    if (!session.isChild && profileLoaded) {
      // Қадами дохилии оғози барнома, session, notification ва экрани аввал.
      profileLoaded = false;
      childProfile = null;
    }
    final childHere = session.isChild;
    if (childHere && !profileLoaded && !profileLoading) loadProfile();
    final role = session.signedIn ? session.role : null;
    if (role != wizardRole) {
      if (role == null) {
        wizardRole = null;
        wizardDone = false;
        wizardLoading = false;
      } else {
        loadWizardFlag(role);
      }
    }

    final String state;
    final Widget screen;
    if (session.loading ||
        (childHere && !profileLoaded) ||
        (role != null && wizardLoading)) {
      state = 'loading';
      screen = const _Splash();
    } else if (!session.signedIn) {
      state = 'auth';
      screen = const AuthScreen();
    } else if (session.role == null) {
      state = 'role';
      screen = const RoleScreen();
    } else if (session.isChild && childProfile == null) {
      state = 'child-setup';
      screen = ChildSetupScreen(
        onDone: (profile) => setState(() => childProfile = profile),
      );
    } else if (!wizardDone) {
      state = 'wizard-$role';
      screen = PermissionsWizard(
        childMode: session.isChild,
        onDone: onWizardDone,
      );
    } else if (session.isParent) {
      state = 'parent';
      screen = const ParentHome();
    } else {
      state = 'child';
      screen = const ChildHome();
    }
    if (state == 'parent' || state == 'child') scheduleUpdateCheck(session);
    syncNotifications(session, home: state == 'parent' || state == 'child');

    // Animation бо назардошти танзими кам кардани ҳаракат иҷро мешавад.
    return AnimatedSwitcher(
      duration: reducedMotion(context)
          ? Duration.zero
          : const Duration(milliseconds: 280),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: KeyedSubtree(key: ValueKey(state), child: screen),
    );
  }
}

/// Додаҳо ва рафтори марбут ба оғози барнома, session, notification ва экрани аввалро ифода мекунад.
class _Splash extends StatelessWidget {
  const _Splash();

  /// Ҳангоми омодасозии session экрани интизории NIGOH-ро нишон медиҳад.
  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          BrandLogo(size: 84),
          SizedBox(height: 22),
          SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          ),
        ],
      ),
    ),
  );
}
