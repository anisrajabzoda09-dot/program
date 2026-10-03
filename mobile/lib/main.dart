import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/child_profile.dart';
import 'core/home_target.dart';
import 'core/notify_bridge.dart';
import 'core/platform.dart';
import 'core/session.dart';
import 'features/auth/auth_screen.dart';
import 'features/auth/brand_logo.dart';
import 'features/call/call_screen.dart';
import 'features/child/child_home.dart';
import 'features/desktop/desktop_notifications.dart';
import 'features/onboarding/child_setup_screen.dart';
import 'features/onboarding/permissions_wizard.dart';
import 'features/onboarding/role_screen.dart';
import 'features/parent/parent_home.dart';
import 'features/settings/app_update.dart';
import 'features/settings/theme_mode.dart';
import 'ui/theme.dart';
import 'ui/widgets.dart';
import 'l10n/l10n.dart';

/// App-wide navigator, used to open screens from notifications.
final navigatorKey = GlobalKey<NavigatorState>();

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

class NigohApp extends StatefulWidget {
  const NigohApp({super.key, required this.session});
  final Session session;

  @override
  State<NigohApp> createState() => _NigohAppState();
}

class _NigohAppState extends State<NigohApp> {
  @override
  void initState() {
    super.initState();
    appLanguage.addListener(rebuildAll);
  }

  @override
  void dispose() {
    appLanguage.removeListener(rebuildAll);
    super.dispose();
  }

  /// Texts come from tr() inside build methods, so a language switch must
  /// rebuild every element — including routes pushed above the home (e.g. the
  /// open Settings screen) — while keeping their state.
  void rebuildAll() {
    void mark(Element element) {
      element.markNeedsBuild();
      element.visitChildren(mark);
    }

    if (mounted) (context as Element).visitChildren(mark);
  }

  Session get session => widget.session;

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

/// Picks the screen for the current state:
/// loading → splash, signed out → [AuthScreen], no role → [RoleScreen],
/// child without a local profile → [ChildSetupScreen], permissions not set
/// up yet for this role → [PermissionsWizard] (once), else the home.
class RootGate extends StatefulWidget {
  const RootGate({super.key});

  @override
  State<RootGate> createState() => _RootGateState();
}

class _RootGateState extends State<RootGate> {
  ChildProfile? childProfile;
  bool profileLoaded = false;
  bool profileLoading = false;
  bool updateChecked = false;

  /// Role whose `nigoh.wizard_done.<role>` flag is loaded / loading.
  String? wizardRole;
  bool wizardDone = false;
  bool wizardLoading = false;

  /// Token and role (as `token|role`) the notification service was started for.
  String? notifyKey;
  bool notifyPermissionsAsked = false;

  @override
  void initState() {
    super.initState();
    NotifyBridge.launch.addListener(onLaunch);
    if (NotifyBridge.launch.value != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => onLaunch());
    }
  }

  @override
  void dispose() {
    NotifyBridge.launch.removeListener(onLaunch);
    if (isDesktop) DesktopNotifications.stop();
    super.dispose();
  }

  /// Starts the notification service when signed in with a role, stops it on
  /// sign-out, and asks for notification permissions once.
  void syncNotifications(Session session, {required bool home}) {
    if (isDesktop) return syncDesktopNotifications(session);
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

  /// Desktop (parent only): a Dart long-poll of the events shows banners,
  /// the SOS alarm and incoming calls while the app is open.
  void syncDesktopNotifications(Session session) {
    final key = session.signedIn && session.isParent
        ? '${session.api.token}|parent'
        : null;
    if (key == notifyKey) return;
    notifyKey = key;
    if (key != null) {
      DesktopNotifications.start(session.api, navigatorKey);
    } else {
      DesktopNotifications.stop();
    }
  }

  /// Routes a tap on a notification: calls open [CallScreen], everything else
  /// sets [homeTarget] for the parent/child home to pick up.
  void onLaunch() {
    final action = NotifyBridge.launch.value;
    if (action == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || NotifyBridge.launch.value != action) return;
      NotifyBridge.launch.value = null;
      handleLaunch(action);
    });
  }

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
      // Opened over the lock screen while the alarm is still ringing.
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

  Future<void> loadProfile() async {
    profileLoading = true;
    ChildProfile? profile;
    try {
      profile = await ChildProfile.load();
    } catch (_) {
      profile = null; // Unreadable: ask again.
    }
    if (!mounted) return;
    setState(() {
      childProfile = profile;
      profileLoaded = true;
      profileLoading = false;
    });
  }

  Future<void> loadWizardFlag(String role) async {
    wizardRole = role;
    wizardLoading = true;
    var done = false;
    try {
      done = await PermissionsWizard.isDone(role);
    } catch (_) {
      done = false; // Unreadable flag: show the wizard again.
    }
    if (!mounted || wizardRole != role) return;
    setState(() {
      wizardDone = done;
      wizardLoading = false;
    });
  }

  void onWizardDone() {
    // The wizard covered notifications; do not ask again right away.
    notifyPermissionsAsked = true;
    setState(() => wizardDone = true);
  }

  void scheduleUpdateCheck(Session session) {
    if (updateChecked) return;
    updateChecked = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) AppUpdate.check(context, session.api, silent: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    if (!session.isChild && profileLoaded) {
      // Signed out or switched role: re-read next time.
      profileLoaded = false;
      childProfile = null;
    }
    // The desktop app is parent-only: a stored 'child' role means the role
    // still has to be chosen there.
    final desktop = isDesktop;
    final childHere = session.isChild && !desktop;
    if (childHere && !profileLoaded && !profileLoading) loadProfile();
    final role = session.signedIn ? session.role : null;
    if (desktop) {
      // No Android permissions to set up on a computer.
      wizardRole = role;
      wizardDone = true;
      wizardLoading = false;
    } else if (role != wizardRole) {
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
    } else if (session.role == null || (desktop && !session.isParent)) {
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

    // Short fade-through between the gate's screens (splash → auth → home).
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

class _Splash extends StatelessWidget {
  const _Splash();

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
