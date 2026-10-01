import 'package:flutter/material.dart';

import 'core/child_profile.dart';
import 'core/session.dart';
import 'features/auth/auth_screen.dart';
import 'features/auth/brand_logo.dart';
import 'features/child/child_home.dart';
import 'features/onboarding/child_setup_screen.dart';
import 'features/onboarding/role_screen.dart';
import 'features/parent/parent_home.dart';
import 'features/settings/app_update.dart';
import 'features/settings/theme_mode.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final session = Session();
  await Future.wait([session.load(), themeModeSetting.load()]);
  runApp(NigohApp(session: session));
}

class NigohApp extends StatelessWidget {
  const NigohApp({super.key, required this.session});
  final Session session;

  @override
  Widget build(BuildContext context) => SessionScope(
    session: session,
    child: ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeSetting,
      builder: (_, mode, _) => MaterialApp(
        title: 'NIGOH Family',
        debugShowCheckedModeBanner: false,
        theme: NigohTheme.light(),
        darkTheme: NigohTheme.dark(),
        themeMode: mode,
        home: const RootGate(),
      ),
    ),
  );
}

/// Picks the screen for the current state:
/// loading → splash, signed out → [AuthScreen], no role → [RoleScreen],
/// child without a local profile → [ChildSetupScreen], else the home.
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
    if (session.isChild && !profileLoaded && !profileLoading) loadProfile();

    final String state;
    final Widget screen;
    if (session.loading || (session.isChild && !profileLoaded)) {
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
    } else if (session.isParent) {
      state = 'parent';
      screen = const ParentHome();
    } else {
      state = 'child';
      screen = const ChildHome();
    }
    if (state == 'parent' || state == 'child') scheduleUpdateCheck(session);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
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
