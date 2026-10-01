import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:latlong2/latlong.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/bundle_manager.dart';
import 'core/nigoh_api.dart';
import 'core/user_journey_logic.dart';
import 'pages/access_center_page.dart';
import 'ui/nigoh_design.dart';

const databaseUrl =
    'https://nigoh-family-default-rtdb.europe-west1.firebasedatabase.app';
// This is the public OAuth Web Client ID from google-services.json.  It is
// required by Google Sign-In on Android to mint an ID token for FirebaseAuth.
// It can be overridden at build time without changing source code.
const googleServerClientId = String.fromEnvironment(
  'NIGOH_GOOGLE_WEB_CLIENT_ID',
  defaultValue: '708817646656-mdjfklgfsfaq83h9q5fa0j1mr74avo03.apps.googleusercontent.com',
);
const updateServerBaseUrl = String.fromEnvironment(
  'NIGOH_UPDATE_BASE_URL',
  defaultValue: 'https://nigohfamily.qobus.tj',
);
const updateServerFallbackUrls = <String>[
  'https://nigohfamily.qobus.tj',
  'http://192.168.28.192:8000',
  'http://192.168.31.192:8000',
];

final rootNavigatorKey = GlobalKey<NavigatorState>();
final rootScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
// This notifier is kept at the app level so the theme changes immediately
// without rebuilding or restarting the authenticated session.
final darkMode = ValueNotifier<bool>(false);
SharedPreferences? _appearancePrefs;

const cyberBackground = Color(0xFF070D18);
const cyberSurface = Color(0xFF111C30);
const cyberSurfaceAlt = Color(0xFF162238);
const cyberBorder = Color(0xFF223354);
const cyberCyan = Color(0xFF00E5FF);
const cyberBlue = Color(0xFF1890FF);
const cyberMuted = Color(0xFF8D99AE);
const cyberRed = Color(0xFFE63946);
const cyberGreen = Color(0xFF06D6A0);

ThemeData cyberTheme() => ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  scaffoldBackgroundColor: cyberBackground,
  textTheme: Typography.whiteMountainView.apply(
    bodyColor: Colors.white,
    displayColor: Colors.white,
  ),
  colorScheme: const ColorScheme.dark(
    primary: cyberCyan,
    onPrimary: cyberBackground,
    secondary: cyberBlue,
    onSecondary: Colors.white,
    surface: cyberSurface,
    onSurface: Colors.white,
    error: cyberRed,
  ),
  dividerColor: cyberBorder,
  cardTheme: CardThemeData(
    color: cyberSurface,
    elevation: 0,
    margin: EdgeInsets.zero,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(16)),
      side: BorderSide(color: cyberBorder),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: cyberSurfaceAlt,
    hintStyle: const TextStyle(color: cyberMuted),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(14)),
      borderSide: BorderSide(color: cyberBorder),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(14)),
      borderSide: BorderSide(color: cyberBorder),
    ),
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: cyberBackground,
    foregroundColor: Colors.white,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
  ),
  navigationBarTheme: const NavigationBarThemeData(
    backgroundColor: cyberSurface,
    indicatorColor: Color(0x3322DFFF),
    labelTextStyle: WidgetStatePropertyAll(
      TextStyle(fontSize: 11, color: Colors.white70),
    ),
  ),
);

ThemeData lightTheme() => ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,
  scaffoldBackgroundColor: Colors.white,
  textTheme: Typography.blackMountainView.apply(
    bodyColor: const Color(0xFF374151),
    displayColor: const Color(0xFF111827),
  ),
  colorScheme: const ColorScheme.light(
    primary: Color(0xFF2563EB),
    onPrimary: Colors.white,
    secondary: Color(0xFF2563EB),
    onSecondary: Colors.white,
    surface: Colors.white,
    onSurface: Color(0xFF111827),
    error: Color(0xFFDC2626),
    outline: Color(0xFFD1D5DB),
    outlineVariant: Color(0xFFE5E7EB),
  ),
  dividerColor: const Color(0xFFE5E7EB),
  cardTheme: CardThemeData(
    color: Colors.white,
    elevation: 0,
    margin: EdgeInsets.zero,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(14)),
      side: BorderSide(color: Color(0xFFE5E7EB)),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    hintStyle: const TextStyle(color: Color(0xFF6B7280)),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
      borderSide: BorderSide(color: Color(0xFFD1D5DB)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
      borderSide: BorderSide(color: Color(0xFFD1D5DB)),
    ),
    focusedBorder: const OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
      borderSide: BorderSide(color: Color(0xFF2563EB), width: 1.5),
    ),
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.white,
    foregroundColor: Color(0xFF0F172A),
    surfaceTintColor: Colors.transparent,
    elevation: 0,
  ),
  navigationBarTheme: const NavigationBarThemeData(
    backgroundColor: Colors.white,
    indicatorColor: Color(0xFFEFF6FF),
    labelTextStyle: WidgetStatePropertyAll(
      TextStyle(fontSize: 11, color: Color(0xFF374151)),
    ),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: const Color(0xFF2563EB),
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
  ),
);

Future<void> loadAppearancePreferences() async {
  _appearancePrefs = await SharedPreferences.getInstance();
  if (_appearancePrefs?.getBool('minimal_white_v1') != true) {
    darkMode.value = false;
    await _appearancePrefs?.setBool('dark_mode', false);
    await _appearancePrefs?.setBool('minimal_white_v1', true);
    return;
  }
  darkMode.value =
      _appearancePrefs?.getBool('dark_mode') ??
      _appearancePrefs?.getBool('blue_mode') ??
      false;
}

Future<void> setDarkMode(bool enabled) async {
  darkMode.value = enabled;
  await _appearancePrefs?.setBool('dark_mode', enabled);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await GoogleSignIn.instance.initialize(serverClientId: googleServerClientId);
  await loadAppearancePreferences();
  await dynamicConfig.loadLocal();
  runApp(const NigohApp());
  unawaited(syncDynamicBundleInBackground());
}

Future<void> syncDynamicBundleInBackground() async {
  try {
    final info = await PackageInfo.fromPlatform();
    final nativeCode = int.tryParse(info.buildNumber) ?? 0;
    await dynamicConfig.sync(
      endpointBaseUrl: updateServerBaseUrl,
      fallbackBaseUrls: updateServerFallbackUrls,
      nativeVersionCode: nativeCode,
    );
  } catch (_) {
    // Cached configuration remains active when the network is unavailable.
  }
}

DatabaseReference db(String path) => FirebaseDatabase.instanceFor(
  app: Firebase.app(),
  databaseURL: databaseUrl,
).ref(path);

Future<Map<String, dynamic>> loadAndroidRelease(MethodChannel channel) async {
  Map<String, dynamic> normalizeRelease(Map<Object?, Object?> raw) {
    final value = Map<String, dynamic>.from(raw);
    final rawCode = value['versionCode'] ?? value['version_code'];
    final code = rawCode is num
        ? rawCode.toInt()
        : int.tryParse('$rawCode') ?? 0;
    return {
      ...value,
      'versionCode': code,
      'versionName': (value['versionName'] ?? value['version'] ?? '0.0.0')
          .toString(),
      'downloadUrl': (value['downloadUrl'] ?? value['download_url'] ?? '')
          .toString(),
      'notes': (value['notes'] ?? value['release_notes'] ?? '').toString(),
    };
  }

  final candidates = <String>[
    updateServerBaseUrl,
    ...updateServerFallbackUrls.where((url) => url != updateServerBaseUrl),
  ];
  for (final baseUrl in candidates) {
    try {
      final result = await channel.invokeMapMethod<String, dynamic>(
        'checkForUpdate',
        {'baseUrl': baseUrl},
      );
      if (result != null && result.isNotEmpty) {
        return Map<String, dynamic>.from(result);
      }
    } catch (_) {
      // Try the next known local server before the Firebase fallback.
    }
  }
  // Firebase remains a fallback while the local/production website is offline.
  final snapshot = await db('releases/android').get();
  if (!snapshot.exists || snapshot.value is! Map) return <String, dynamic>{};
  return normalizeRelease(Map<Object?, Object?>.from(snapshot.value as Map));
}

String encodedAppKey(String packageName) =>
    UserJourneyLogic.encodedAppKey(packageName);

class NigohApp extends StatelessWidget {
  const NigohApp({super.key});
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: dynamicConfig,
    builder: (_, _) => ValueListenableBuilder<bool>(
      valueListenable: darkMode,
      builder: (_, dark, _) => MaterialApp(
        navigatorKey: rootNavigatorKey,
        scaffoldMessengerKey: rootScaffoldMessengerKey,
        debugShowCheckedModeBanner: false,
        title: dynamicConfig.text('app_name', fallback: 'NIGOH Family'),
        theme: lightTheme(),
        darkTheme: cyberTheme(),
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        home: const AuthGate(),
        builder: (_, child) => child ?? const SizedBox.shrink(),
      ),
    ),
  );
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});
  @override
  Widget build(BuildContext context) => StreamBuilder<User?>(
    stream: FirebaseAuth.instance.authStateChanges(),
    builder: (_, auth) {
      if (auth.connectionState == ConnectionState.waiting) {
        return const LoadingPage();
      }
      return auth.data == null
          ? const AuthPage()
          : ProfileGate(user: auth.data!);
    },
  );
}

class NoPageTransitionsBuilder extends PageTransitionsBuilder {
  const NoPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => child;
}

class LoadingPage extends StatelessWidget {
  const LoadingPage({super.key});
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 56});
  final double size;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(borderRadius: BorderRadius.circular(size * .3)),
    child: Image.asset(
      'assets/branding/nigoh_family_icon.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
    ),
  );
}

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});
  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final email = TextEditingController(),
      password = TextEditingController(),
      name = TextEditingController();
  bool register = false, loading = false, obscure = true;

  void message(Object text) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$text')));
    }
  }

  Future<void> submit() async {
    setState(() => loading = true);
    try {
      if (register) {
        final value = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(
              email: email.text.trim(),
              password: password.text,
            );
        await value.user?.updateDisplayName(name.text.trim());
      } else {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email.text.trim(),
          password: password.text,
        );
      }
    } on FirebaseAuthException catch (error) {
      message(error.message ?? 'Воридшавӣ анҷом нашуд');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> google() async {
    setState(() => loading = true);
    try {
      // Clear the previous Google account selection so testing two accounts
      // on the same phone opens the account chooser instead of reusing the
      // child account silently.
      await GoogleSignIn.instance.signOut();
      final account = await GoogleSignIn.instance.authenticate();
      final token = account.authentication.idToken;
      if (token == null) throw Exception('Google ID token дастрас нест');
      await FirebaseAuth.instance.signInWithCredential(
        GoogleAuthProvider.credential(idToken: token),
      );
    } catch (error) {
      message('Google Login анҷом нашуд: $error');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> demoLogin() async {
    setState(() => loading = true);
    try {
      // Anonymous auth keeps the demo path isolated from real family accounts.
      // The Firebase project must have Anonymous provider enabled.
      await FirebaseAuth.instance.signInAnonymously();
    } on FirebaseAuthException catch (error) {
      message(
        error.code == 'operation-not-allowed'
            ? 'Ҳолати санҷишӣ дар Firebase фаъол нест. Дар Authentication > Sign-in method Anonymous-ро фаъол кунед.'
            : (error.message ?? 'Ҳолати санҷишӣ оғоз нашуд'),
      );
    } catch (error) {
      message('Ҳолати санҷишӣ оғоз нашуд: $error');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hero = Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const BrandMark(size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'NIGOH Family',
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Муҳофизати оила дар як ҷо',
                      style: TextStyle(
                        color: scheme.onSurface.withValues(alpha: .65),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Назорат бо меҳр,\nоромӣ барои оила.',
            style: TextStyle(
              color: scheme.onSurface,
              fontSize: 30,
              height: 1.16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Ҷойгиршавӣ, вақти экран, қоидаҳои барнома ва паёмҳои оилавӣ — бо забони тоҷикӣ.',
            style: TextStyle(
              color: scheme.onSurface.withValues(alpha: .65),
              height: 1.45,
            ),
          ),
        ],
      ),
    );

    final form = Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              register ? 'Сохтани аккаунт' : 'Хуш омадед',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              register
                  ? 'Барои оғози муҳофизати оила маълумотро пур кунед.'
                  : 'Ба панели бехатари оилаи худ ворид шавед.',
              style: TextStyle(color: scheme.onSurface.withValues(alpha: .62)),
            ),
            const SizedBox(height: 22),
            if (register) ...[
              TextField(
                controller: name,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Ному насаб',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
              ),
              const SizedBox(height: 13),
            ],
            TextField(
              controller: email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Почтаи электронӣ',
                prefixIcon: Icon(Icons.alternate_email_rounded),
              ),
            ),
            const SizedBox(height: 13),
            TextField(
              controller: password,
              obscureText: obscure,
              onSubmitted: (_) {
                if (!loading) unawaited(submit());
              },
              decoration: InputDecoration(
                labelText: 'Парол',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  tooltip: obscure ? 'Нишон додан' : 'Пинҳон кардан',
                  onPressed: () => setState(() => obscure = !obscure),
                  icon: Icon(
                    obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
            ),
            if (!register)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () async {
                    if (email.text.trim().isEmpty) {
                      return message('Аввал почтаро нависед');
                    }
                    try {
                      await FirebaseAuth.instance.sendPasswordResetEmail(
                        email: email.text.trim(),
                      );
                      message('Пайванди барқароркунӣ фиристода шуд');
                    } on FirebaseAuthException catch (error) {
                      message(error.message ?? 'Почта фиристода нашуд');
                    }
                  },
                  child: const Text('Паролро фаромӯш кардед?'),
                ),
              )
            else
              const SizedBox(height: 17),
            FilledButton.icon(
              onPressed: loading ? null : submit,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: loading
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(
                      register
                          ? Icons.person_add_alt_1_rounded
                          : Icons.login_rounded,
                    ),
              label: Text(register ? 'Сохтани аккаунт' : 'Ворид шудан'),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 15),
              child: Row(
                children: [
                  Expanded(child: Divider()),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text('ё'),
                  ),
                  Expanded(child: Divider()),
                ],
              ),
            ),
            OutlinedButton.icon(
              onPressed: loading ? null : google,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Text(
                  'G',
                  style: TextStyle(
                    color: Color(0xFF4285F4),
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              label: const Text('Воридшавӣ бо Google'),
            ),
            const SizedBox(height: 7),
            TextButton.icon(
              onPressed: loading ? null : demoLogin,
              icon: const Icon(Icons.science_outlined),
              label: const Text('Воридшавии санҷишӣ'),
            ),
            TextButton(
              onPressed: loading
                  ? null
                  : () => setState(() => register = !register),
              child: Text(
                register
                    ? 'Аккаунт доред? Ворид шавед'
                    : 'Аккаунт надоред? Бақайдгирӣ',
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.shield_outlined, size: 15, color: scheme.primary),
                const SizedBox(width: 6),
                Text(
                  'Маълумоти оила бо ҳифзи NIGOH нигоҳ дошта мешавад',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: scheme.onSurface.withValues(alpha: .54),
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    return Scaffold(
      body: ColoredBox(
        color: scheme.surface,
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 980),
                  child: constraints.maxWidth >= 820
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(child: hero),
                            const SizedBox(width: 24),
                            SizedBox(width: 430, child: form),
                          ],
                        )
                      : Column(
                          children: [
                            hero,
                            const SizedBox(height: 18),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 480),
                              child: form,
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
}

class ProfileGate extends StatelessWidget {
  const ProfileGate({super.key, required this.user});
  final User user;
  @override
  Widget build(BuildContext context) => StreamBuilder<DatabaseEvent>(
    stream: db('profiles/${user.uid}').onValue,
    builder: (_, snapshot) {
      if (!snapshot.hasData) return const LoadingPage();
      final raw = snapshot.data!.snapshot.value;
      return raw is Map
          ? ParentPinGate(user: user, profile: Map<String, dynamic>.from(raw))
          : OnboardingPage(user: user);
    },
  );
}

class ParentPinGate extends StatefulWidget {
  const ParentPinGate({super.key, required this.user, required this.profile});
  final User user;
  final Map<String, dynamic> profile;

  @override
  State<ParentPinGate> createState() => _ParentPinGateState();
}

class _ParentPinGateState extends State<ParentPinGate>
    with WidgetsBindingObserver {
  static const deviceChannel = MethodChannel('tj.nigoh/device_control');
  final pin = TextEditingController();
  bool checkingPin = true;
  bool hasPin = false;
  bool unlocked = false;
  bool invalid = false;
  DateTime? backgroundedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    loadPinStatus();
  }

  Future<void> loadPinStatus() async {
    try {
      final enabled =
          await deviceChannel.invokeMethod<bool>('getLocalPinStatus') ?? false;
      if (mounted) {
        setState(() {
          hasPin = enabled;
          checkingPin = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => checkingPin = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    pin.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      backgroundedAt ??= DateTime.now();
    } else if (state == AppLifecycleState.resumed && backgroundedAt != null) {
      final shouldLock =
          DateTime.now().difference(backgroundedAt!).inSeconds >= 30;
      backgroundedAt = null;
      if (shouldLock && hasPin) {
        setState(() {
          unlocked = false;
          pin.clear();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (checkingPin) return const LoadingPage();
    if (!hasPin || unlocked) {
      return HomeShell(user: widget.user, profile: widget.profile);
    }
    Future<void> unlock() async {
      final value = pin.text.trim();
      final ok =
          RegExp(r'^\d{4}$').hasMatch(value) &&
          (await deviceChannel.invokeMethod<bool>('verifyLocalPin', {
                'pin': value,
              }) ??
              false);
      if (!mounted) return;
      setState(() {
        unlocked = ok;
        invalid = !ok;
      });
    }

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(26),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const BrandMark(size: 76),
                      const SizedBox(height: 18),
                      const Text(
                        'NIGOH Family қулф аст',
                        style: TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 7),
                      const Text(
                        'Рамзи 4-рақама маълумоти оиларо муҳофизат мекунад.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: pin,
                        autofocus: true,
                        obscureText: true,
                        keyboardType: TextInputType.number,
                        maxLength: 4,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 28,
                          letterSpacing: 12,
                          fontWeight: FontWeight.w900,
                        ),
                        decoration: InputDecoration(
                          counterText: '',
                          labelText: 'Рамз',
                          errorText: invalid ? 'Рамз нодуруст аст' : null,
                        ),
                        onSubmitted: (_) => unlock(),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: unlock,
                          icon: const Icon(Icons.lock_open_rounded),
                          label: const Text('Кушодан'),
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
}

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key, required this.user});
  final User user;
  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage>
    with WidgetsBindingObserver {
  static const deviceChannel = MethodChannel('tj.nigoh/device_control');
  final pin = TextEditingController();
  final confirmPin = TextEditingController();
  int step = 0;
  int protectionWizardStage = 0;
  String role = '', gender = '';
  bool location = false,
      notifications = false,
      camera = false,
      usageAccess = false,
      overlayAccess = false,
      appControl = false,
      requestingPermissions = false,
      saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    pin.addListener(refreshPinState);
    confirmPin.addListener(refreshPinState);
    refreshAppControl();
  }

  void refreshPinState() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    pin.dispose();
    confirmPin.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      refreshAppControl();
      if (protectionWizardStage > 0) {
        Future<void>.delayed(
          const Duration(milliseconds: 450),
          advanceProtectionWizard,
        );
      }
    }
  }

  Future<void> refreshAppControl() async {
    try {
      final raw = await deviceChannel.invokeMethod<Map<Object?, Object?>>(
        'getProtectionStatus',
      );
      final usage = raw?['usage'] == true;
      final overlay = raw?['overlay'] == true;
      final accessibility = raw?['accessibility'] == true;
      if (mounted) {
        setState(() {
          usageAccess = usage;
          overlayAccess = overlay;
          appControl = usage && overlay && accessibility;
        });
      }
    } catch (_) {}
  }

  Future<void> requestAppControl() async {
    if (!mounted) return;
    final proceed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.admin_panel_settings_rounded, size: 42),
        title: const Text('Қадами 1 аз 4'),
        content: const Text(
          'Дар App info менюи ⋮-ро кушоед ва «Allow restricted settings»-ро пахш кунед. Баъд ба NIGOH баргардед — Usage access, Display over apps ва Accessibility пайдарпай кушода мешаванд.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Бекор кардан'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Кушодани App info'),
          ),
        ],
      ),
    );
    if (proceed != true) return;
    protectionWizardStage = 1;
    await deviceChannel.invokeMethod<void>('openAppDetails');
  }

  Future<void> advanceProtectionWizard() async {
    if (!mounted) return;
    if (protectionWizardStage == 1) {
      protectionWizardStage = 2;
      await deviceChannel.invokeMethod<void>('openUsageSettings');
      return;
    }
    await refreshAppControl();
    if (!mounted) return;
    if (protectionWizardStage == 2) {
      if (!usageAccess) {
        protectionWizardStage = 0;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Usage access фаъол нашуд. Дар App info аввал Allow restricted settings-ро иҷозат диҳед ва дубора кӯшиш кунед.',
            ),
          ),
        );
        return;
      }
      protectionWizardStage = 3;
      await deviceChannel.invokeMethod<void>('openOverlaySettings');
      return;
    }
    if (protectionWizardStage == 3) {
      protectionWizardStage = 4;
      await deviceChannel.invokeMethod<void>('openAccessibilitySettings');
      return;
    }
    if (protectionWizardStage == 4) {
      protectionWizardStage = 0;
      await refreshAppControl();
    }
  }

  Future<void> permissions() async {
    if (requestingPermissions) return;
    setState(() => requestingPermissions = true);
    var loc = await Geolocator.checkPermission();
    if (loc == LocationPermission.denied) {
      loc = await Geolocator.requestPermission();
    }
    if (role == 'child' && loc == LocationPermission.whileInUse) {
      await ph.Permission.locationAlways.request();
      loc = await Geolocator.checkPermission();
    }
    final cameraStatus = await ph.Permission.camera.request();
    final note = await ph.Permission.notification.request();
    if (mounted) {
      setState(() {
        location =
            loc == LocationPermission.always ||
            loc == LocationPermission.whileInUse;
        notifications = note.isGranted;
        camera = cameraStatus.isGranted;
        requestingPermissions = false;
      });
    }
    if (role == 'child' && !appControl && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            'Иҷозати бастани барномаҳо ҳоло фаъол нест. Барнома идома меёбад; онро баъдтар аз «Муҳофизат» фаъол кунед.',
          ),
        ),
      );
    }
  }

  Future<void> finish() async {
    setState(() => saving = true);
    final uid = widget.user.uid;
    final alreadyHasPin =
        await deviceChannel.invokeMethod<bool>('getLocalPinStatus') ?? false;
    final pinResult = alreadyHasPin
        ? <String, dynamic>{'ok': true}
        : await deviceChannel.invokeMapMethod<String, dynamic>('setLocalPin', {
            'currentPin': '',
            'newPin': pin.text.trim(),
          });
    if (pinResult?['ok'] != true) {
      if (mounted) {
        setState(() => saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PIN нигоҳ дошта нашуд. Дубора кӯшиш кунед.'),
          ),
        );
      }
      return;
    }
    final profile = <String, Object?>{
      'displayName': widget.user.displayName?.isNotEmpty == true
          ? widget.user.displayName!
          : (widget.user.email?.split('@').first ?? 'Истифодабаранда'),
      'email': widget.user.email ?? '',
      'role': role,
      'gender': gender,
      'createdAt': ServerValue.timestamp,
      'online': true,
    };
    final updates = <String, Object?>{'profiles/$uid': profile};
    if (role == 'parent') {
      final family = db('families').push().key!;
      profile['familyId'] = family;
      updates['profiles/$uid'] = profile;
      updates['families/$family'] = {
        'parentUid': uid,
        'createdAt': ServerValue.timestamp,
      };
      updates['userFamilies/$uid/$family'] = true;
    }
    await db('').update(updates);
    if (mounted) setState(() => saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final content = switch (step) {
      0 => ChoicePage(
        title: 'Шумо кистед?',
        subtitle: 'Ҷинси худро интихоб кунед.',
        value: gender,
        items: const [
          Choice('male', 'Мард', Icons.male),
          Choice('female', 'Зан', Icons.female),
        ],
        changed: (v) => setState(() => gender = v),
      ),
      1 => ChoicePage(
        title: 'Нақши шумо чист?',
        subtitle: 'Ин телефон барои кӣ аст?',
        value: role,
        items: const [
          Choice('parent', 'Волидайн', Icons.family_restroom),
          Choice('child', 'Фарзанд', Icons.child_care),
        ],
        changed: (v) => setState(() => role = v),
      ),
      2 => PermissionPage(
        location: location,
        notifications: notifications,
        camera: camera,
        appControl: appControl,
        showAppControl: role == 'child',
        requesting: requestingPermissions,
        request: permissions,
        requestAppControl: requestAppControl,
      ),
      _ => SecurityPinSetupPage(pin: pin, confirmPin: confirmPin),
    };
    // Android special access cannot be silently granted. Keep onboarding
    // usable with normal permissions; app blocking is an optional protected
    // feature that the parent enables manually from the protection screen.
    final permissionsReady = location && notifications && camera;
    final pinReady =
        RegExp(r'^\d{4}$').hasMatch(pin.text.trim()) &&
        pin.text.trim() == confirmPin.text.trim();
    final next = step == 0
        ? gender.isNotEmpty
        : step == 1
        ? role.isNotEmpty
        : step == 2
        ? permissionsReady
        : pinReady;
    const stepTitles = [
      'Шиносоӣ',
      'Интихоби нақш',
      'Иҷозатҳои асосӣ',
      'PIN-и муҳофизат',
    ];
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: scheme.outlineVariant),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(13),
                              ),
                              child: const BrandMark(size: 35),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Омодасозии NIGOH Family',
                                    style: TextStyle(
                                      color: scheme.onSurface,
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    'Ҳамагӣ чанд қадами кӯтоҳ',
                                    style: TextStyle(
                                      color: scheme.onSurface.withValues(
                                        alpha: .65,
                                      ),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: scheme.primary.withValues(alpha: .08),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${step + 1}/4',
                                style: TextStyle(
                                  color: scheme.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: List.generate(
                            4,
                            (i) => Expanded(
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 220),
                                height: 7,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: i <= step
                                      ? scheme.primary
                                      : scheme.outlineVariant,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            stepTitles[step],
                            style: TextStyle(
                              color: scheme.onSurface,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: content,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (step > 0)
                        OutlinedButton.icon(
                          onPressed: () => setState(() => step--),
                          icon: const Icon(Icons.arrow_back_rounded),
                          label: const Text('Қафо'),
                        )
                      else
                        const SizedBox.shrink(),
                      const Spacer(),
                      FilledButton.icon(
                        onPressed: !next || saving
                            ? null
                            : () =>
                                  step < 3 ? setState(() => step++) : finish(),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(154, 50),
                          backgroundColor: scheme.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        icon: saving
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Icon(
                                step == 3
                                    ? Icons.shield_rounded
                                    : Icons.arrow_forward_rounded,
                              ),
                        label: Text(step == 3 ? 'Оғоз кардан' : 'Давом додан'),
                      ),
                    ],
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

class Choice {
  const Choice(this.value, this.title, this.icon);
  final String value, title;
  final IconData icon;
}

class ChoicePage extends StatelessWidget {
  const ChoicePage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.items,
    required this.changed,
  });
  final String title, subtitle, value;
  final List<Choice> items;
  final ValueChanged<String> changed;
  @override
  Widget build(BuildContext context) => ListView(
    children: [
      const SizedBox(height: 26),
      Text(
        title,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
      ),
      const SizedBox(height: 8),
      Text(
        subtitle,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Color(0xFF60738A)),
      ),
      const SizedBox(height: 28),
      ...items.map(
        (item) => Card(
          color: value == item.value ? const Color(0xFFEAF1FF) : Colors.white,
          child: ListTile(
            contentPadding: const EdgeInsets.all(18),
            leading: CircleAvatar(child: Icon(item.icon)),
            title: Text(
              item.title,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            trailing: Icon(
              value == item.value ? Icons.check_circle : Icons.circle_outlined,
            ),
            onTap: () => changed(item.value),
          ),
        ),
      ),
    ],
  );
}

class SecurityPinSetupPage extends StatelessWidget {
  const SecurityPinSetupPage({
    super.key,
    required this.pin,
    required this.confirmPin,
  });

  final TextEditingController pin;
  final TextEditingController confirmPin;

  Widget field(TextEditingController controller, String label) => TextField(
    controller: controller,
    obscureText: true,
    keyboardType: TextInputType.number,
    maxLength: 4,
    textAlign: TextAlign.center,
    style: const TextStyle(
      fontSize: 27,
      fontWeight: FontWeight.w900,
      letterSpacing: 10,
    ),
    decoration: InputDecoration(
      labelText: label,
      counterText: '',
      prefixIcon: const Icon(Icons.password_rounded),
    ),
  );

  @override
  Widget build(BuildContext context) => ListView(
    children: [
      const SizedBox(height: 22),
      const Icon(Icons.lock_rounded, size: 68, color: Color(0xFF0095F6)),
      const SizedBox(height: 14),
      const Text(
        'Рамзи муҳофизат гузоред',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900),
      ),
      const SizedBox(height: 8),
      const Text(
        'Барои кушодани NIGOH Family рамзи 4-рақама талаб мешавад. Рамз дар шакли рамзгузоришуда нигоҳ дошта мешавад.',
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 26),
      field(pin, 'Рамзи 4-рақама'),
      const SizedBox(height: 12),
      field(confirmPin, 'Рамзро такрор кунед'),
      if (confirmPin.text.isNotEmpty && pin.text != confirmPin.text) ...[
        const SizedBox(height: 8),
        const Text(
          'Рамзҳо мувофиқ нестанд',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700),
        ),
      ],
    ],
  );
}

class PermissionPage extends StatelessWidget {
  const PermissionPage({
    super.key,
    required this.location,
    required this.notifications,
    required this.camera,
    required this.appControl,
    required this.showAppControl,
    required this.requesting,
    required this.request,
    required this.requestAppControl,
  });
  final bool location,
      notifications,
      camera,
      appControl,
      showAppControl,
      requesting;
  final VoidCallback request, requestAppControl;
  @override
  Widget build(BuildContext context) => ListView(
    children: [
      const SizedBox(height: 22),
      const Text(
        'Иҷозатҳои муҳофизат',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
      ),
      const SizedBox(height: 8),
      const Text(
        'Ҳама иҷозатҳо ошкоро гирифта мешаванд.',
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 24),
      PermissionTile(
        icon: Icons.location_on,
        title: 'Ҷойгиршавӣ',
        ok: location,
      ),
      PermissionTile(
        icon: Icons.notifications,
        title: 'Огоҳиномаҳо',
        ok: notifications,
      ),
      PermissionTile(
        icon: Icons.camera_alt_rounded,
        title: 'Камера барои QR',
        ok: camera,
      ),
      if (showAppControl)
        PermissionTile(
          icon: Icons.apps,
          title: 'Назорати барномаҳо',
          ok: appControl,
          note: appControl
              ? 'Муҳофизати NIGOH фаъол аст'
              : 'Usage access ва Display over apps-ро фаъол кунед',
        ),
      const SizedBox(height: 16),
      FilledButton.icon(
        onPressed: requesting ? null : request,
        icon: requesting
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.security),
        label: Text(
          requesting
              ? 'Иҷозатҳо гирифта мешаванд…'
              : 'Ҳама иҷозатҳоро гирифтан',
        ),
      ),
      if (showAppControl && !appControl) ...[
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: requestAppControl,
          icon: const Icon(Icons.admin_panel_settings_outlined),
          label: const Text('Фаъол кардани назорати барномаҳо'),
        ),
      ],
    ],
  );
}

class PermissionTile extends StatelessWidget {
  const PermissionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.ok,
    this.note,
  });
  final IconData icon;
  final String title;
  final bool ok;
  final String? note;
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: CircleAvatar(child: Icon(icon)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: note == null ? null : Text(note!),
      trailing: Icon(
        ok ? Icons.check_circle : Icons.info_outline,
        color: ok ? Colors.green : Colors.orange,
      ),
    ),
  );
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.user, required this.profile});
  final User user;
  final Map<String, dynamic> profile;
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  static const updateChannel = MethodChannel('tj.nigoh/update');
  static const deviceControlChannel = MethodChannel('tj.nigoh/device_control');
  static const packageEventsChannel = EventChannel('tj.nigoh/package_events');
  int index = 0;
  StreamSubscription<Position>? positions;
  StreamSubscription<DatabaseEvent>? blockedApps;
  StreamSubscription<Object?>? packageEvents;
  bool permissionPromptVisible = false;
  bool permissionNoticeShown = false;
  bool locationStarting = false;
  int permissionWizardStage = 0;
  int? serverChildId;
  NigohApi? serverApi;
  Timer? serverRulesTimer;
  Timer? appsSyncTimer;
  bool serverFamilyLinked = false;
  bool serverFamilyLinking = false;
  bool appsSyncing = false;
  DateTime? lastServerAppsSync;
  bool get parent => widget.profile['role'] == 'parent';
  String? get family => widget.profile['familyId'] as String?;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    db('profiles/${widget.user.uid}')
        .update({'online': true, 'lastSeen': ServerValue.timestamp});
    db('profiles/${widget.user.uid}/online').onDisconnect().set(false);
    if (!parent) {
      unawaited(_bootstrapServerChild());
      startLocation();
      unawaited(syncInstalledApps());
      appsSyncTimer = Timer.periodic(
        const Duration(minutes: 2),
        (_) => unawaited(syncInstalledApps()),
      );
      packageEvents = packageEventsChannel.receiveBroadcastStream().listen((_) {
        if (mounted) unawaited(syncInstalledApps());
      }, onError: (_) {});
      if (family != null) syncBlockedApps();
      unawaited(_syncServerRules());
      serverRulesTimer = Timer.periodic(
        const Duration(seconds: 15),
        (_) => _syncServerRules(),
      );
    }
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await checkForUpdate();
      if (mounted && !parent) await checkMissingPermissions();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || parent) return;
    Future<void>.delayed(const Duration(milliseconds: 450), () async {
      if (!mounted) return;
      if (positions == null) unawaited(startLocation());
      unawaited(syncInstalledApps());
      if (permissionWizardStage == 1) {
        permissionWizardStage = 2;
        await deviceControlChannel.invokeMethod<void>('openUsageSettings');
        return;
      }
      if (permissionWizardStage == 2) {
        final raw = await deviceControlChannel
            .invokeMethod<Map<Object?, Object?>>('getProtectionStatus');
        if (raw?['usage'] != true) {
          permissionWizardStage = 0;
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Дар App info менюи ⋮ → «Разрешить ограниченные настройки»-ро фаъол кунед.',
                ),
              ),
            );
          }
          return;
        }
        if (raw?['overlay'] != true) {
          permissionWizardStage = 3;
          await deviceControlChannel.invokeMethod<void>('openOverlaySettings');
          return;
        }
        permissionWizardStage = 0;
      } else if (permissionWizardStage == 3) {
        permissionWizardStage = 0;
      }
      await checkMissingPermissions();
    });
  }

  Future<List<String>> missingPermissions() async {
    final missing = <String>[];
    final location = await Geolocator.checkPermission();
    if (location == LocationPermission.denied ||
        location == LocationPermission.deniedForever) {
      missing.add('Ҷойгиршавӣ');
    }
    if (!await ph.Permission.camera.isGranted) missing.add('Камера');
    if (!await ph.Permission.notification.isGranted) {
      missing.add('Огоҳиномаҳо');
    }
    try {
      final raw = await deviceControlChannel
          .invokeMethod<Map<Object?, Object?>>('getProtectionStatus');
      if (raw?['usage'] != true) {
        missing.add('Дидани барномаҳои истифодашуда');
      }
      if (raw?['overlay'] != true) {
        missing.add('Намоиш болои барномаҳо');
      }
      if (raw?['accessibility'] != true) {
        missing.add('Accessibility — назорати барномаҳо');
      }
    } catch (_) {}
    return missing;
  }

  Future<int?> _ensureServerChildId() async {
    if (serverChildId != null) return serverChildId;
    final api = serverApi ??= await NigohApi.current('child');
    if (api == null) return null;
    try {
      Map<String, dynamic> snapshot;
      try {
        snapshot = await api.snapshot();
      } on NigohApiException catch (error) {
        // A child that was paired by an older Firebase-only build has no
        // server profile yet; the snapshot then answers 404.
        if (error.statusCode != 404) rethrow;
        snapshot = <String, dynamic>{};
      }
      var child = snapshot['child'] as Map?;
      if (child == null) {
        await api.createPairCode(
          childName: widget.profile['displayName']?.toString() ?? 'Фарзанд',
          gender: widget.profile['gender']?.toString() ?? 'boy',
          age: (widget.profile['age'] as num?)?.toInt() ?? 11,
        );
        snapshot = await api.snapshot();
        child = snapshot['child'] as Map?;
      }
      serverChildId = (child?['id'] as num?)?.toInt();
      return serverChildId;
    } catch (_) {
      return null;
    }
  }

  Future<void> _bootstrapServerChild() async {
    if (parent || serverFamilyLinked || serverFamilyLinking) return;
    serverFamilyLinking = true;
    try {
      final id = await _ensureServerChildId();
      if (id == null || family == null) return;
      final parentSnap = await db('families/$family/parentUid').get();
      final parentUid = parentSnap.value?.toString();
      if (parentUid == null || parentUid.isEmpty) return;
      final api = serverApi;
      if (api != null) {
        await api.linkExisting(parentUid);
        serverFamilyLinked = true;
        unawaited(syncInstalledApps());
      }
    } catch (_) {
      // Firebase-paired families are still supported while the API bridge is
      // being established. Retry later: the parent may not have opened the
      // server-backed dashboard yet when the child first launches.
    } finally {
      serverFamilyLinking = false;
    }
  }

  Future<void> checkMissingPermissions() async {
    if (permissionPromptVisible ||
        permissionWizardStage > 0 ||
        permissionNoticeShown ||
        !mounted) {
      return;
    }
    final missing = await missingPermissions();
    if (missing.isEmpty || !mounted) return;
    permissionNoticeShown = true;
    permissionPromptVisible = true;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const Scaffold(body: AccessCenterPage(childMode: true)),
      ),
    );
    if (mounted) {
      permissionPromptVisible = false;
    }
  }

  Future<void> grantMissingPermissions() async {
    var location = await Geolocator.checkPermission();
    if (location == LocationPermission.denied) {
      location = await Geolocator.requestPermission();
    }
    if (location == LocationPermission.whileInUse) {
      await ph.Permission.locationAlways.request();
    }
    if (!await ph.Permission.camera.isGranted) {
      await ph.Permission.camera.request();
    }
    if (!await ph.Permission.notification.isGranted) {
      await ph.Permission.notification.request();
    }
    final raw = await deviceControlChannel.invokeMethod<Map<Object?, Object?>>(
      'getProtectionStatus',
    );
    if (!mounted) return;
    if (raw?['usage'] != true) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Як қадами Android'),
          content: const Text(
            'Дар саҳифаи NIGOH Family менюи ⋮-ро зер кунед ва «Разрешить ограниченные настройки»-ро интихоб намоед. Баъд ба NIGOH баргардед.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Баъдтар'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Кушодан'),
            ),
          ],
        ),
      );
      if (proceed != true) return;
      permissionWizardStage = 1;
      await deviceControlChannel.invokeMethod<void>('openAppDetails');
      return;
    }
    if (raw?['overlay'] != true) {
      permissionWizardStage = 3;
      await deviceControlChannel.invokeMethod<void>('openOverlaySettings');
      return;
    }
    await checkMissingPermissions();
  }

  @override
  void didUpdateWidget(covariant HomeShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldFamily = oldWidget.profile['familyId'];
    if (!parent && oldFamily == null && family != null) {
      blockedApps?.cancel();
      syncBlockedApps();
    }
  }

  Future<void> checkForUpdate() async {
    try {
      final installed = await PackageInfo.fromPlatform();
      final currentCode = int.tryParse(installed.buildNumber) ?? 0;
      final release = await loadAndroidRelease(updateChannel);
      if (release.isEmpty || !mounted) return;
      final latestCode = (release['versionCode'] as num?)?.toInt() ?? 0;
      final downloadUrl = release['downloadUrl']?.toString() ?? '';
      if (!UserJourneyLogic.shouldOfferUpdate(latestCode, currentCode) ||
          downloadUrl.isEmpty) {
        return;
      }
      final version = release['versionName']?.toString() ?? '$latestCode';
      final mandatory = release['mandatory'] == true;
      final notes =
          release['notes']?.toString() ??
          'Версияи нав бо беҳбудиҳои амниятӣ дастрас аст.';
      await showDialog<void>(
        context: context,
        barrierDismissible: !mandatory,
        builder: (dialogContext) => PopScope(
          canPop: !mandatory,
          child: AlertDialog(
            icon: const Icon(Icons.system_update_rounded, size: 44),
            title: Text('NIGOH Family $version'),
            content: Text(notes),
            actions: [
              if (!mandatory)
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Баъдтар'),
                ),
              FilledButton.icon(
                onPressed: () async {
                  final status = await updateChannel.invokeMethod<String>(
                    'installUpdate',
                    {'downloadUrl': downloadUrl, 'version': version},
                  );
                  if (!mounted || !dialogContext.mounted) return;
                  Navigator.pop(dialogContext);
                  final text = status == 'download_started'
                      ? 'Навсозӣ дар дохили NIGOH зеркашӣ мешавад.'
                      : status == 'install_permission_required'
                      ? 'Иҷозати насбро фаъол кунед. Пас аз баргаштан навсозӣ худкор идома меёбад.'
                      : 'Навсозӣ омода мешавад.';
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text(text)));
                },
                icon: const Icon(Icons.download_rounded),
                label: const Text('Навсозӣ'),
              ),
            ],
          ),
        ),
      );
    } catch (_) {
      // Update checks must never block authentication or the family dashboard.
    }
  }

  Future<void> startLocation() async {
    if (parent || positions != null || locationStarting) return;
    locationStarting = true;
    try {
      await _startLocation();
    } finally {
      locationStarting = false;
    }
  }

  Future<void> _startLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      await db('profiles/${widget.user.uid}/locationStatus').set('gps_off');
      return;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      await db('profiles/${widget.user.uid}/locationStatus')
          .set('permission_denied');
      return;
    }
    try {
      final first = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
      await publishPosition(first);
    } catch (_) {
      // The live stream below still starts when a fast one-shot fix times out.
    }
    final settings = defaultTargetPlatform == TargetPlatform.android
        ? AndroidSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 10,
            intervalDuration: Duration(seconds: 15),
            foregroundNotificationConfig: ForegroundNotificationConfig(
              notificationTitle: 'NIGOH Family фаъол аст',
              notificationText:
                  'Ҷойгиршавӣ бо оилаи пайвастшуда мубодила мешавад.',
              enableWakeLock: true,
              setOngoing: true,
            ),
          )
        : const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 10,
          );
    positions = Geolocator.getPositionStream(locationSettings: settings).listen(
      publishPosition,
      onError: (_) =>
          db('profiles/${widget.user.uid}/locationStatus').set('stream_error'),
    );
    db('locations/${widget.user.uid}/online').onDisconnect().set(false);
  }

  Future<void> publishPosition(Position p) async {
    await db('locations/${widget.user.uid}').set({
      'lat': p.latitude,
      'lng': p.longitude,
      'accuracy': p.accuracy,
      'speed': p.speed,
      'online': true,
      'updatedAt': ServerValue.timestamp,
    });
    await db('profiles/${widget.user.uid}/locationStatus').set('active');
    unawaited(_publishServerPosition(p));
  }

  Future<void> _publishServerPosition(Position p) async {
    try {
      final childId = await _ensureServerChildId();
      final api = serverApi;
      if (childId == null || api == null) return;
      await api.syncLocation(childId, {
        'latitude': p.latitude,
        'longitude': p.longitude,
        'accuracy': p.accuracy,
        'speed': p.speed,
        'is_online': true,
      });
    } catch (_) {}
  }

  Future<void> syncInstalledApps() async {
    if (appsSyncing) return;
    appsSyncing = true;
    try {
      final apps = await deviceControlChannel.invokeListMethod<Object?>(
        'getInstalledApps',
      );
      if (apps == null || apps.isEmpty) return;
      final payload = <String, Object?>{};
      List<Object?> usageRaw = const <Object?>[];
      try {
        usageRaw =
            await deviceControlChannel.invokeListMethod<Object?>(
              'getUsageStats',
            ) ??
            const <Object?>[];
      } catch (_) {
        // Usage access may still be missing; the app list is still useful.
      }
      final usage = <String, Map<String, dynamic>>{};
      for (final raw in usageRaw) {
        if (raw is Map) {
          final value = Map<String, dynamic>.from(raw);
          final packageName = value['packageName']?.toString() ?? '';
          if (packageName.isNotEmpty) usage[packageName] = value;
        }
      }
      for (final raw in apps) {
        if (raw is! Map) continue;
        final app = Map<String, dynamic>.from(raw);
        final packageName = app['packageName']?.toString() ?? '';
        if (packageName.isEmpty) continue;
        payload[encodedAppKey(packageName)] = {
          'packageName': packageName,
          'name': (app['appName'] ?? app['name'])?.toString() ?? packageName,
          'appName': (app['appName'] ?? app['name'])?.toString() ?? packageName,
          'system': app['isSystemApp'] == true || app['system'] == true,
          'isSystemApp': app['isSystemApp'] == true || app['system'] == true,
          'iconBase64': app['iconBase64']?.toString() ?? '',
          'usageMinutes': usage[packageName]?['minutes'] ?? 0,
          'lastUsedAt': usage[packageName]?['lastUsedAt'] ?? 0,
          'updatedAt': ServerValue.timestamp,
        };
      }
      // Realtime Database rules must not prevent the independent FastAPI
      // sync. The parent can read this server snapshot even when RTDB denies
      // access on an older family record.
      unawaited(_syncAppsToServer(payload));
      try {
        await db('installedApps/${widget.user.uid}').set(payload);
      } catch (_) {
        // The server sync above remains active.
      }
    } catch (_) {
    } finally {
      appsSyncing = false;
    }
  }

  Future<void> _syncAppsToServer(Map<String, Object?> payload) async {
    try {
      final childId = await _ensureServerChildId();
      final api = serverApi;
      if (childId == null || api == null) return;
      final apps = payload.values
          .whereType<Map>()
          .map(
            (raw) => <String, dynamic>{
              'package_name': raw['packageName']?.toString() ?? '',
              'app_name': raw['name']?.toString() ?? '',
              'icon_base64': raw['iconBase64']?.toString() ?? '',
              'is_system_app': raw['isSystemApp'] == true,
              // The server rejects the whole batch when a single value is
              // out of range, so keep every field inside its schema.
              'usage_minutes':
                  ((raw['usageMinutes'] as num?)?.toInt() ?? 0).clamp(0, 1440),
              'last_used_at': ((raw['lastUsedAt'] as num?)?.toInt() ?? 0) <= 0
                  ? null
                  : DateTime.fromMillisecondsSinceEpoch(
                      (raw['lastUsedAt'] as num).toInt(),
                    ).toUtc().toIso8601String(),
            },
          )
          .where((item) => item['package_name'].toString().isNotEmpty)
          .toList();
      await api.syncApps(childId, apps);
      lastServerAppsSync = DateTime.now();
    } catch (_) {}
  }

  Future<void> _syncServerRules() async {
    if (parent) return;
    if (!serverFamilyLinked) unawaited(_bootstrapServerChild());
    final lastSync = lastServerAppsSync;
    if (lastSync == null ||
        DateTime.now().difference(lastSync) > const Duration(minutes: 10)) {
      unawaited(syncInstalledApps());
    }
    try {
      final api = serverApi ??= await NigohApi.current('child');
      if (api == null) return;
      final snapshot = await api.snapshot();
      final child = snapshot['child'] as Map?;
      final rules = <Map<String, dynamic>>[];
      for (final raw in (child?['apps'] as List? ?? const [])) {
        if (raw is! Map) continue;
        final item = Map<String, dynamic>.from(raw);
        final packageName = item['package_name']?.toString() ?? '';
        if (packageName.isEmpty) continue;
        final schedule = item['schedule'] is Map
            ? Map<String, dynamic>.from(item['schedule'] as Map)
            : null;
        rules.add({
          'packageName': packageName,
          'blocked': item['is_blocked'] == true || item['is_blocked'] == 1,
          'dailyLimitMinutes': item['daily_limit_minutes'] ?? 0,
          'schedule': schedule,
        });
      }
      await deviceControlChannel.invokeMethod<void>('setAppControlRules', {
        'rules': rules,
      });
    } catch (_) {}
  }

  void syncBlockedApps() {
    blockedApps = db('blockedApps/${widget.user.uid}').onValue.listen((event) {
      final raw = event.snapshot.value as Map?;
      final packages = <String>[];
      final rules = <Map<String, dynamic>>[];
      for (final value in raw?.values ?? const []) {
        if (value is! Map) continue;
        final packageName = value['packageName']?.toString();
        if (packageName == null || packageName.isEmpty) continue;
        final blocked = value['blocked'] == true;
        if (blocked) packages.add(packageName);
        final rawSchedule = value['schedule'];
        final schedule = rawSchedule is Map
            ? <String, dynamic>{
                'enabled': rawSchedule['enabled'] == true,
                'start':
                    rawSchedule['start']?.toString() ??
                    dynamicConfig.ruleString(
                      'homeworkStart',
                      fallback: '16:00',
                    ),
                'end':
                    rawSchedule['end']?.toString() ??
                    dynamicConfig.ruleString('homeworkEnd', fallback: '18:00'),
                'weekdays': rawSchedule['weekdays'] is List
                    ? List<int>.from(
                        (rawSchedule['weekdays'] as List).map(
                          (day) => (day as num?)?.toInt() ?? 1,
                        ),
                      )
                    : <int>[1, 2, 3, 4, 5],
              }
            : null;
        rules.add({
          'packageName': packageName,
          'blocked': blocked,
          'dailyLimitMinutes':
              (value['dailyLimitMinutes'] as num?)?.toInt() ?? 0,
          'schedule': schedule,
        });
      }
      // Native Android stores the whole snapshot immediately, so enforcement
      // continues when the child's connection is disabled.
      deviceControlChannel.invokeMethod<void>('setAppControlRules', {
        'rules': rules,
      });
      // Keep the legacy field in sync for already installed older builds.
      deviceControlChannel.invokeMethod<void>('setBlockedApps', {
        'packages': packages,
      });
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    positions?.cancel();
    blockedApps?.cancel();
    packageEvents?.cancel();
    serverRulesTimer?.cancel();
    appsSyncTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = parent
        ? [
            ParentDashboard(
              profile: widget.profile,
              onOpenApps: () => setState(() => index = 1),
              onOpenLocation: () => setState(() => index = 2),
              onOpenChat: () => setState(() => index = 3),
              onAddChild: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => Scaffold(
                    appBar: AppBar(title: const Text('Илова кардани фарзанд')),
                    body: PairPage(profile: widget.profile, parent: true),
                  ),
                ),
              ),
            ),
            AppControlPage(family: family),
            FamilyMap(family: family, uid: widget.user.uid, parent: true),
            ChatPage(
              family: family,
              uid: widget.user.uid,
              profile: widget.profile,
              parent: true,
            ),
            ParentMorePage(
              user: widget.user,
              profile: widget.profile,
              family: family,
              openApps: () => setState(() => index = 1),
            ),
          ]
        : [
            family == null
                ? PairPage(profile: widget.profile, parent: false)
                : ChildDashboardPage(
                    profile: widget.profile,
                    uid: widget.user.uid,
                    onOpenLocation: () => setState(() => index = 1),
                    onOpenChat: () => setState(() => index = 2),
                    onOpenPermissions: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => Scaffold(
                          appBar: AppBar(title: const Text('Маркази иҷозатҳо')),
                          body: const AccessCenterPage(childMode: true),
                        ),
                      ),
                    ),
                  ),
            FamilyMap(family: family, uid: widget.user.uid, parent: false),
            ChatPage(
              family: family,
              uid: widget.user.uid,
              profile: widget.profile,
              parent: false,
            ),
            ProfilePage(user: widget.user, profile: widget.profile),
          ];
    final nav = parent
        ? const [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard_rounded),
              label: 'Назорат',
            ),
            NavigationDestination(
              icon: Icon(Icons.apps_outlined),
              selectedIcon: Icon(Icons.apps_rounded),
              label: 'Барномаҳо',
            ),
            NavigationDestination(
              icon: Icon(Icons.location_on_outlined),
              selectedIcon: Icon(Icons.location_on_rounded),
              label: 'Харита',
            ),
            NavigationDestination(
              icon: Icon(Icons.chat_bubble_outline_rounded),
              selectedIcon: Icon(Icons.chat_bubble_rounded),
              label: 'Пайёмҳо',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings_rounded),
              label: 'Танзимот',
            ),
          ]
        : const [
            NavigationDestination(
              icon: Icon(Icons.qr_code_2),
              selectedIcon: Icon(Icons.qr_code_2_rounded),
              label: 'Пайваст',
            ),
            NavigationDestination(
              icon: Icon(Icons.map_outlined),
              selectedIcon: Icon(Icons.map_rounded),
              label: 'Ҷой',
            ),
            NavigationDestination(
              icon: Icon(Icons.send_outlined),
              selectedIcon: Icon(Icons.send_rounded),
              label: 'Чат',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Профил',
            ),
          ];
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const BrandMark(size: 32),
            const SizedBox(width: 9),
            Text(
              parent
                  ? dynamicConfig.text(
                      'parent_home_title',
                      fallback: 'NIGOH Family',
                    )
                  : dynamicConfig.text('home_title', fallback: 'NIGOH Family'),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: -.3,
              ),
            ),
          ],
        ),
        actions: [
          if (parent)
            IconButton(
              tooltip: 'Илова кардани фарзанд',
              icon: const Icon(Icons.qr_code_scanner_rounded),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => Scaffold(
                    appBar: AppBar(title: const Text('Илова кардани фарзанд')),
                    body: PairPage(profile: widget.profile, parent: true),
                  ),
                ),
              ),
            ),
          const SizedBox(width: 10),
        ],
      ),
      body: IndexedStack(index: index, children: pages),
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: EdgeInsets.zero,
        child: Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: scheme.surface,
            border: Border(top: BorderSide(color: scheme.outlineVariant)),
          ),
          child: Row(
            children: List.generate(nav.length, (navIndex) {
              final item = nav[navIndex];
              final selected = index == navIndex;
              return Expanded(
                child: Semantics(
                  button: true,
                  selected: selected,
                  label: item.label,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() => index = navIndex),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: selected
                            ? scheme.primary.withValues(alpha: .08)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconTheme(
                            data: IconThemeData(
                              size: 21,
                              color: selected
                                  ? scheme.primary
                                  : scheme.onSurface.withValues(alpha: .58),
                            ),
                            child: selected
                                ? (item.selectedIcon ?? item.icon)
                                : item.icon,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10.5,
                              height: 1.05,
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: selected
                                  ? scheme.primary
                                  : scheme.onSurface.withValues(alpha: .58),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class AppUpdatePage extends StatefulWidget {
  const AppUpdatePage({super.key});

  @override
  State<AppUpdatePage> createState() => _AppUpdatePageState();
}

class _AppUpdatePageState extends State<AppUpdatePage> {
  static const channel = MethodChannel('tj.nigoh/update');
  late Future<PackageInfo> installed;
  late Future<Map<String, dynamic>> release;
  bool opening = false;

  @override
  void initState() {
    super.initState();
    installed = PackageInfo.fromPlatform();
    release = loadAndroidRelease(channel);
  }

  void refresh() => setState(() {
    installed = PackageInfo.fromPlatform();
    release = loadAndroidRelease(channel);
  });

  Future<void> openUpdate(String url, String version) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Пайванди навсозӣ ҳоло дастрас нест.')),
      );
      return;
    }
    setState(() => opening = true);
    try {
      final status = await channel.invokeMethod<String>('installUpdate', {
        'downloadUrl': url,
        'version': version,
      });
      if (!mounted) return;
      final text = status == 'download_started'
          ? 'Навсозӣ зеркашӣ мешавад. Баъди анҷом равзанаи насб худкор кушода мешавад.'
          : status == 'install_permission_required'
          ? 'Иҷозати “Install unknown apps”-ро фаъол кунед ва ба NIGOH баргардед.'
          : 'Навсозӣ омода мешавад.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(text), duration: const Duration(seconds: 5)),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Зеркашии навсозӣ оғоз нашуд. Интернетро санҷед.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => opening = false);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<PackageInfo>(
    future: installed,
    builder: (_, installedSnap) {
      final info = installedSnap.data;
      final currentCode = int.tryParse(info?.buildNumber ?? '') ?? 0;
      return FutureBuilder<Map<String, dynamic>>(
        future: release,
        builder: (_, releaseSnap) {
          final releaseData = releaseSnap.data ?? <String, dynamic>{};
          final latestCode = (releaseData['versionCode'] as num?)?.toInt() ?? 0;
          final latestName = releaseData['versionName']?.toString() ?? '—';
          final notes =
              releaseData['notes']?.toString() ??
              'Маълумоти версияи нав ҳоло дастрас нест.';
          final downloadUrl = releaseData['downloadUrl']?.toString() ?? '';
          final updateAvailable = UserJourneyLogic.shouldOfferUpdate(
            latestCode,
            currentCode,
          );
          final checking =
              info == null ||
              releaseSnap.connectionState == ConnectionState.waiting;

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Center(child: BrandMark(size: 82)),
              const SizedBox(height: 18),
              Text(
                checking
                    ? 'Версия санҷида мешавад…'
                    : updateAvailable
                    ? 'Навсозӣ дастрас аст'
                    : 'Барнома нав аст',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                updateAvailable
                    ? 'NIGOH Family $latestName барои насб омода аст.'
                    : 'Шумо версияи охиринро истифода мебаред.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: _VersionCard(
                      label: 'Версияи ҷорӣ',
                      value: info == null
                          ? '…'
                          : '${info.version} (${info.buildNumber})',
                      icon: Icons.phone_android_rounded,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _VersionCard(
                      label: 'Версияи нав',
                      value: latestCode == 0
                          ? '—'
                          : '$latestName ($latestCode)',
                      icon: Icons.new_releases_rounded,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Чӣ нав шуд?',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(notes),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              if (updateAvailable)
                FilledButton.icon(
                  onPressed: opening
                      ? null
                      : () => openUpdate(downloadUrl, latestName),
                  icon: opening
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.system_update_alt_rounded),
                  label: const Text('Навсозӣ кардан'),
                )
              else
                OutlinedButton.icon(
                  onPressed: refresh,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Аз нав санҷидан'),
                ),
              const SizedBox(height: 12),
              const Text(
                'Навсозӣ дар дохили NIGOH зеркашӣ мешавад. Маълумоти аккаунт, чат ва танзимот нигоҳ дошта мешаванд. Android танҳо тасдиқи охирини насбро нишон медиҳад.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: Colors.black54),
              ),
            ],
          );
        },
      );
    },
  );
}

class _VersionCard extends StatelessWidget {
  const _VersionCard({
    required this.label,
    required this.value,
    required this.icon,
  });
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF315FEA)),
          const SizedBox(height: 12),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
        ],
      ),
    ),
  );
}

class _ProfileRing extends StatelessWidget {
  const _ProfileRing({
    required this.name,
    required this.online,
    this.size = 58,
  });

  final String name;
  final bool online;
  final double size;

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      Container(
        width: size,
        height: size,
        padding: const EdgeInsets.all(2.5),
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0xFFDBEAFE),
        ),
        child: Container(
          padding: const EdgeInsets.all(2.5),
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
          ),
          child: CircleAvatar(
            backgroundColor: const Color(0xFFEFF6FF),
            foregroundColor: NigohDesign.navy,
            child: Text(
              name.isEmpty ? '?' : name[0].toUpperCase(),
              style: TextStyle(
                fontSize: size * .35,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
      Positioned(
        right: 1,
        bottom: 1,
        child: Container(
          width: size * .22,
          height: size * .22,
          decoration: BoxDecoration(
            color: online ? const Color(0xFF22C55E) : const Color(0xFFA8A8A8),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
        ),
      ),
    ],
  );
}

class ParentMorePage extends StatelessWidget {
  const ParentMorePage({
    super.key,
    required this.user,
    required this.profile,
    required this.family,
    required this.openApps,
  });

  final User user;
  final Map<String, dynamic> profile;
  final String? family;
  final VoidCallback openApps;

  static const deviceChannel = MethodChannel('tj.nigoh/device_control');

  Future<void> showUninstallDialog(BuildContext context) async {
    final pin = TextEditingController();
    var busy = false;
    String? error;
    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text('Тасдиқи волидайн'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Барои пурра нест кардани замима рамзи PIN-ро ворид намоед.',
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: pin,
                  autofocus: true,
                  obscureText: true,
                  maxLength: 4,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'PIN-и волидайн',
                    prefixIcon: Icon(Icons.lock_outline_rounded),
                    counterText: '',
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: busy ? null : () => Navigator.pop(dialogContext),
                child: const Text('Бекор кардан'),
              ),
              FilledButton.icon(
                onPressed: busy
                    ? null
                    : () async {
                        final value = pin.text.trim();
                        if (!RegExp(r'^\d{4}$').hasMatch(value)) {
                          setState(
                            () => error = 'PIN бояд аз 4 рақам иборат бошад',
                          );
                          return;
                        }
                        setState(() {
                          busy = true;
                          error = null;
                        });
                        try {
                          final result = await deviceChannel
                              .invokeMapMethod<String, dynamic>(
                                'requestUninstallWithPin',
                                {'pin': value},
                              );
                          if (!context.mounted) return;
                          if (result?['ok'] == true) {
                            Navigator.pop(dialogContext);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Тасдиқ шуд. Android экрани несткуниро мекушояд.',
                                ),
                              ),
                            );
                          } else {
                            final locked = result?['error'] == 'locked';
                            final seconds = result?['remainingSeconds'];
                            setState(() {
                              busy = false;
                              error = locked
                                  ? 'Кӯшишҳо баста шуданд. Баъд аз $seconds сония дубора кӯшиш кунед.'
                                  : result?['error'] == 'no_pin'
                                  ? 'Аввал PIN-и волидайнро дар «Рамзи муҳофизат» гузоред.'
                                  : 'Рамзи PIN нодуруст аст';
                            });
                          }
                        } on PlatformException {
                          if (context.mounted) {
                            setState(() {
                              busy = false;
                              error = 'Нест кардани барнома дастрас нест';
                            });
                          }
                        }
                      },
                icon: busy
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.delete_forever_rounded),
                label: const Text('Нест кардан'),
              ),
            ],
          ),
        ),
      );
    } finally {
      pin.dispose();
    }
  }

  void openPage(BuildContext context, String title, Widget page) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text(title)),
          body: page,
        ),
      ),
    );
  }

  Future<void> showVersion(BuildContext context) async {
    final info = await PackageInfo.fromPlatform();
    if (!context.mounted) return;
    showAboutDialog(
      context: context,
      applicationName: 'NIGOH Family',
      applicationVersion: '${info.version} (${info.buildNumber})',
      applicationIcon: const BrandMark(size: 58),
      children: const [Text('Амнияти фарзанд ва оромии волидайн.')],
    );
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
    children: [
      Row(
        children: [
          _ProfileRing(
            name: profile['displayName']?.toString() ?? 'Волидайн',
            online: true,
            size: 74,
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile['displayName']?.toString() ?? 'Волидайн',
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  user.email ?? '',
                  style: const TextStyle(color: Colors.black54),
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 22),
      const Divider(height: 1),
      const SizedBox(height: 12),
      GridView.count(
        crossAxisCount: 1,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 8,
        childAspectRatio: 4.5,
        children: [
          _MenuActionCard(
            icon: Icons.person_add_alt_1_rounded,
            title: 'Иловаи фарзанд',
            subtitle: 'QR ё рамзи оила',
            color: const Color(0xFF315FEA),
            onTap: () => openPage(
              context,
              'Илова кардани фарзанд',
              PairPage(profile: profile, parent: true),
            ),
          ),
          _MenuActionCard(
            icon: Icons.admin_panel_settings_rounded,
            title: 'Барномаҳо',
            subtitle: 'Дидан ва маҳкам кардан',
            color: const Color(0xFF00A98F),
            onTap: openApps,
          ),
          _MenuActionCard(
            icon: Icons.security_rounded,
            title: 'Маркази иҷозатҳо',
            subtitle: 'Бинед, кадом дастрасӣ дода нашудааст',
            color: const Color(0xFF0057FF),
            onTap: () => openPage(
              context,
              'Маркази иҷозатҳо',
              const AccessCenterPage(childMode: false),
            ),
          ),
          _MenuActionCard(
            icon: Icons.water_drop_rounded,
            title: 'Намуди барнома',
            subtitle: 'Режими Cyber Blue ё Clean White-ро интихоб кунед',
            color: const Color(0xFF147DFF),
            onTap: () =>
                openPage(context, 'Намуди барнома', const AppearancePage()),
          ),
          _MenuActionCard(
            icon: Icons.manage_accounts_rounded,
            title: 'Профили ман',
            subtitle: 'Ном, почта ва баромадан',
            color: const Color(0xFF7758D9),
            onTap: () => openPage(
              context,
              'Профили ман',
              ProfilePage(user: user, profile: profile),
            ),
          ),
          _MenuActionCard(
            icon: Icons.info_outline_rounded,
            title: 'Дар бораи барнома',
            subtitle: 'Версия ва маълумот',
            color: const Color(0xFFE89128),
            onTap: () => showVersion(context),
          ),
          _MenuActionCard(
            icon: Icons.system_update_alt_rounded,
            title: 'Навсозии барнома',
            subtitle: 'Санҷидан ва нав кардан',
            color: const Color(0xFF0A89C7),
            onTap: () =>
                openPage(context, 'Навсозии барнома', const AppUpdatePage()),
          ),
          _MenuActionCard(
            icon: Icons.password_rounded,
            title: 'Рамзи муҳофизат',
            subtitle: 'Гузоштан ё иваз кардани PIN',
            color: const Color(0xFFD14A73),
            onTap: () =>
                openPage(context, 'Рамзи муҳофизат', const SecurityCodePage()),
          ),
          _MenuActionCard(
            icon: Icons.delete_forever_rounded,
            title: 'Нест кардани барнома аз ин дастгоҳ',
            subtitle: 'Танҳо бо PIN-и волидайн',
            color: const Color(0xFFE63946),
            onTap: () => showUninstallDialog(context),
          ),
        ],
      ),
      const SizedBox(height: 16),
      Card(
        child: ListTile(
          leading: const CircleAvatar(
            backgroundColor: Color(0xFFE8F7F3),
            child: Icon(Icons.verified_user_rounded, color: Color(0xFF009B82)),
          ),
          title: const Text(
            'Оилаи муҳофизатшуда',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          subtitle: Text(
            family == null
                ? 'Ҳоло фарзанд пайваст нашудааст'
                : 'Пайвастшавии рамзгузоришуда фаъол аст',
          ),
        ),
      ),
      const SizedBox(height: 10),
      OutlinedButton.icon(
        onPressed: () async {
          await GoogleSignIn.instance.signOut();
          await FirebaseAuth.instance.signOut();
        },
        icon: const Icon(Icons.logout_rounded),
        label: const Text('Баромадан аз аккаунт'),
      ),
    ],
  );
}

class AppearancePage extends StatelessWidget {
  const AppearancePage({super.key});

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(16, 18, 16, 30),
    children: [
      const Text(
        'Намуди барнома',
        style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900),
      ),
      const SizedBox(height: 7),
      const Text(
        'Ранги барнома фавран иваз мешавад ва интихоби шумо дар телефон нигоҳ дошта мешавад.',
      ),
      const SizedBox(height: 18),
      ValueListenableBuilder<bool>(
        valueListenable: darkMode,
        builder: (_, enabled, _) => Card(
          child: SwitchListTile.adaptive(
            value: enabled,
            onChanged: (value) => unawaited(setDarkMode(value)),
            secondary: Icon(
              enabled ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
            ),
            title: const Text(
              'Режими торик / равшан',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: Text(
              enabled ? 'Cyber Midnight Blue фаъол' : 'Clean White фаъол',
            ),
          ),
        ),
      ),
    ],
  );
}

class SecurityCodePage extends StatefulWidget {
  const SecurityCodePage({super.key});

  @override
  State<SecurityCodePage> createState() => _SecurityCodePageState();
}

class _SecurityCodePageState extends State<SecurityCodePage> {
  static const deviceChannel = MethodChannel('tj.nigoh/device_control');
  final current = TextEditingController();
  final next = TextEditingController();
  final confirm = TextEditingController();
  bool loading = true;
  bool hasPin = false;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    loadStatus();
  }

  Future<void> loadStatus() async {
    final enabled =
        await deviceChannel.invokeMethod<bool>('getLocalPinStatus') ?? false;
    if (mounted) {
      setState(() {
        hasPin = enabled;
        loading = false;
      });
    }
  }

  @override
  void dispose() {
    current.dispose();
    next.dispose();
    confirm.dispose();
    super.dispose();
  }

  void message(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<void> save() async {
    final newPin = next.text.trim();
    if (!RegExp(r'^\d{4}$').hasMatch(newPin)) {
      return message('Рамзи нав бояд аз 4 рақам иборат бошад');
    }
    if (newPin != confirm.text.trim()) {
      return message('Такрори рамз мувофиқ нест');
    }
    setState(() => saving = true);
    final result = await deviceChannel.invokeMapMethod<String, dynamic>(
      'setLocalPin',
      {'currentPin': current.text.trim(), 'newPin': newPin},
    );
    if (result?['ok'] != true) {
      if (mounted) setState(() => saving = false);
      return message(
        result?['error'] == 'wrong_current_pin'
            ? 'Рамзи ҷорӣ нодуруст аст'
            : 'Рамз нигоҳ дошта нашуд',
      );
    }
    current.clear();
    next.clear();
    confirm.clear();
    final wasNew = !hasPin;
    if (mounted) {
      setState(() {
        saving = false;
        hasPin = true;
      });
    }
    message(wasNew ? 'Рамз гузошта шуд' : 'Рамз иваз шуд');
  }

  Widget pinField(TextEditingController controller, String label) => TextField(
    controller: controller,
    obscureText: true,
    keyboardType: TextInputType.number,
    maxLength: 4,
    decoration: InputDecoration(
      labelText: label,
      counterText: '',
      prefixIcon: const Icon(Icons.password_rounded),
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    return ListView(
      padding: const EdgeInsets.all(22),
      children: [
        Icon(
          hasPin ? Icons.lock_rounded : Icons.lock_open_rounded,
          size: 74,
          color: const Color(0xFF315FEA),
        ),
        const SizedBox(height: 14),
        Text(
          hasPin ? 'Рамз фаъол аст' : 'Рамзи муҳофизат гузоред',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 7),
        const Text(
          'Ҳангоми аз нав кушодани панели волидайн ин рамз дархост мешавад.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        if (hasPin) ...[
          pinField(current, 'Рамзи ҷорӣ'),
          const SizedBox(height: 10),
        ],
        pinField(next, hasPin ? 'Рамзи нав' : 'Рамзи 4-рақама'),
        const SizedBox(height: 10),
        pinField(confirm, 'Рамзи навро такрор кунед'),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: saving ? null : save,
          icon: saving
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_rounded),
          label: Text(hasPin ? 'Иваз кардани рамз' : 'Гузоштани рамз'),
        ),
      ],
    );
  }
}

class _MenuActionCard extends StatelessWidget {
  const _MenuActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            CircleAvatar(
              radius: 21,
              backgroundColor: color.withValues(alpha: .10),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.black38),
          ],
        ),
      ),
    ),
  );
}

class ParentDashboard extends StatefulWidget {
  const ParentDashboard({
    super.key,
    required this.profile,
    required this.onOpenApps,
    required this.onOpenLocation,
    required this.onOpenChat,
    required this.onAddChild,
  });
  final Map<String, dynamic> profile;
  final VoidCallback onOpenApps;
  final VoidCallback onOpenLocation;
  final VoidCallback onOpenChat;
  final VoidCallback onAddChild;

  @override
  State<ParentDashboard> createState() => _ParentDashboardState();
}

class _ParentDashboardState extends State<ParentDashboard> {
  Map<String, dynamic> get profile => widget.profile;
  VoidCallback get onOpenApps => widget.onOpenApps;
  VoidCallback get onOpenLocation => widget.onOpenLocation;
  VoidCallback get onOpenChat => widget.onOpenChat;
  VoidCallback get onAddChild => widget.onAddChild;

  static const deviceChannel = MethodChannel('tj.nigoh/device_control');
  List<Map<String, dynamic>> serverChildren = <Map<String, dynamic>>[];
  Timer? refreshTimer;

  @override
  void initState() {
    super.initState();
    unawaited(_loadServerChildren());
    refreshTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _loadServerChildren(),
    );
  }

  Future<void> _loadServerChildren() async {
    try {
      final api = await NigohApi.current('parent');
      if (api == null) return;
      final snapshot = await api.snapshot();
      final children = (snapshot['children'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .where((item) => (item['firebase_uid']?.toString() ?? '').isNotEmpty)
          .toList();
      if (mounted) setState(() => serverChildren = children);
    } catch (_) {
      // Realtime Database remains available when the API is temporarily down.
    }
  }

  Map<String, dynamic>? _serverChild(Object uid) {
    for (final child in serverChildren) {
      if (child['firebase_uid']?.toString() == uid.toString()) return child;
    }
    return null;
  }

  @override
  void dispose() {
    refreshTimer?.cancel();
    super.dispose();
  }

  Future<bool> verifyRemovePin(BuildContext context) async {
    final hasPin =
        await deviceChannel.invokeMethod<bool>('getLocalPinStatus') ?? false;
    if (!hasPin) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Аввал дар меню PIN-и муҳофизатро гузоред.'),
          ),
        );
      }
      return false;
    }
    final controller = TextEditingController();
    var error = false;
    if (!context.mounted) {
      controller.dispose();
      return false;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (_, setDialogState) => AlertDialog(
          icon: const Icon(Icons.lock_rounded, color: Color(0xFF0057FF)),
          title: const Text('Тасдиқи PIN лозим аст'),
          content: TextField(
            controller: controller,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: 4,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'PIN-и волидайн',
              errorText: error ? 'PIN нодуруст аст' : null,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Бекор кардан'),
            ),
            FilledButton(
              onPressed: () async {
                final valid =
                    await deviceChannel.invokeMethod<bool>('verifyLocalPin', {
                      'pin': controller.text.trim(),
                    }) ??
                    false;
                if (valid && dialogContext.mounted) {
                  Navigator.pop(dialogContext, true);
                } else {
                  setDialogState(() => error = true);
                }
              },
              child: const Text('Тасдиқ кардан'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    return ok == true;
  }

  Future<void> removeChild(
    BuildContext context,
    String family,
    String childUid,
    String name,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        icon: const Icon(Icons.person_remove_rounded, color: Colors.red),
        title: Text('$name-ро хориҷ мекунед?'),
        content: const Text(
          'Пайвастшавӣ, ҷойгиршавии муштарак, қоидаҳои барномаҳо ва чат аз ин оила тоза мешаванд. Аккаунти фарзанд боқӣ мемонад ва метавонад боз пайваст шавад.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Не'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Хориҷ кардан'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!context.mounted) return;
    if (!await verifyRemovePin(context)) return;
    await db('').update({
      'families/$family/children/$childUid': null,
      'userFamilies/$childUid/$family': null,
      'profiles/$childUid/familyId': null,
      'locations/$childUid': null,
      'blockedApps/$childUid': null,
      'installedApps/$childUid': null,
      'conversations/$family/$childUid': null,
    });
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$name аз оила хориҷ шуд')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final family = profile['familyId'] as String?;
    final scheme = Theme.of(context).colorScheme;
    final displayName = profile['displayName']?.toString().trim();
    final firstName = displayName == null || displayName.isEmpty
        ? 'Волидайн'
        : displayName.split(RegExp(r'\s+')).first;
    return StreamBuilder<DatabaseEvent>(
      stream: family == null ? null : db('families/$family/children').onValue,
      builder: (_, snap) {
        final firebaseChildren = snap.data?.snapshot.value as Map?;
        final children = firebaseChildren != null && firebaseChildren.isNotEmpty
            ? firebaseChildren
            : <String, bool>{
                for (final child in serverChildren)
                  if ((child['firebase_uid']?.toString() ?? '').isNotEmpty)
                    child['firebase_uid'].toString(): true,
              };
        return ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: NigohHeroCard(
                badge: 'NIGOH SHIELD • ФАЪОЛ',
                title: 'Салом, $firstName!',
                subtitle: 'Ҷойгиршавӣ, вақти экран ва амнияти фарзандон дар як панели фаҳмо.',
                icon: Icons.family_restroom_rounded,
                footer: Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: onOpenApps,
                        style: FilledButton.styleFrom(
                          backgroundColor: NigohDesign.blue,
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.apps_rounded, size: 19),
                        label: const Text('Барномаҳо'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    IconButton.filled(
                      tooltip: 'Илова кардани фарзанд',
                      onPressed: onAddChild,
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFFEFF6FF),
                        foregroundColor: NigohDesign.blue,
                        side: const BorderSide(color: Color(0xFFDBEAFE)),
                      ),
                      icon: const Icon(Icons.person_add_alt_1_rounded),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
              child: NigohSectionHeader(
                title: 'Идоракунии зуд',
                subtitle: 'Ҳамаи вазифаҳои асосӣ бе ҷустуҷӯ',
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: LayoutBuilder(
                builder: (context, constraints) => GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: constraints.maxWidth >= 650 ? 4 : 2,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: constraints.maxWidth >= 650 ? 1.15 : 1.34,
                  children: [
                    NigohActionCard(
                      icon: Icons.apps_rounded,
                      title: 'Барномаҳо',
                      subtitle: 'Лимит ва қулф',
                      color: NigohDesign.blue,
                      onTap: onOpenApps,
                    ),
                    NigohActionCard(
                      icon: Icons.location_on_rounded,
                      title: 'Ҷойгиршавӣ',
                      subtitle: 'Харитаи зинда',
                      color: NigohDesign.mint,
                      onTap: onOpenLocation,
                    ),
                    NigohActionCard(
                      icon: Icons.chat_bubble_rounded,
                      title: 'Паёмҳо',
                      subtitle: 'Чати оилавӣ',
                      color: const Color(0xFF8B5CF6),
                      onTap: onOpenChat,
                    ),
                    NigohActionCard(
                      icon: Icons.qr_code_scanner_rounded,
                      title: 'Илова',
                      subtitle: 'QR ё рамзи 6-рақама',
                      color: NigohDesign.amber,
                      onTap: onAddChild,
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 22, 16, 12),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Оилаи ман',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  NigohStatusPill(
                    icon: Icons.people_alt_rounded,
                    label: '${children.length} фарзанд',
                    color: scheme.primary,
                  ),
                ],
              ),
            ),
            if (children.isNotEmpty)
              SizedBox(
                height: 102,
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  scrollDirection: Axis.horizontal,
                  children: children.keys.map((uid) {
                    return StreamBuilder<DatabaseEvent>(
                      stream: db('profiles/$uid').onValue,
                      builder: (_, childSnap) {
                        final data = childSnap.data?.snapshot.value as Map?;
                        final server = _serverChild(uid);
                        final name =
                            data?['displayName']?.toString() ??
                            server?['name']?.toString() ??
                            'Фарзанд';
                        final online =
                            data?['online'] == true ||
                            server?['is_online'] == true ||
                            server?['is_online'] == 1;
                        return SizedBox(
                          width: 84,
                          child: Column(
                            children: [
                              _ProfileRing(
                                name: name,
                                online: online,
                                size: 67,
                              ),
                              const SizedBox(height: 5),
                              Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  }).toList(),
                ),
              ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Metric(
                      icon: Icons.people_outline,
                      value: '${children.length}',
                      label: 'Фарзанд',
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Metric(
                      icon: Icons.shield_outlined,
                      value: 'Фаъол',
                      label: 'Муҳофизат',
                    ),
                  ),
                ],
              ),
            ),
            if (children.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const EmptyCard(
                      icon: Icons.qr_code_scanner,
                      title: 'Фарзанд илова нашудааст',
                      text: 'QR-кодро скан кунед ё рамзи 6-рақамаи телефони фарзандро ворид намоед.',
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: onAddChild,
                      icon: const Icon(Icons.person_add_alt_1_rounded),
                      label: const Text('Илова кардани фарзанд'),
                    ),
                  ],
                ),
              )
            else
              ...children.keys.map(
                (uid) => StreamBuilder<DatabaseEvent>(
                  stream: db('profiles/$uid').onValue,
                  builder: (_, child) {
                    final data = child.data?.snapshot.value as Map?;
                    final server = _serverChild(uid);
                    final display =
                        '${data?['displayName'] ?? server?['name'] ?? 'Фарзанд'}';
                    final online =
                        data?['online'] == true ||
                        server?['is_online'] == true ||
                        server?['is_online'] == 1;
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16, 5, 16, 5),
                      child: Card(
                        child: ListTile(
                          leading: _ProfileRing(
                            name: display,
                            online: online,
                            size: 48,
                          ),
                          title: Text(
                            display,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          subtitle: Text(online ? '● Онлайн' : 'Офлайн'),
                          trailing: PopupMenuButton<String>(
                            tooltip: 'Амалиёт',
                            onSelected: (value) {
                              if (value == 'remove') {
                                removeChild(
                                  context,
                                  family!,
                                  uid.toString(),
                                  display,
                                );
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: 'remove',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.person_remove,
                                      color: Colors.red,
                                    ),
                                    SizedBox(width: 10),
                                    Text('Хориҷ кардани фарзанд'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}

class Metric extends StatelessWidget {
  const Metric({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
  });
  final IconData icon;
  final String value, label;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: scheme.primary.withValues(alpha: .12),
              foregroundColor: scheme.primary,
              child: Icon(icon),
            ),
            const SizedBox(height: 14),
            Text(
              value,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            Text(
              label,
              style: TextStyle(color: scheme.onSurface.withValues(alpha: .62)),
            ),
          ],
        ),
      ),
    );
  }
}

class EmptyCard extends StatelessWidget {
  const EmptyCard({
    super.key,
    required this.icon,
    required this.title,
    required this.text,
  });
  final IconData icon;
  final String title, text;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(26),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: const Color(0xFF1667FF)),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(text, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}

class ChildDashboardPage extends StatefulWidget {
  const ChildDashboardPage({
    super.key,
    required this.profile,
    required this.uid,
    required this.onOpenLocation,
    required this.onOpenChat,
    required this.onOpenPermissions,
  });

  final Map<String, dynamic> profile;
  final String uid;
  final VoidCallback onOpenLocation;
  final VoidCallback onOpenChat;
  final VoidCallback onOpenPermissions;

  @override
  State<ChildDashboardPage> createState() => _ChildDashboardPageState();
}

class _ChildDashboardPageState extends State<ChildDashboardPage> {
  Map<String, dynamic> child = <String, dynamic>{};
  List<Map<String, dynamic>> apps = <Map<String, dynamic>>[];
  bool loading = true;
  Timer? refreshTimer;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
    refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) => _load());
  }

  Future<void> _load() async {
    try {
      final api = await NigohApi.current('child');
      if (api == null) return;
      final snapshot = await api.snapshot();
      final rawChild = snapshot['child'];
      final rawApps = rawChild is Map ? rawChild['apps'] : null;
      final nextApps =
          (rawApps as List? ?? const [])
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList()
            ..sort(
              (a, b) => ((b['usage_minutes_today'] as num?)?.toInt() ?? 0)
                  .compareTo((a['usage_minutes_today'] as num?)?.toInt() ?? 0),
            );
      if (!mounted) return;
      setState(() {
        child = rawChild is Map
            ? Map<String, dynamic>.from(rawChild)
            : <String, dynamic>{};
        apps = nextApps;
        loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    refreshTimer?.cancel();
    super.dispose();
  }

  String _minutesLabel(int minutes) {
    if (minutes < 60) return '$minutes дақ.';
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    return rest == 0 ? '$hours соат' : '$hours с $rest дақ.';
  }

  Widget _metric(
    BuildContext context,
    IconData icon,
    String value,
    String label,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface.withValues(alpha: .62),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Icon(icon, size: 21, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 5),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _appRow(BuildContext context, Map<String, dynamic> app) {
    final name =
        app['app_name']?.toString() ??
        app['package_name']?.toString() ??
        'Барнома';
    final used = (app['usage_minutes_today'] as num?)?.toInt() ?? 0;
    final limit = (app['daily_limit_minutes'] as num?)?.toInt() ?? 0;
    final blocked = app['is_blocked'] == true || app['is_blocked'] == 1;
    final progress = limit > 0
        ? (used / limit).clamp(0.0, 1.0).toDouble()
        : 0.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: Theme.of(context).colorScheme.primary
                .withValues(alpha: .12),
            child: Icon(
              Icons.apps_rounded,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    Text(
                      blocked ? 'Маҳкам' : _minutesLabel(used),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: blocked
                            ? Theme.of(context).colorScheme.error
                            : Theme.of(context).colorScheme.onSurface
                                  .withValues(alpha: .62),
                      ),
                    ),
                  ],
                ),
                if (limit > 0) ...[
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      minHeight: 6,
                      value: progress,
                      backgroundColor: Theme.of(context).colorScheme.primary
                          .withValues(alpha: .10),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${_minutesLabel(used)} аз ${_minutesLabel(limit)}',
                    style: TextStyle(
                      fontSize: 10,
                      color: Theme.of(context).colorScheme.onSurface
                          .withValues(alpha: .58),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.profile['displayName']?.toString() ?? 'Фарзанд';
    final used = apps.fold<int>(
      0,
      (sum, app) => sum + ((app['usage_minutes_today'] as num?)?.toInt() ?? 0),
    );
    final blocked = apps
        .where((app) => app['is_blocked'] == true || app['is_blocked'] == 1)
        .length;
    final location = child['location'] is Map
        ? Map<String, dynamic>.from(child['location'] as Map)
        : const <String, dynamic>{};
    final online =
        child['is_online'] == 1 ||
        child['is_online'] == true ||
        location['online'] == true;
    final scheme = Theme.of(context).colorScheme;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
        children: [
          Text(
            'Салом, $name 👋',
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Ин панели шахсии ту дар NIGOH Family аст.',
            style: TextStyle(color: scheme.onSurface.withValues(alpha: .65)),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.link_rounded, color: scheme.primary, size: 26),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        'Оила пайваст аст',
                        style: TextStyle(
                          color: scheme.onSurface,
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: .08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        online ? 'Онлайн' : 'Офлайн',
                        style: TextStyle(
                          color: scheme.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 9),
                Text(
                  'Волидайн метавонад вақти истифода, барномаҳо ва ҷойгиршавиро идора кунад.',
                  style: TextStyle(
                    color: scheme.onSurface.withValues(alpha: .65),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 15),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: widget.onOpenChat,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: scheme.primary,
                          side: BorderSide(color: scheme.outlineVariant),
                        ),
                        icon: const Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 18,
                        ),
                        label: const Text('Чат'),
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: widget.onOpenLocation,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: scheme.primary,
                          side: BorderSide(color: scheme.outlineVariant),
                        ),
                        icon: const Icon(Icons.location_on_outlined, size: 18),
                        label: const Text('Ҷой'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _metric(
                context,
                Icons.timer_outlined,
                _minutesLabel(used),
                'Имрӯз',
              ),
              const SizedBox(width: 9),
              _metric(context, Icons.apps_rounded, '${apps.length}', 'Барнома'),
              const SizedBox(width: 9),
              _metric(
                context,
                Icons.lock_outline_rounded,
                '$blocked',
                'Маҳкам',
              ),
            ],
          ),
          const SizedBox(height: 20),
          const NigohSectionHeader(
            title: 'Амалиёти зуд',
            subtitle: 'Ҳар чизе ки имрӯз лозим мешавад',
          ),
          const SizedBox(height: 10),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            mainAxisSpacing: 9,
            crossAxisSpacing: 9,
            childAspectRatio: .82,
            children: [
              NigohActionCard(
                icon: Icons.chat_bubble_rounded,
                title: 'Чат',
                subtitle: 'Ба оила навис',
                color: const Color(0xFF8B5CF6),
                onTap: widget.onOpenChat,
              ),
              NigohActionCard(
                icon: Icons.location_on_rounded,
                title: 'Ҷой',
                subtitle: 'Харитаро бин',
                color: NigohDesign.mint,
                onTap: widget.onOpenLocation,
              ),
              NigohActionCard(
                icon: Icons.shield_rounded,
                title: 'Иҷозатҳо',
                subtitle: 'Муҳофизатро санҷ',
                color: NigohDesign.blue,
                onTap: widget.onOpenPermissions,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: scheme.primary.withValues(alpha: .12),
                child: Icon(Icons.verified_user_rounded, color: scheme.primary),
              ),
              title: const Text(
                'Муҳофизати телефон',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(
                blocked > 0
                    ? '$blocked барнома ҳоло маҳкам аст'
                    : 'Қоидаҳои волидайн дар пасзамина фаъоланд',
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: widget.onOpenPermissions,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Барномаҳои имрӯз',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
                ),
              ),
              IconButton(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          if (loading && apps.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (apps.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Text(
                  'Ҳоло рӯйхати барномаҳо омода нашудааст. Дар «Маркази иҷозатҳо» Usage Access-ро фаъол карда, барномаро аз нав кушоед.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: scheme.onSurface.withValues(alpha: .68),
                  ),
                ),
              ),
            )
          else
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 16, 14, 5),
                child: Column(
                  children: apps
                      .take(5)
                      .map((app) => _appRow(context, app))
                      .toList(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class PairPage extends StatefulWidget {
  const PairPage({super.key, required this.profile, required this.parent});
  final Map<String, dynamic> profile;
  final bool parent;
  @override
  State<PairPage> createState() => _PairPageState();
}

class _PairPageState extends State<PairPage> {
  final input = TextEditingController();
  String? code;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    if (!widget.parent && widget.profile['familyId'] == null) createCode();
  }

  Future<void> createCode() async {
    var value = (100000 + Random.secure().nextInt(900000)).toString();
    final oldCode = code;
    var serverCreated = false;
    try {
      if (!widget.parent) {
        final api = await NigohApi.current('child');
        if (api != null) {
          final server = await api.createPairCode(
            childName: widget.profile['displayName']?.toString() ?? 'Фарзанд',
            gender: widget.profile['gender']?.toString() ?? 'boy',
            age: (widget.profile['age'] as num?)?.toInt() ?? 11,
          );
          value = server['pairing_code']?.toString() ?? value;
          serverCreated = true;
        }
      }
      final updates = <String, Object?>{
        'pairCodes/$value': {
          'childUid': FirebaseAuth.instance.currentUser!.uid,
          'createdAt': ServerValue.timestamp,
          'expiresAt': DateTime.now()
              .add(const Duration(minutes: 15))
              .millisecondsSinceEpoch,
          'used': false,
        },
      };
      if (oldCode != null) updates['pairCodes/$oldCode'] = null;
      try {
        await db('').update(updates);
      } catch (_) {
        if (!serverCreated) rethrow;
        // The FastAPI pairing code is authoritative. A Realtime Database
        // outage must not hide a valid code from the child.
        message('Код аз сервер омода шуд; Firebase баъдтар ҳамоҳанг мешавад.');
      }
      if (mounted) setState(() => code = value);
    } catch (error) {
      message('Коди нав сохта нашуд: $error');
    }
  }

  void message(Object text) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$text')));
    }
  }

  Future<void> pair(String raw) async {
    final value = UserJourneyLogic.pairingCode(raw);
    if (value.length != 6) return message('QR ё код нодуруст аст');
    setState(() => busy = true);
    var serverPaired = false;
    try {
      try {
        final api = await NigohApi.current('parent');
        if (api != null) {
          await api.pair(value);
          serverPaired = true;
        }
      } catch (_) {
        // Keep compatibility with families created by the Firebase-only
        // builds; the API bridge is retried on the next child sync.
      }
      final snap = await db('pairCodes/$value').get();
      final rawData = snap.value;
      if (rawData is! Map) {
        throw Exception('Код ёфт нашуд. Аз телефони фарзанд коди нав гиред.');
      }
      final data = Map<String, dynamic>.from(rawData);
      final expiresAt = (data['expiresAt'] as num?)?.toInt() ?? 0;
      if (data['used'] == true ||
          expiresAt < DateTime.now().millisecondsSinceEpoch) {
        throw Exception('Код гузаштааст. Аз телефони фарзанд коди нав гиред.');
      }
      final childUid = data['childUid']?.toString();
      if (childUid == null || childUid.isEmpty) {
        throw Exception('Коди pairing нодуруст аст. Коди нав созед.');
      }
      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      if (currentUid == null || currentUid == childUid) {
        throw Exception(
          'Parent бояд бо аккаунти дигар ворид шавад, на бо аккаунти фарзанд.',
        );
      }
      final codeRef = db('pairCodes/$value');
      // Claim the one-time code first. Firebase rules can then authorize the
      // parent to consume it, while another parent cannot race the same code.
      await codeRef.update({
        'parentUid': currentUid,
        'claimedAt': ServerValue.timestamp,
      });
      var family = widget.profile['familyId']?.toString();
      try {
        if (family == null || family.isEmpty) {
          family = db('families').push().key;
          if (family == null) throw Exception('Оилаи нав сохта нашуд.');
          await db('').update({
            'profiles/$currentUid/familyId': family,
            'families/$family/parentUid': currentUid,
            'families/$family/createdAt': ServerValue.timestamp,
            'userFamilies/$currentUid/$family': true,
          });
        }
        await db('').update({
          'families/$family/children/$childUid': true,
          'userFamilies/$childUid/$family': true,
          'profiles/$childUid/familyId': family,
        });
        // Mark the code as consumed only after all family membership writes
        // succeed. Keeping the tombstone makes this work with both the
        // current and older deployed Firebase rules while preventing reuse.
        await codeRef.update({
          'used': true,
          'consumedAt': ServerValue.timestamp,
        });
      } catch (error) {
        // A rollback is best-effort. Older deployed rules allow the child to
        // write its own code and allow the claimed parent to update it, but
        // they do not allow a parent to delete/reset a claim. Keeping the
        // claim is safe: the same parent can retry the membership write, and
        // another parent cannot complete the pairing flow with this code.
        try {
          await codeRef.update({'parentUid': null, 'claimedAt': null});
        } catch (_) {
          // Preserve the original membership error for the user.
        }
        rethrow;
      }
      message('Фарзанд пайваст шуд');
      if (widget.parent && mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (serverPaired) {
        message(
          'Фарзанд дар сервер пайваст шуд; Firebase баъдтар ҳамоҳанг мешавад.',
        );
        if (widget.parent && mounted) Navigator.of(context).pop(true);
        return;
      }
      final error = e.toString().replaceFirst('Exception: ', '');
      message('Пайвастшавӣ нашуд: $error');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.parent) {
      if (widget.profile['familyId'] != null) {
        return const Center(
          child: EmptyCard(
            icon: Icons.link,
            title: 'Ба оила пайваст шудед',
            text: 'Волидайн метавонад ҷойгиршавӣ ва ҳолати дастгоҳро бинад.',
          ),
        );
      }
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'Пайвастшавӣ бо волидайн',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          const Text(
            'QR-код 15 дақиқа эътибор дорад.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 22),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  if (code == null)
                    const CircularProgressIndicator()
                  else ...[
                    QrImageView(data: 'nigoh://pair/$code', size: 230),
                    const SizedBox(height: 12),
                    Text(
                      code!,
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 8,
                      ),
                    ),
                  ],
                  TextButton.icon(
                    onPressed: createCode,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Коди нав'),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }
    return ListView(
      padding: const EdgeInsets.all(22),
      children: [
        const Text(
          'Илова кардани фарзанд',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        const Text('QR-и телефони фарзандро скан кунед ё кодро нависед.'),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: busy
              ? null
              : () async {
                  final result = await Navigator.push<String>(
                    context,
                    MaterialPageRoute(builder: (_) => const ScannerPage()),
                  );
                  if (result != null) pair(result);
                },
          icon: const Icon(Icons.qr_code_scanner),
          label: const Text('Кушодани сканер'),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: input,
          keyboardType: TextInputType.number,
          maxLength: 6,
          decoration: const InputDecoration(
            labelText: 'Коди 6-рақама',
            prefixIcon: Icon(Icons.pin),
          ),
        ),
        FilledButton.tonal(
          onPressed: busy ? null : () => pair(input.text),
          child: const Text('Пайваст кардан'),
        ),
      ],
    );
  }
}

class ScannerPage extends StatefulWidget {
  const ScannerPage({super.key});
  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  bool done = false;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Сканери QR')),
    body: MobileScanner(
      onDetect: (capture) {
        final value = capture.barcodes.firstOrNull?.rawValue;
        if (!done && value != null) {
          done = true;
          Navigator.pop(context, value);
        }
      },
    ),
  );
}

class FamilyMap extends StatefulWidget {
  const FamilyMap({
    super.key,
    required this.family,
    required this.uid,
    required this.parent,
  });
  final String? family;
  final String uid;
  final bool parent;

  @override
  State<FamilyMap> createState() => _FamilyMapState();
}

class _FamilyMapState extends State<FamilyMap> {
  String? selectedChild;

  @override
  Widget build(BuildContext context) {
    if (!widget.parent) return LocationView(childUid: widget.uid);
    if (widget.family == null) {
      return const Center(child: Text('Оила ҳоло сохта нашудааст'));
    }
    return StreamBuilder<DatabaseEvent>(
      stream: db('families/${widget.family}/children').onValue,
      builder: (_, snap) {
        final map = snap.data?.snapshot.value as Map?;
        if (map == null || map.isEmpty) {
          return const Center(child: Text('Аввал фарзандро пайваст кунед'));
        }
        final ids = map.keys.map((key) => key.toString()).toList();
        final active = ids.contains(selectedChild) ? selectedChild! : ids.first;
        return Column(
          children: [
            if (ids.length > 1)
              SizedBox(
                height: 66,
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                  scrollDirection: Axis.horizontal,
                  itemCount: ids.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (_, index) {
                    final childUid = ids[index];
                    return StreamBuilder<DatabaseEvent>(
                      stream: db('profiles/$childUid').onValue,
                      builder: (_, childSnap) {
                        final data = childSnap.data?.snapshot.value as Map?;
                        return ChoiceChip(
                          selected: childUid == active,
                          avatar: const Icon(Icons.child_care_rounded),
                          label: Text(
                            data?['displayName']?.toString() ?? 'Фарзанд',
                          ),
                          onSelected: (_) =>
                              setState(() => selectedChild = childUid),
                        );
                      },
                    );
                  },
                ),
              ),
            Expanded(child: LocationView(childUid: active)),
          ],
        );
      },
    );
  }
}

class LocationView extends StatefulWidget {
  const LocationView({super.key, required this.childUid});
  final String childUid;
  @override
  State<LocationView> createState() => _LocationViewState();
}

class _LocationViewState extends State<LocationView> {
  final controller = MapController();
  LatLng? shownPoint;
  Map<String, dynamic>? serverLocation;
  String? serverName;
  Timer? serverRefreshTimer;

  @override
  void initState() {
    super.initState();
    unawaited(_loadServerLocation());
    serverRefreshTimer = Timer.periodic(
      const Duration(seconds: 12),
      (_) => _loadServerLocation(),
    );
  }

  Future<void> _loadServerLocation() async {
    try {
      final api = await NigohApi.current('parent');
      if (api == null) return;
      final snapshot = await api.snapshot();
      final child = (snapshot['children'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .firstWhere(
            (item) => item['firebase_uid']?.toString() == widget.childUid,
            orElse: () => <String, dynamic>{},
          );
      final rawLocation = child['location'];
      if (!mounted || rawLocation is! Map) return;
      setState(() {
        serverName = child['name']?.toString();
        serverLocation = Map<String, dynamic>.from(rawLocation);
      });
    } catch (_) {}
  }

  @override
  void didUpdateWidget(covariant LocationView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.childUid != widget.childUid) {
      serverLocation = null;
      unawaited(_loadServerLocation());
    }
  }

  @override
  void dispose() {
    serverRefreshTimer?.cancel();
    super.dispose();
  }

  String ageLabel(Object? value) {
    DateTime? updatedAt;
    if (value is num) {
      final stamp = value.toInt();
      updatedAt = DateTime.fromMillisecondsSinceEpoch(
        stamp < 100000000000 ? stamp * 1000 : stamp,
      );
    } else if (value is String) {
      updatedAt = DateTime.tryParse(value)?.toLocal();
    }
    if (updatedAt == null) return 'Вақти навсозӣ номаълум';
    final age = DateTime.now().difference(updatedAt);
    if (age.isNegative) return 'Ҳозир нав шуд';
    if (age.inSeconds < 60) return 'Ҳозир нав шуд';
    if (age.inMinutes < 60) return '${age.inMinutes} дақиқа пеш';
    return '${age.inHours} соат пеш';
  }

  void follow(LatLng point) {
    if (shownPoint == point) return;
    shownPoint = point;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        try {
          controller.move(point, 16);
        } catch (_) {}
      }
    });
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<DatabaseEvent>(
    stream: db('profiles/${widget.childUid}').onValue,
    builder: (_, profileSnap) {
      final profile = profileSnap.data?.snapshot.value as Map?;
      final name =
          profile?['displayName']?.toString() ?? serverName ?? 'Фарзанд';
      return StreamBuilder<DatabaseEvent>(
        stream: db('locations/${widget.childUid}').onValue,
        builder: (_, snap) {
          final firebaseData = snap.data?.snapshot.value as Map?;
          final firebaseLat = (firebaseData?['lat'] as num?)?.toDouble();
          final firebaseLng = (firebaseData?['lng'] as num?)?.toDouble();
          final data = firebaseLat != null && firebaseLng != null
              ? firebaseData
              : serverLocation;
          final lat = (data?['lat'] as num?)?.toDouble();
          final lng =
              (data?['lng'] as num?)?.toDouble() ??
              (data?['longitude'] as num?)?.toDouble();
          final normalizedLat = lat ?? (data?['latitude'] as num?)?.toDouble();
          if (normalizedLat == null || lng == null) {
            final status = profile?['locationStatus']?.toString();
            final help = switch (status) {
              'gps_off' => 'GPS дар телефони фарзанд хомӯш аст.',
              'permission_denied' => 'Иҷозати Location дода нашудааст. Дар Settings → Apps → NIGOH Family → Permissions онро фаъол кунед.',
              'stream_error' => 'Пайвасти ҷойгиршавӣ қатъ шуд. Барномаро дар телефони фарзанд кушоед ва GPS-ро санҷед.',
              _ =>
                'Дар телефони фарзанд GPS ва иҷозати Location-ро фаъол кунед.',
            };
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: EmptyCard(
                  icon: Icons.location_searching,
                  title: 'Ҷойгиршавии $name интизор аст',
                  text: '$help Харита танҳо координатаи воқеиро нишон медиҳад.',
                ),
              ),
            );
          }
          final point = LatLng(normalizedLat, lng);
          final online = data?['online'] == true;
          follow(point);
          return Stack(
            children: [
              FlutterMap(
                mapController: controller,
                options: MapOptions(initialCenter: point, initialZoom: 16),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'tj.nigoh.nigoh_family_parent',
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: point,
                        width: 76,
                        height: 76,
                        child: Container(
                          decoration: BoxDecoration(
                            color: online
                                ? const Color(0xFF1667FF)
                                : Colors.orange,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 4),
                            boxShadow: const [
                              BoxShadow(blurRadius: 18, color: Colors.black26),
                            ],
                          ),
                          child: const Icon(
                            Icons.child_care,
                            color: Colors.white,
                            size: 36,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const RichAttributionWidget(
                    attributions: [
                      TextSourceAttribution('© OpenStreetMap contributors'),
                    ],
                  ),
                ],
              ),
              Positioned(
                left: 16,
                right: 16,
                top: 16,
                child: Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: online
                          ? const Color(0xFFE5F8F2)
                          : const Color(0xFFFFF1DE),
                      child: Icon(
                        online ? Icons.location_on : Icons.location_history,
                        color: online ? Colors.green : Colors.orange,
                      ),
                    ),
                    title: Text(
                      '$name • ${online ? 'онлайн' : 'охирин ҷой'}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text(
                      '${ageLabel(data?['updatedAt'] ?? data?['updated_at'])} • дақиқӣ ${(data?['accuracy'] as num?)?.round() ?? 0} м\n${normalizedLat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}',
                    ),
                    isThreeLine: true,
                    trailing: IconButton(
                      tooltip: 'Ба ҷой гузаред',
                      onPressed: () => controller.move(point, 17),
                      icon: const Icon(Icons.my_location),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      );
    },
  );
}

class LegacyChatPage extends StatelessWidget {
  const LegacyChatPage({
    super.key,
    required this.family,
    required this.uid,
    required this.profile,
    required this.parent,
  });
  final String? family, uid;
  final Map<String, dynamic> profile;
  final bool parent;

  Future<Map<String, dynamic>> _serverSnapshot() async {
    try {
      final api = await NigohApi.current(parent ? 'parent' : 'child');
      return api == null ? <String, dynamic>{} : await api.snapshot();
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  @override
  Widget build(BuildContext context) {
    if (family == null) {
      return FutureBuilder<Map<String, dynamic>>(
        future: _serverSnapshot(),
        builder: (_, snapshot) {
          final children = (snapshot.data?['children'] as List? ?? const [])
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList();
          if (parent && children.isNotEmpty) {
            return ListView(
              padding: const EdgeInsets.all(14),
              children: [
                const Text(
                  'Паёмҳо',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 10),
                ...children.map(
                  (child) => ServerChatPeerTile(
                    family: 'server',
                    child: child,
                    currentUid: uid!,
                    currentName:
                        profile['displayName']?.toString() ?? 'Волидайн',
                  ),
                ),
              ],
            );
          }
          return const Center(
            child: Text('Барои чат аввал ба оила пайваст шавед'),
          );
        },
      );
    }
    if (!parent) {
      return StreamBuilder<DatabaseEvent>(
        stream: db('families/$family/parentUid').onValue,
        builder: (_, snap) {
          final parentUid = snap.data?.snapshot.value?.toString();
          if (parentUid == null) {
            return FutureBuilder<Map<String, dynamic>>(
              future: _serverSnapshot(),
              builder: (_, serverSnap) {
                final child = serverSnap.data?['child'] as Map?;
                final serverParent = child?['parent_firebase_uid']?.toString();
                if (serverParent == null || serverParent.isEmpty) {
                  return const LoadingPage();
                }
                return ConversationPage(
                  family: family!,
                  childUid: uid!,
                  currentUid: uid!,
                  currentName: profile['displayName']?.toString() ?? 'Фарзанд',
                  peerUid: serverParent,
                );
              },
            );
          }
          return ConversationPage(
            family: family!,
            childUid: uid!,
            currentUid: uid!,
            currentName: profile['displayName']?.toString() ?? 'Фарзанд',
            peerUid: parentUid,
          );
        },
      );
    }
    return StreamBuilder<DatabaseEvent>(
      stream: db('families/$family/children').onValue,
      builder: (_, snap) {
        final children = snap.data?.snapshot.value as Map?;
        if (children == null || children.isEmpty) {
          return FutureBuilder<Map<String, dynamic>>(
            future: _serverSnapshot(),
            builder: (_, serverSnap) {
              final serverChildren =
                  (serverSnap.data?['children'] as List? ?? const [])
                      .whereType<Map>()
                      .map((item) => Map<String, dynamic>.from(item))
                      .toList();
              if (serverChildren.isEmpty) {
                return const Center(
                  child: Text('Аввал фарзандро пайваст кунед'),
                );
              }
              return ListView(
                padding: const EdgeInsets.all(14),
                children: [
                  const Text(
                    'Паёмҳо',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 10),
                  ...serverChildren.map(
                    (child) => ServerChatPeerTile(
                      family: family!,
                      child: child,
                      currentUid: uid!,
                      currentName:
                          profile['displayName']?.toString() ?? 'Волидайн',
                    ),
                  ),
                ],
              );
            },
          );
        }
        return ListView(
          padding: EdgeInsets.zero,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Паёмҳо',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Icon(Icons.edit_square, size: 25),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: TextField(
                readOnly: true,
                decoration: InputDecoration(
                  hintText: 'Ҷустуҷӯ',
                  prefixIcon: Icon(Icons.search_rounded),
                  isDense: true,
                ),
              ),
            ),
            ...children.keys.map(
              (childUid) => ChatPeerTile(
                family: family!,
                childUid: childUid.toString(),
                currentUid: uid!,
                currentName: profile['displayName']?.toString() ?? 'Волидайн',
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Server-first chat hub. Firebase RTDB is kept only as a compatibility
/// fallback for families created by older releases.
class ChatPage extends StatefulWidget {
  const ChatPage({
    super.key,
    required this.family,
    required this.uid,
    required this.profile,
    required this.parent,
  });

  final String? family, uid;
  final Map<String, dynamic> profile;
  final bool parent;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  late Future<Map<String, dynamic>> snapshotFuture;
  Timer? refreshTimer;

  @override
  void initState() {
    super.initState();
    snapshotFuture = _loadSnapshot();
    refreshTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _refreshSnapshot(),
    );
  }

  Future<Map<String, dynamic>> _loadSnapshot() async {
    try {
      final api = await NigohApi.current(widget.parent ? 'parent' : 'child');
      return api == null ? <String, dynamic>{} : await api.snapshot();
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  void _refreshSnapshot() {
    if (!mounted) return;
    setState(() => snapshotFuture = _loadSnapshot());
  }

  @override
  void dispose() {
    refreshTimer?.cancel();
    super.dispose();
  }

  Widget _serverParentList(
    BuildContext context,
    List<Map<String, dynamic>> children,
  ) {
    final currentUid = widget.uid ?? '';
    return RefreshIndicator(
      onRefresh: () async => _refreshSnapshot(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Паёмҳо',
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
              IconButton(
                tooltip: 'Навсозӣ',
                onPressed: _refreshSnapshot,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Гуфтугӯи бехатар бо аъзои оила тавассути сервери NIGOH',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface
                  .withValues(alpha: .65),
            ),
          ),
          const SizedBox(height: 16),
          ...children.map(
            (child) => Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ServerChatPeerTile(
                family: 'server',
                child: child,
                currentUid: currentUid,
                currentName:
                    widget.profile['displayName']?.toString() ?? 'Волидайн',
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
    future: snapshotFuture,
    builder: (_, snapshot) {
      final data = snapshot.data ?? const <String, dynamic>{};
      if (widget.parent) {
        final children = (data['children'] as List? ?? const [])
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .where(
              (child) => (child['firebase_uid']?.toString() ?? '').isNotEmpty,
            )
            .toList();
        if (children.isNotEmpty) return _serverParentList(context, children);
      } else {
        final child = data['child'] is Map
            ? Map<String, dynamic>.from(data['child'] as Map)
            : const <String, dynamic>{};
        final parentUid = child['parent_firebase_uid']?.toString() ?? '';
        if (parentUid.isNotEmpty && widget.uid != null) {
          return ConversationPage(
            family: widget.family ?? 'server',
            childUid: widget.uid!,
            currentUid: widget.uid!,
            currentName: widget.profile['displayName']?.toString() ?? 'Фарзанд',
            peerUid: parentUid,
          );
        }
      }
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(child: CircularProgressIndicator());
      }
      return LegacyChatPage(
        family: widget.family,
        uid: widget.uid,
        profile: widget.profile,
        parent: widget.parent,
      );
    },
  );
}

class ChatPeerTile extends StatelessWidget {
  const ChatPeerTile({
    super.key,
    required this.family,
    required this.childUid,
    required this.currentUid,
    required this.currentName,
  });
  final String family, childUid, currentUid, currentName;

  @override
  Widget build(BuildContext context) => StreamBuilder<DatabaseEvent>(
    stream: db('profiles/$childUid').onValue,
    builder: (_, profileSnap) {
      final peer = profileSnap.data?.snapshot.value as Map?;
      final name = peer?['displayName']?.toString() ?? 'Фарзанд';
      final online = peer?['online'] == true;
      return StreamBuilder<DatabaseEvent>(
        stream: db('conversations/$family/$childUid/messages')
            .orderByChild('createdAt')
            .limitToLast(1)
            .onValue,
        builder: (_, messageSnap) {
          final messages = messageSnap.data?.snapshot.value as Map?;
          final last = messages?.values.firstOrNull as Map?;
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 6,
            ),
            leading: _ProfileRing(name: name, online: online, size: 58),
            title: Text(
              name,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: Text(
              last?['text']?.toString() ??
                  (online ? 'Онлайн • Салом нависед' : 'Офлайн'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: const Icon(Icons.camera_alt_outlined, size: 24),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => Scaffold(
                  body: SafeArea(
                    child: ConversationPage(
                      family: family,
                      childUid: childUid,
                      currentUid: currentUid,
                      currentName: currentName,
                      peerUid: childUid,
                      canGoBack: true,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

class ServerChatPeerTile extends StatelessWidget {
  const ServerChatPeerTile({
    super.key,
    required this.family,
    required this.child,
    required this.currentUid,
    required this.currentName,
  });

  final String family;
  final Map<String, dynamic> child;
  final String currentUid;
  final String currentName;

  @override
  Widget build(BuildContext context) {
    final childUid = child['firebase_uid']?.toString() ?? '';
    final name = child['name']?.toString() ?? 'Фарзанд';
    final online = child['is_online'] == 1 || child['is_online'] == true;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 5),
      leading: _ProfileRing(name: name, online: online, size: 54),
      title: Text(name, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text(
        online ? 'Онлайн • сервери NIGOH' : 'Офлайн • охирин ҳолат',
      ),
      trailing: const Icon(Icons.chat_bubble_outline_rounded),
      onTap: childUid.isEmpty
          ? null
          : () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => Scaffold(
                  body: SafeArea(
                    child: ConversationPage(
                      family: family,
                      childUid: childUid,
                      currentUid: currentUid,
                      currentName: currentName,
                      peerUid: childUid,
                      canGoBack: true,
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

class ConversationPage extends StatefulWidget {
  const ConversationPage({
    super.key,
    required this.family,
    required this.childUid,
    required this.currentUid,
    required this.currentName,
    required this.peerUid,
    this.canGoBack = false,
  });
  final String family, childUid, currentUid, currentName, peerUid;
  final bool canGoBack;
  @override
  State<ConversationPage> createState() => _ConversationPageState();
}

class _ConversationPageState extends State<ConversationPage> {
  final input = TextEditingController();
  final scroll = ScrollController();
  bool sending = false;
  bool authChecking = true;
  bool authValid = false;
  bool serverLoading = false;
  int? serverChildId;
  String? serverError;
  List<Map<String, dynamic>> serverMessages = <Map<String, dynamic>>[];
  Timer? serverRefreshTimer;

  @override
  void initState() {
    super.initState();
    unawaited(_refreshAuth());
    unawaited(_loadServerMessages());
    serverRefreshTimer = Timer.periodic(
      const Duration(seconds: 4),
      (_) => _loadServerMessages(),
    );
  }

  Future<void> _loadServerMessages() async {
    if (serverLoading) return;
    serverLoading = true;
    try {
      final role = widget.currentUid == widget.childUid ? 'child' : 'parent';
      final api = await NigohApi.current(role);
      if (api == null) return;
      final childId = await _resolveServerChildId(api, role);
      if (childId == null) return;
      final messages = await api.chat(childId);
      final isChild = role == 'child';
      final normalized = messages.map((item) {
        final senderRole = item['sender_role']?.toString() ?? '';
        final mine = senderRole == (isChild ? 'child' : 'parent');
        return <String, dynamic>{
          'id': item['id'],
          'senderRole': senderRole,
          'senderUid': mine ? widget.currentUid : widget.peerUid,
          'senderName': item['sender_name']?.toString() ?? '',
          'text': item['content']?.toString() ?? '',
          'createdAt': item['created_at']?.toString() ?? '',
        };
      }).toList();
      if (mounted) {
        setState(() {
          serverMessages = normalized;
          serverError = null;
        });
      }
    } catch (error) {
      if (mounted) setState(() => serverError = error.toString());
    } finally {
      serverLoading = false;
    }
  }

  Future<int?> _resolveServerChildId(NigohApi api, String role) async {
    if (serverChildId != null) return serverChildId;
    final snapshot = await api.snapshot();
    var rawChild = role == 'child'
        ? snapshot['child']
        : (snapshot['children'] as List? ?? const [])
              .whereType<Map>()
              .firstWhere(
                (item) => item['firebase_uid']?.toString() == widget.childUid,
                orElse: () => <String, dynamic>{},
              );
    if (role == 'child' &&
        rawChild is Map &&
        (rawChild['parent_firebase_uid']?.toString() ?? '').isEmpty &&
        widget.peerUid.isNotEmpty) {
      // A Firebase-only family may predate the FastAPI data plane. Link it
      // when chat first opens, after the parent has authenticated to FastAPI.
      await api.linkExisting(widget.peerUid);
      rawChild = (await api.snapshot())['child'];
    }
    if (rawChild is Map) {
      serverChildId = (rawChild['id'] as num?)?.toInt();
    }
    return serverChildId;
  }

  @override
  void didUpdateWidget(covariant ConversationPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentUid != widget.currentUid) {
      unawaited(_refreshAuth());
    }
  }

  Future<bool> _refreshAuth() async {
    if (mounted) setState(() => authChecking = true);
    final user = FirebaseAuth.instance.currentUser;
    var valid = false;
    if (user != null && user.uid == widget.currentUid) {
      try {
        await user.getIdToken(true);
        valid = true;
      } catch (_) {
        valid = false;
      }
    }
    if (mounted) {
      setState(() {
        authValid = valid;
        authChecking = false;
      });
    }
    return valid;
  }

  Future<void> send() async {
    final text = input.text.trim();
    if (text.isEmpty || sending) return;
    if (!authValid && !await _refreshAuth()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Хатогӣ дар пайвастшавӣ. Аз нав ворид шавед.'),
          ),
        );
      }
      return;
    }
    setState(() => sending = true);
    try {
      var sentToApi = false;
      Object? apiError;
      try {
        final role = widget.currentUid == widget.childUid ? 'child' : 'parent';
        final api = await NigohApi.current(role);
        if (api != null) {
          final childId = await _resolveServerChildId(api, role);
          if (childId != null) {
            await api.sendChat(childId, text);
            sentToApi = true;
            input.clear();
            await _loadServerMessages();
          }
        }
      } catch (error) {
        apiError = error;
        // Firebase remains a compatibility fallback if the API is temporarily
        // unavailable during migration.
      }
      if (sentToApi) return;
      if (widget.family == 'server') {
        throw apiError ??
            const NigohApiException(
              'Чат ба сервер пайваст нашуд. Дубора кӯшиш кунед.',
            );
      }
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || user.uid != widget.currentUid) {
        throw FirebaseException(
          plugin: 'firebase_auth',
          code: 'unauthenticated',
        );
      }
      await user.getIdToken(true);
      await db('conversations/${widget.family}/${widget.childUid}/messages')
          .push()
          .set({
            'senderUid': widget.currentUid,
            'senderName': widget.currentName,
            'recipientUid': widget.peerUid,
            'childUid': widget.childUid,
            'text': text,
            'createdAt': ServerValue.timestamp,
            'delivered': false,
          });
      input.clear();
    } on FirebaseException catch (error) {
      if (!mounted) return;
      final denied = error.code.toLowerCase().contains('permission');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            denied
                ? 'Хатогӣ дар пайвастшавӣ: дастрасии чат рад шуд.'
                : 'Хатогӣ дар пайвастшавӣ. Интернетро санҷед.',
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Хатогӣ дар пайвастшавӣ: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  void _openCall(BuildContext context, bool video) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CallPage(
          family: widget.family,
          childUid: widget.childUid,
          currentUid: widget.currentUid,
          currentName: widget.currentName,
          peerUid: widget.peerUid,
          video: video,
        ),
      ),
    );
  }

  @override
  void dispose() {
    input.dispose();
    scroll.dispose();
    serverRefreshTimer?.cancel();
    super.dispose();
  }

  String timeLabel(Object? value) {
    DateTime? date;
    if (value is num) {
      date = DateTime.fromMillisecondsSinceEpoch(value.toInt());
    } else if (value is String) {
      date = DateTime.tryParse(value)?.toLocal();
    }
    if (date == null) return '';
    return TimeOfDay.fromDateTime(date).format(context);
  }

  @override
  Widget build(BuildContext context) {
    if (authChecking) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!authValid) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Сессия ба охир расид. Барои фаъол шудани чат аз нав ворид шавед.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () => unawaited(_refreshAuth()),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Аз нав санҷидан'),
              ),
            ],
          ),
        ),
      );
    }
    return StreamBuilder<DatabaseEvent>(
      stream: db('profiles/${widget.peerUid}').onValue,
      builder: (_, peerSnap) {
        final peer = peerSnap.data?.snapshot.value as Map?;
        final peerName = peer?['displayName']?.toString() ?? 'Оила';
        final online = peer?['online'] == true;
        final scheme = Theme.of(context).colorScheme;
        return Column(
          children: [
            Material(
              color: Theme.of(context).colorScheme.surface,
              child: Container(
                height: 66,
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: scheme.outlineVariant, width: .7),
                  ),
                ),
                child: Row(
                  children: [
                    if (widget.canGoBack)
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back_rounded),
                      )
                    else
                      const SizedBox(width: 12),
                    _ProfileRing(name: peerName, online: online, size: 42),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            peerName,
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          StreamBuilder<DatabaseEvent>(
                            stream: db('.info/connected').onValue,
                            builder: (_, connectedSnap) {
                              final connected =
                                  connectedSnap.data?.snapshot.value == true;
                              return Text(
                                connected
                                    ? (online ? 'Онлайн' : 'Офлайн')
                                    : 'Пайвастшавӣ…',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context).colorScheme.onSurface
                                      .withValues(alpha: .62),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Занги овозӣ',
                      onPressed: () => _openCall(context, false),
                      icon: const Icon(Icons.call_outlined),
                    ),
                    IconButton(
                      tooltip: 'Занги видеоӣ',
                      onPressed: () => _openCall(context, true),
                      icon: const Icon(Icons.videocam_outlined),
                    ),
                    const SizedBox(width: 16),
                  ],
                ),
              ),
            ),
            Expanded(
              child: StreamBuilder<DatabaseEvent>(
                stream: widget.family == 'server'
                    ? const Stream<DatabaseEvent>.empty()
                    : db(
                        'conversations/${widget.family}/${widget.childUid}/messages',
                      ).orderByChild('createdAt').limitToLast(100).onValue,
                builder: (_, snap) {
                  if (snap.hasError && serverMessages.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Чат ба сервер пайваст нашуд. Интернетро санҷед ва дубора кӯшиш кунед.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }
                  final raw = snap.data?.snapshot.value as Map?;
                  if (raw == null && serverMessages.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            serverError ??
                                'Шумо бо $peerName суҳбат мекунед\nСалом нависед 👋',
                            textAlign: TextAlign.center,
                          ),
                          if (serverError != null)
                            TextButton.icon(
                              onPressed: () => unawaited(_loadServerMessages()),
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('Аз нав кӯшиш кардан'),
                            ),
                        ],
                      ),
                    );
                  }
                  final firebaseMessages = raw == null
                      ? const <Map<String, dynamic>>[]
                      : raw.values
                            .whereType<Map>()
                            .map((value) => Map<String, dynamic>.from(value))
                            .toList();
                  final items = UserJourneyLogic.mergeMessages(
                    firebaseMessages,
                    serverMessages,
                  );
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (scroll.hasClients) {
                      scroll.jumpTo(scroll.position.maxScrollExtent);
                    }
                  });
                  return DecoratedBox(
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: .025),
                    ),
                    child: ListView.builder(
                      controller: scroll,
                      padding: const EdgeInsets.fromLTRB(12, 18, 12, 12),
                      itemCount: items.length,
                      itemBuilder: (_, i) {
                        final item = items[i];
                        final mine = item['senderUid'] == widget.currentUid;
                        return Align(
                          alignment: mine
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (!mine) ...[
                                _ProfileRing(
                                  name: peerName,
                                  online: online,
                                  size: 30,
                                ),
                                const SizedBox(width: 6),
                              ],
                              Container(
                                margin: const EdgeInsets.only(bottom: 9),
                                padding: const EdgeInsets.fromLTRB(
                                  14,
                                  9,
                                  10,
                                  7,
                                ),
                                constraints: BoxConstraints(
                                  maxWidth:
                                      MediaQuery.sizeOf(context).width * .72,
                                ),
                                decoration: BoxDecoration(
                                  color: mine
                                      ? scheme.primary
                                      : scheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(19),
                                    topRight: const Radius.circular(19),
                                    bottomLeft: Radius.circular(mine ? 19 : 5),
                                    bottomRight: Radius.circular(mine ? 5 : 19),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: scheme.shadow.withValues(
                                        alpha: .07,
                                      ),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    if (!mine)
                                      Text(
                                        item['senderName']?.toString() ??
                                            peerName,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          color: scheme.primary,
                                        ),
                                      ),
                                    Text(
                                      item['text']?.toString() ?? '',
                                      style: TextStyle(
                                        color: mine
                                            ? scheme.onPrimary
                                            : scheme.onSurface,
                                      ),
                                    ),
                                    Text(
                                      '${timeLabel(item['createdAt'])}${mine ? '  ✓✓' : ''}',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: mine
                                            ? scheme.onPrimary.withValues(
                                                alpha: .70,
                                              )
                                            : scheme.onSurface.withValues(
                                                alpha: .46,
                                              ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
            SafeArea(
              top: false,
              child: Container(
                color: Theme.of(context).colorScheme.surface,
                padding: const EdgeInsets.fromLTRB(12, 7, 12, 9),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: scheme.outlineVariant),
                          borderRadius: BorderRadius.circular(28),
                        ),
                        child: TextField(
                          controller: input,
                          maxLength: 1000,
                          minLines: 1,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            counterText: '',
                            hintText: 'Паём нависед…',
                            prefixIcon: Icon(
                              Icons.camera_alt_rounded,
                              color: Color(0xFF0095F6),
                            ),
                            filled: false,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                          ),
                          onSubmitted: (_) => send(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: sending ? null : send,
                      icon: sending
                          ? const SizedBox.square(
                              dimension: 19,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send_rounded),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class CallPage extends StatefulWidget {
  const CallPage({
    super.key,
    required this.family,
    required this.childUid,
    required this.currentUid,
    required this.currentName,
    required this.peerUid,
    required this.video,
  });
  final String family, childUid, currentUid, currentName, peerUid;
  final bool video;

  @override
  State<CallPage> createState() => _CallPageState();
}

class _CallPageState extends State<CallPage> {
  late final String callId = db('calls/${widget.family}/${widget.childUid}')
      .push()
      .key!;
  bool connecting = true;

  DatabaseReference get callRef =>
      db('calls/${widget.family}/${widget.childUid}/$callId');

  @override
  void initState() {
    super.initState();
    callRef.set({
      'callerUid': widget.currentUid,
      'callerName': widget.currentName,
      'peerUid': widget.peerUid,
      'type': widget.video ? 'video' : 'voice',
      'status': 'ringing',
      'createdAt': ServerValue.timestamp,
    });
  }

  Future<void> end() async {
    await callRef.update({'status': 'ended', 'endedAt': ServerValue.timestamp});
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.video ? 'Занги видеоӣ' : 'Занги овозӣ')),
    body: StreamBuilder<DatabaseEvent>(
      stream: callRef.onValue,
      builder: (_, snap) {
        final data = snap.data?.snapshot.value as Map?;
        final status = data?['status']?.toString() ?? 'ringing';
        if (status == 'ended') {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) Navigator.pop(context);
          });
        }
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 54,
                  backgroundColor: const Color(0xFFDCEBFF),
                  child: Icon(
                    widget.video ? Icons.videocam_rounded : Icons.call_rounded,
                    color: const Color(0xFF1769E0),
                    size: 46,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Пайвастшавӣ ба ${widget.currentName == data?['callerName'] ? 'оила' : 'ҳамсуҳбат'}…',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  status == 'ringing'
                      ? 'Дар телефони дигар огоҳии занг фиристода шуд.'
                      : 'Занг фаъол аст',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 28),
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: end,
                  icon: const Icon(Icons.call_end_rounded),
                  label: const Text('Анҷом додани занг'),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

class AppControlPage extends StatefulWidget {
  const AppControlPage({super.key, required this.family});
  final String? family;
  @override
  State<AppControlPage> createState() => _AppControlPageState();
}

class _AppControlPageState extends State<AppControlPage> {
  String? selectedChild;
  List<Map<String, dynamic>> serverChildren = <Map<String, dynamic>>[];
  Timer? serverRefreshTimer;

  @override
  void initState() {
    super.initState();
    unawaited(_loadServerChildren());
    serverRefreshTimer = Timer.periodic(
      const Duration(seconds: 12),
      (_) => _loadServerChildren(),
    );
  }

  Future<void> _loadServerChildren() async {
    try {
      final api = await NigohApi.current('parent');
      if (api == null) return;
      final raw = await api.snapshot();
      final children = (raw['children'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .where((item) => (item['firebase_uid']?.toString() ?? '').isNotEmpty)
          .toList();
      if (mounted) setState(() => serverChildren = children);
    } catch (_) {}
  }

  @override
  void dispose() {
    serverRefreshTimer?.cancel();
    super.dispose();
  }

  Widget _serverFallbackPanel() {
    if (serverChildren.isEmpty) {
      return const Center(
        child: EmptyCard(
          icon: Icons.link_off_rounded,
          title: 'Фарзанд ҳоло дар сервер пайваст нест',
          text: 'Аз телефони фарзанд барномаро кушоед, баъд QR ё рамзи 6-рақамаро аз нав пайваст кунед.',
        ),
      );
    }
    final ids = serverChildren
        .map((item) => item['firebase_uid']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toList();
    final active = ids.contains(selectedChild) ? selectedChild! : ids.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(18, 18, 18, 8),
          child: Text(
            'Назорати барномаҳо',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Text(
            'Маълумот аз сервери NIGOH • бе вобастагӣ аз хатои Firebase Database',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface
                  .withValues(alpha: .65),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(child: ChildAppsList(childUid: active)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.family == null) {
      return _serverFallbackPanel();
    }
    final scheme = Theme.of(context).colorScheme;
    return StreamBuilder<DatabaseEvent>(
      stream: db('families/${widget.family}/children').onValue,
      builder: (_, snap) {
        final children = snap.data?.snapshot.value as Map?;
        if (children == null || children.isEmpty) {
          return _serverFallbackPanel();
        }
        final ids = children.keys.map((e) => e.toString()).toList();
        if (selectedChild == null || !ids.contains(selectedChild)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => selectedChild = ids.first);
          });
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Назорати барномаҳо',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: scheme.onSurface,
                          ),
                        ),
                      ),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFDBEAFE)),
                        ),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          child: Text(
                            'NIGOH SHIELD',
                            style: TextStyle(
                              color: NigohDesign.blue,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Лимит, қулф ва Homework Mode — ҳамааш дар як ҷо.',
                    style: TextStyle(
                      color: scheme.onSurface.withValues(alpha: .65),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ids
                          .map(
                            (id) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: StreamBuilder<DatabaseEvent>(
                                stream: db('profiles/$id').onValue,
                                builder: (_, profileSnap) {
                                  final profile =
                                      profileSnap.data?.snapshot.value as Map?;
                                  return ChoiceChip(
                                    selected: selectedChild == id,
                                    label: Text(
                                      profile?['displayName']?.toString() ??
                                          'Фарзанд',
                                    ),
                                    avatar: const Icon(Icons.child_care),
                                    onSelected: (_) =>
                                        setState(() => selectedChild = id),
                                  );
                                },
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: selectedChild == null
                  ? const LoadingPage()
                  : ChildAppsList(childUid: selectedChild!),
            ),
          ],
        );
      },
    );
  }
}

class _ScreenTimeOverview extends StatelessWidget {
  const _ScreenTimeOverview({
    required this.usedMinutes,
    required this.limitMinutes,
    required this.blockedCount,
  });

  final int usedMinutes;
  final int limitMinutes;
  final int blockedCount;

  String _duration(int minutes) {
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    if (hours == 0) return '$rest дақ';
    return rest == 0 ? '$hours соат' : '$hoursс $restд';
  }

  @override
  Widget build(BuildContext context) {
    final progress = limitMinutes > 0
        ? (usedMinutes / limitMinutes).clamp(0.0, 1.0)
        : 0.0;
    final scheme = Theme.of(context).colorScheme;
    final ringColor = progress >= 1
        ? NigohDesign.coral
        : progress >= .75
        ? NigohDesign.amber
        : NigohDesign.blue;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            NigohDesign.blue.withValues(alpha: .10),
            NigohDesign.violet.withValues(alpha: .08),
            NigohDesign.mint.withValues(alpha: .08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: NigohDesign.blue.withValues(alpha: .18)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 96,
            height: 96,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 9,
                    strokeCap: StrokeCap.round,
                    backgroundColor: ringColor.withValues(alpha: .14),
                    color: ringColor,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${(progress * 100).round()}%',
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'истифода',
                      style: TextStyle(
                        color: scheme.onSurface.withValues(alpha: .65),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Вақти умумии экран',
                  style: TextStyle(
                    color: scheme.onSurface.withValues(alpha: .65),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _duration(usedMinutes),
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: 25,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '${_duration((limitMinutes - usedMinutes).clamp(0, limitMinutes))} боқӣ',
                  style: TextStyle(
                    color: ringColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _SummaryPill(
                      icon: Icons.lock_outline,
                      text: '$blockedCount маҳкам',
                      color: cyberRed,
                    ),
                    const SizedBox(width: 8),
                    const _SummaryPill(
                      icon: Icons.shield_outlined,
                      text: 'Offline Shield',
                      color: cyberGreen,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryPill extends StatelessWidget {
  const _SummaryPill({
    required this.icon,
    required this.text,
    required this.color,
  });
  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Flexible(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: .35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _QuickPauseBanner extends StatelessWidget {
  const _QuickPauseBanner({required this.active, required this.onChanged});
  final bool active;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: active
            ? scheme.error.withValues(alpha: .10)
            : scheme.primary.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: active
              ? scheme.error.withValues(alpha: .55)
              : scheme.primary.withValues(alpha: .24),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.pause_circle_filled,
            color: active ? scheme.error : scheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Ҳолати танаффус',
              style: TextStyle(
                color: scheme.onSurface,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Switch.adaptive(
            value: active,
            onChanged: onChanged,
            activeThumbColor: scheme.error,
          ),
        ],
      ),
    );
  }
}

class AppDetailRulesSheet extends StatefulWidget {
  const AppDetailRulesSheet({
    super.key,
    required this.childUid,
    required this.ruleKey,
    required this.app,
    required this.rule,
  });

  final String childUid;
  final String ruleKey;
  final Map<String, dynamic> app;
  final Map? rule;

  @override
  State<AppDetailRulesSheet> createState() => _AppDetailRulesSheetState();
}

class _AppDetailRulesSheetState extends State<AppDetailRulesSheet> {
  static const presets = <int>[15, 60, 90, 120, 0];
  late bool instantLock;
  late bool homework;
  late int limit;
  late TimeOfDay start;
  late TimeOfDay end;
  late Set<int> weekdays;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    final rule = widget.rule;
    final schedule = rule?['schedule'] is Map
        ? Map<String, dynamic>.from(rule!['schedule'] as Map)
        : <String, dynamic>{};
    instantLock = rule?['blocked'] == true;
    homework = schedule['enabled'] == true;
    limit = (rule?['dailyLimitMinutes'] as num?)?.toInt() ?? 90;
    start = _parseTime(
      schedule['start']?.toString(),
      const TimeOfDay(hour: 16, minute: 0),
    );
    end = _parseTime(
      schedule['end']?.toString(),
      const TimeOfDay(hour: 18, minute: 0),
    );
    weekdays = ((schedule['weekdays'] as List?) ?? const [1, 2, 3, 4, 5])
        .whereType<num>()
        .map((value) => value.toInt())
        .toSet();
  }

  TimeOfDay _parseTime(String? value, TimeOfDay fallback) {
    if (value == null) return fallback;
    final parts = value.split(':');
    final hour = int.tryParse(parts.first);
    final minute = parts.length > 1 ? int.tryParse(parts[1]) : null;
    if (hour == null || minute == null || hour > 23 || minute > 59) {
      return fallback;
    }
    return TimeOfDay(hour: hour, minute: minute);
  }

  String _formatTime(TimeOfDay value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

  String _limitLabel(int minutes) {
    if (minutes <= 0) return 'Бе лимит';
    if (minutes < 60) return '$minutes дақ';
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    return rest == 0 ? '$hours соат' : '$hours соат $rest дақ';
  }

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? start : end,
      helpText: isStart ? 'Оғози Homework Mode' : 'Анҷоми Homework Mode',
    );
    if (picked == null || !mounted) return;
    setState(() => isStart ? start = picked : end = picked);
  }

  Future<void> _save() async {
    setState(() => saving = true);
    try {
      final packageName = widget.app['packageName']?.toString() ?? '';
      final schedule = {
        'enabled': homework,
        'start': _formatTime(start),
        'end': _formatTime(end),
        'weekdays': weekdays.toList()..sort(),
      };
      var serverSaved = false;
      try {
        final api = await NigohApi.current('parent');
        if (api != null) {
          final snapshot = await api.snapshot();
          final child = (snapshot['children'] as List? ?? const [])
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .firstWhere(
                (item) => item['firebase_uid']?.toString() == widget.childUid,
                orElse: () => <String, dynamic>{},
              );
          final childId = (child['id'] as num?)?.toInt();
          if (childId != null) {
            await api.updateRule(childId, packageName, {
              'is_blocked': instantLock,
              'daily_limit_minutes': limit,
              'schedule': schedule,
            });
            serverSaved = true;
          }
        }
      } catch (_) {}
      try {
        await db('blockedApps/${widget.childUid}/${widget.ruleKey}').update({
          'packageName': packageName,
          'name': widget.app['name']?.toString() ?? '',
          'blocked': instantLock,
          'dailyLimitMinutes': limit,
          'schedule': schedule,
          'updatedAt': ServerValue.timestamp,
          'updatedBy': FirebaseAuth.instance.currentUser?.uid,
        });
      } catch (_) {
        if (!serverSaved) rethrow;
      }
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final iconBase64 = widget.app['iconBase64']?.toString() ?? '';
    final appName = widget.app['name']?.toString() ?? 'Барнома';
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
        children: [
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: scheme.onSurface.withValues(alpha: .28),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.tune_rounded, color: scheme.primary),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Қоидаҳои барнома',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: .06),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Row(
              children: [
                NigohAppIcon(
                  icon: iconBase64,
                  seed: widget.app['packageName']?.toString() ?? appName,
                  size: 60,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              appName,
                              style: const TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.verified_rounded,
                            color: cyberGreen,
                            size: 17,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.app['packageName']?.toString() ?? '',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: scheme.onSurface.withValues(alpha: .58),
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        children: [
                          _DarkTag('Фаъол', scheme.primary),
                          const _DarkTag('Муҳофизати офлайн', cyberGreen),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _RuleSection(
            icon: Icons.gpp_bad_rounded,
            color: cyberRed,
            title: 'Маҳкамсозии фаврӣ',
            subtitle: 'Барномаро дар як сония маҳкам намоед',
            trailing: Switch.adaptive(
              value: instantLock,
              onChanged: (value) => setState(() => instantLock = value),
              activeThumbColor: cyberRed,
            ),
            footer: const _DarkTag('Муҳофизат бо PIN-и волидайн', cyberRed),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Лимити рӯзонаи истифода',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${_limitLabel(limit)} / рӯз (ҳамарӯза)',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: scheme.primary,
                    ),
                  ),
                  Slider(
                    value: presets
                        .indexOf(limit)
                        .clamp(0, presets.length - 1)
                        .toDouble(),
                    min: 0,
                    max: (presets.length - 1).toDouble(),
                    divisions: presets.length - 1,
                    activeColor: scheme.primary,
                    onChanged: (value) =>
                        setState(() => limit = presets[value.round()]),
                  ),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: presets
                        .map(
                          (value) => ChoiceChip(
                            label: Text(_limitLabel(value)),
                            selected: limit == value,
                            onSelected: (_) => setState(() => limit = value),
                            selectedColor: scheme.primaryContainer,
                            backgroundColor: scheme.surface,
                            side: BorderSide(color: scheme.outlineVariant),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.menu_book_rounded, color: scheme.primary),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Ҳолати Дарстайёркунӣ',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                      Switch.adaptive(
                        value: homework,
                        onChanged: (value) => setState(() => homework = value),
                        activeThumbColor: scheme.primary,
                      ),
                    ],
                  ),
                  Text(
                    'Барнома дар ин соатҳо баста мешавад',
                    style: TextStyle(
                      color: scheme.onSurface.withValues(alpha: .62),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _TimeButton(
                          label: 'Аз соати',
                          time: start,
                          onTap: () => _pickTime(true),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Icon(
                          Icons.arrow_forward_rounded,
                          color: scheme.primary,
                        ),
                      ),
                      Expanded(
                        child: _TimeButton(
                          label: 'То соати',
                          time: end,
                          onTap: () => _pickTime(false),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    children: [1, 2, 3, 4, 5, 6, 7].map((day) {
                      const labels = ['Д', 'С', 'Ч', 'П', 'Ҷ', 'Ш', 'Я'];
                      final selected = weekdays.contains(day);
                      return ChoiceChip(
                        label: Text(labels[day - 1]),
                        selected: selected,
                        onSelected: (_) => setState(() {
                          if (selected) {
                            weekdays.remove(day);
                          } else {
                            weekdays.add(day);
                          }
                        }),
                        selectedColor: scheme.primaryContainer,
                        backgroundColor: scheme.surface,
                        side: BorderSide(color: scheme.outlineVariant),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: saving ? null : _save,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
            ),
            icon: saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check_rounded),
            label: const Text(
              'Тағйиротро захира кунед',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          TextButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.history_rounded, color: scheme.primary),
            label: Text(
              'Таърихи истифодаи 7-рӯзаро бинед',
              style: TextStyle(color: scheme.primary),
            ),
          ),
        ],
      ),
    );
  }
}

class _DarkTag extends StatelessWidget {
  const _DarkTag(this.text, this.color);
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withValues(alpha: .38)),
    ),
    child: Text(
      text,
      style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800),
    ),
  );
}

class _RuleSection extends StatelessWidget {
  const _RuleSection({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.footer,
  });
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final Widget trailing;
  final Widget footer;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface
                            .withValues(alpha: .60),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              trailing,
            ],
          ),
          const SizedBox(height: 10),
          footer,
        ],
      ),
    ),
  );
}

class _TimeButton extends StatelessWidget {
  const _TimeButton({
    required this.label,
    required this.time,
    required this.onTap,
  });
  final String label;
  final TimeOfDay time;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: scheme.onSurface,
        side: BorderSide(color: scheme.outlineVariant),
        backgroundColor: scheme.primary.withValues(alpha: .05),
        padding: const EdgeInsets.symmetric(vertical: 10),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              color: scheme.onSurface.withValues(alpha: .58),
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            time.format(context),
            style: TextStyle(
              color: scheme.primary,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _AppsLoadingSkeleton extends StatelessWidget {
  const _AppsLoadingSkeleton();

  @override
  Widget build(BuildContext context) => ListView.separated(
    padding: const EdgeInsets.fromLTRB(14, 18, 14, 22),
    itemCount: 6,
    separatorBuilder: (_, _) => const SizedBox(height: 10),
    itemBuilder: (_, _) => Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const SizedBox.square(
              dimension: 46,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.all(Radius.circular(14)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 14,
                    width: 150,
                    decoration: BoxDecoration(
                      color: Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.all(Radius.circular(7)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 10,
                    width: 220,
                    decoration: BoxDecoration(
                      color: Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.all(Radius.circular(5)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class ChildAppsList extends StatefulWidget {
  const ChildAppsList({super.key, required this.childUid});
  final String childUid;

  @override
  State<ChildAppsList> createState() => _ChildAppsListState();
}

class _ChildAppsListState extends State<ChildAppsList> {
  final search = TextEditingController();
  String query = '';
  String category = 'Ҳама';
  bool pauseActive = false;
  bool cacheLoading = true;
  bool refreshing = false;
  Map<String, dynamic> cachedApps = <String, dynamic>{};
  Map<String, dynamic> serverApps = <String, dynamic>{};
  Map<String, dynamic> serverRules = <String, dynamic>{};
  final Map<String, int> pendingLimits = <String, int>{};
  int? serverChildId;
  Timer? serverRefreshTimer;
  static const limitChoices = <int>[15, 60, 90, 120, 240, 0];
  static const categories = <String>['Ҳама', 'Маориф', 'Бозиҳо', 'Шабакаҳо'];

  String get _cacheKey => 'installed_apps_cache_${widget.childUid}';

  @override
  void initState() {
    super.initState();
    unawaited(_loadCachedApps());
    unawaited(_loadServerApps());
    serverRefreshTimer = Timer.periodic(
      const Duration(seconds: 12),
      (_) => _loadServerApps(),
    );
  }

  @override
  void didUpdateWidget(covariant ChildAppsList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.childUid != widget.childUid) {
      cachedApps = <String, dynamic>{};
      serverApps = <String, dynamic>{};
      serverRules = <String, dynamic>{};
      pendingLimits.clear();
      serverChildId = null;
      cacheLoading = true;
      unawaited(_loadCachedApps());
      unawaited(_loadServerApps());
    }
  }

  Future<void> _loadServerApps() async {
    try {
      final api = await NigohApi.current('parent');
      if (api == null) return;
      final snapshot = await api.snapshot();
      final children = (snapshot['children'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item));
      final child = children.firstWhere(
        (item) => item['firebase_uid']?.toString() == widget.childUid,
        orElse: () => <String, dynamic>{},
      );
      if (child.isEmpty) return;
      serverChildId = (child['id'] as num?)?.toInt();
      final apps = <String, dynamic>{};
      final rules = <String, dynamic>{};
      for (final raw in (child['apps'] as List? ?? const [])) {
        if (raw is! Map) continue;
        final item = Map<String, dynamic>.from(raw);
        final packageName = item['package_name']?.toString() ?? '';
        if (packageName.isEmpty) continue;
        // Older servers pre-seed placeholder apps (TikTok, PUBG…) that were
        // never reported by the phone. Only show apps the device synced.
        if (item['last_synced_at'] == null) continue;
        final key = encodedAppKey(packageName);
        apps[key] = {
          'packageName': packageName,
          'name': item['app_name']?.toString() ?? packageName,
          'appName': item['app_name']?.toString() ?? packageName,
          'iconBase64': item['app_icon']?.toString() ?? '',
          'usageMinutes': (item['usage_minutes_today'] as num?) ?? 0,
          'lastUsedAt': 0,
        };
        rules[key] = {
          'packageName': packageName,
          'name': item['app_name']?.toString() ?? packageName,
          'blocked': item['is_blocked'] == true || item['is_blocked'] == 1,
          'dailyLimitMinutes': item['daily_limit_minutes'] ?? 0,
          'schedule': item['schedule'],
        };
      }
      if (mounted) {
        setState(() {
          serverApps = apps;
          serverRules = rules;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadCachedApps() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheKey);
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          cachedApps = decoded.map(
            (key, value) => MapEntry(key.toString(), value),
          );
        }
      } catch (_) {
        cachedApps = <String, dynamic>{};
      }
    }
    if (mounted) setState(() => cacheLoading = false);
  }

  Future<void> _cacheApps(Map rawApps) async {
    final normalized = <String, dynamic>{
      for (final entry in rawApps.entries)
        entry.key.toString(): entry.value is Map
            ? Map<String, dynamic>.from(entry.value as Map)
            : entry.value,
    };
    cachedApps = normalized;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cacheKey, jsonEncode(normalized));
  }

  Future<void> _refreshApps() async {
    if (refreshing) return;
    setState(() => refreshing = true);
    try {
      final snapshot = await db('installedApps/${widget.childUid}').get();
      final raw = snapshot.value as Map?;
      if (raw != null && raw.isNotEmpty) {
        await _cacheApps(raw);
      }
      await _loadServerApps();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Навсозӣ нашуд. Пайвастшавиро санҷед.')),
        );
      }
    } finally {
      if (mounted) setState(() => refreshing = false);
    }
  }

  @override
  void dispose() {
    search.dispose();
    serverRefreshTimer?.cancel();
    super.dispose();
  }

  int _limitIndex(int minutes) => UserJourneyLogic.nearestLimitIndex(minutes);

  String _limitLabel(int minutes) => UserJourneyLogic.limitLabel(minutes);

  Future<void> _setLimit(String key, int minutes) async {
    final packageName =
        ((serverApps[key] ?? cachedApps[key]) as Map?)?['packageName']
            ?.toString();
    var serverSaved = false;
    try {
      final api = await NigohApi.current('parent');
      if (api != null && serverChildId == null) await _loadServerApps();
      final childId = serverChildId;
      if (api != null && childId != null && packageName != null) {
        await api.updateRule(childId, packageName, {
          'daily_limit_minutes': minutes,
        });
        serverSaved = true;
      }
    } catch (_) {}
    try {
      await db('blockedApps/${widget.childUid}/$key').update({
        'dailyLimitMinutes': minutes,
        'updatedAt': ServerValue.timestamp,
        'updatedBy': FirebaseAuth.instance.currentUser!.uid,
      });
    } catch (_) {
      if (!serverSaved && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Қоида нигоҳ дошта нашуд. Серверро санҷед.'),
          ),
        );
      }
    }
    if (mounted) {
      setState(() => pendingLimits.remove(key));
      if (serverSaved) unawaited(_loadServerApps());
    }
  }

  Future<void> _setBlocked(
    String key,
    String packageName,
    String appName,
    bool value,
  ) async {
    var serverSaved = false;
    try {
      final api = await NigohApi.current('parent');
      if (api != null) {
        if (serverChildId == null) await _loadServerApps();
        final childId = serverChildId;
        if (childId != null) {
          await api.updateRule(childId, packageName, {'is_blocked': value});
          serverSaved = true;
        }
      }
    } catch (_) {}
    try {
      await db('blockedApps/${widget.childUid}/$key').update({
        'packageName': packageName,
        'name': appName,
        'blocked': value,
        'updatedAt': ServerValue.timestamp,
        'updatedBy': FirebaseAuth.instance.currentUser?.uid,
      });
    } catch (_) {
      if (!serverSaved && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Қулф нигоҳ дошта нашуд. Серверро санҷед.'),
          ),
        );
      }
    }
    if (serverSaved) {
      serverRules[key] = {
        ...Map<String, dynamic>.from(serverRules[key] as Map? ?? const {}),
        'packageName': packageName,
        'name': appName,
        'blocked': value,
      };
      if (mounted) setState(() {});
    }
  }

  Future<void> _togglePause(List<Map<String, dynamic>> apps, bool value) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final updates = <String, Object?>{};
    for (final app in apps) {
      final packageName = app['packageName']?.toString() ?? '';
      if (packageName.isEmpty) continue;
      final key = encodedAppKey(packageName);
      updates['blockedApps/${widget.childUid}/$key/packageName'] = packageName;
      updates['blockedApps/${widget.childUid}/$key/name'] =
          app['name']?.toString() ?? packageName;
      updates['blockedApps/${widget.childUid}/$key/blocked'] = value;
      updates['blockedApps/${widget.childUid}/$key/updatedBy'] = user.uid;
      updates['blockedApps/${widget.childUid}/$key/updatedAt'] =
          ServerValue.timestamp;
      unawaited(
        _setBlocked(
          key,
          packageName,
          app['name']?.toString() ?? packageName,
          value,
        ),
      );
    }
    try {
      await db('').update(updates);
    } catch (_) {
      // The server data plane above is authoritative during RTDB outages.
    }
    if (mounted) setState(() => pauseActive = value);
  }

  Future<void> _openDetails(
    BuildContext context,
    Map<String, dynamic> app,
    Map? rule,
  ) async {
    final packageName = app['packageName']?.toString() ?? '';
    final key = encodedAppKey(packageName);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      barrierColor: Colors.black.withValues(alpha: .62),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (_) => FractionallySizedBox(
        heightFactor: .94,
        child: AppDetailRulesSheet(
          childUid: widget.childUid,
          ruleKey: key,
          app: app,
          rule: rule,
        ),
      ),
    );
  }

  Future<void> _pickSchedule(
    String key,
    String packageName,
    String appName,
    Map? current,
  ) async {
    final schedule = current?['schedule'] is Map
        ? Map<String, dynamic>.from(current!['schedule'] as Map)
        : <String, dynamic>{};
    TimeOfDay parseTime(String value, TimeOfDay fallback) {
      final parts = value.split(':');
      final hour = int.tryParse(parts.first);
      final minute = parts.length > 1 ? int.tryParse(parts[1]) : null;
      return hour != null && minute != null && hour < 24 && minute < 60
          ? TimeOfDay(hour: hour, minute: minute)
          : fallback;
    }

    final start = await showTimePicker(
      context: context,
      initialTime: parseTime(
        schedule['start']?.toString() ??
            dynamicConfig.ruleString('homeworkStart', fallback: '16:00'),
        const TimeOfDay(hour: 16, minute: 0),
      ),
      helpText: 'Оғози Homework Mode',
    );
    if (start == null || !mounted) return;
    final end = await showTimePicker(
      context: context,
      initialTime: parseTime(
        schedule['end']?.toString() ??
            dynamicConfig.ruleString('homeworkEnd', fallback: '18:00'),
        const TimeOfDay(hour: 18, minute: 0),
      ),
      helpText: 'Анҷоми Homework Mode',
    );
    if (end == null || !mounted) return;
    String format(TimeOfDay time) =>
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    final schedulePayload = <String, dynamic>{
      'enabled': true,
      'start': format(start),
      'end': format(end),
      'weekdays': [1, 2, 3, 4, 5],
    };
    var serverSaved = false;
    try {
      final api = await NigohApi.current('parent');
      if (api != null && serverChildId == null) await _loadServerApps();
      if (api != null && serverChildId != null) {
        await api.updateRule(serverChildId!, packageName, {
          'schedule': schedulePayload,
        });
        serverSaved = true;
      }
    } catch (_) {}
    try {
      await db('blockedApps/${widget.childUid}/$key').update({
        'packageName': packageName,
        'name': appName,
        'schedule': schedulePayload,
        'updatedAt': ServerValue.timestamp,
        'updatedBy': FirebaseAuth.instance.currentUser?.uid,
      });
    } catch (_) {
      if (!serverSaved && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ҷадвал нигоҳ дошта нашуд.')),
        );
      }
    }
    if (serverSaved) {
      serverRules[key] = {
        ...Map<String, dynamic>.from(serverRules[key] as Map? ?? const {}),
        'packageName': packageName,
        'name': appName,
        'schedule': schedulePayload,
      };
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<DatabaseEvent>(
    stream: db('installedApps/${widget.childUid}').onValue,
    builder: (_, appsSnap) {
      final remoteApps = appsSnap.data?.snapshot.value as Map?;
      final rawApps = remoteApps != null && remoteApps.isNotEmpty
          ? remoteApps
          : (serverApps.isNotEmpty
                ? serverApps
                : (cachedApps.isNotEmpty ? cachedApps : null));
      if (remoteApps != null && remoteApps.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) unawaited(_cacheApps(remoteApps));
        });
      }
      if (rawApps == null || rawApps.isEmpty) {
        if (appsSnap.connectionState == ConnectionState.waiting ||
            cacheLoading) {
          return const _AppsLoadingSkeleton();
        }
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const EmptyCard(
                  icon: Icons.apps_outlined,
                  title: 'Ягон барнома ёфт нашуд',
                  text: 'Барномаи фарзандро кушоед ва рӯйхатро аз нав навсозӣ кунед.',
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: refreshing ? null : _refreshApps,
                  icon: refreshing
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh_rounded),
                  label: const Text('Навсозӣ'),
                ),
              ],
            ),
          ),
        );
      }
      final apps =
          rawApps.values
              .whereType<Map>()
              .map((value) => Map<String, dynamic>.from(value))
              .toList()
            ..sort(
              (a, b) => (a['name']?.toString() ?? '').toLowerCase().compareTo(
                (b['name']?.toString() ?? '').toLowerCase(),
              ),
            );
      final visibleApps = apps.where((app) {
        return UserJourneyLogic.appMatches(
          app,
          query: query,
          category: category,
        );
      }).toList();
      return StreamBuilder<DatabaseEvent>(
        stream: db('blockedApps/${widget.childUid}').onValue,
        builder: (_, blockedSnap) {
          final firebaseBlocked = blockedSnap.data?.snapshot.value as Map?;
          final blocked = firebaseBlocked != null && firebaseBlocked.isNotEmpty
              ? firebaseBlocked
              : (serverRules.isNotEmpty ? serverRules : firebaseBlocked);
          final blockedCount = apps.where((app) {
            final key = encodedAppKey(app['packageName']?.toString() ?? '');
            return (blocked?[key] as Map?)?['blocked'] == true;
          }).length;
          final totalMinutes = apps.fold<int>(
            0,
            (sum, app) => sum + ((app['usageMinutes'] as num?)?.round() ?? 0),
          );
          final totalLimit = apps.fold<int>(0, (sum, app) {
            final key = encodedAppKey(app['packageName']?.toString() ?? '');
            final rule = blocked?[key] as Map?;
            return sum + ((rule?['dailyLimitMinutes'] as num?)?.toInt() ?? 0);
          });
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
                child: _ScreenTimeOverview(
                  usedMinutes: totalMinutes,
                  limitMinutes: totalLimit > 0 ? totalLimit : 240,
                  blockedCount: blockedCount,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: _QuickPauseBanner(
                        active: pauseActive,
                        onChanged: (value) => _togglePause(apps, value),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      tooltip: 'Қулфи фаврӣ',
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0x332D0E19),
                        foregroundColor: cyberRed,
                        side: const BorderSide(color: cyberRed),
                      ),
                      onPressed: () => _togglePause(apps, true),
                      icon: const Icon(Icons.lock_rounded),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: search,
                        onChanged: (value) => setState(() => query = value),
                        decoration: const InputDecoration(
                          hintText: 'Ҷустуҷӯи барнома…',
                          prefixIcon: Icon(Icons.search_rounded),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary
                            .withValues(alpha: .10),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.primary
                              .withValues(alpha: .24),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        child: Text(
                          '$blockedCount маҳкам',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 38,
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                  scrollDirection: Axis.horizontal,
                  itemCount: categories.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (_, index) => ChoiceChip(
                    label: Text(categories[index]),
                    selected: category == categories[index],
                    onSelected: (_) =>
                        setState(() => category = categories[index]),
                    selectedColor: Theme.of(context)
                        .colorScheme
                        .primaryContainer,
                    backgroundColor: Theme.of(context).colorScheme.surface,
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                    labelStyle: TextStyle(
                      color: category == categories[index]
                          ? Theme.of(context).colorScheme.onPrimaryContainer
                          : Theme.of(context).colorScheme.onSurface
                                .withValues(alpha: .68),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 22),
                  itemCount: visibleApps.length,
                  itemBuilder: (_, index) {
                    final app = visibleApps[index];
                    final packageName = app['packageName']?.toString() ?? '';
                    final key = encodedAppKey(packageName);
                    final rule = blocked?[key] as Map?;
                    final isBlocked = rule?['blocked'] == true;
                    final minutes = (app['usageMinutes'] as num?)?.round() ?? 0;
                    final usageText = minutes == 0
                        ? 'Имрӯз истифода нашудааст'
                        : minutes < 60
                        ? 'Имрӯз $minutes дақиқа истифода шудааст'
                        : 'Имрӯз ${minutes ~/ 60} соату ${minutes % 60} дақиқа истифода шудааст';
                    final appName = app['name']?.toString() ?? packageName;
                    final dailyLimit =
                        pendingLimits[key] ??
                        (rule?['dailyLimitMinutes'] as num?)?.toInt() ??
                        0;
                    final limitIndex = _limitIndex(dailyLimit);
                    final progress = UserJourneyLogic.usageProgress(
                      minutes,
                      dailyLimit,
                    );
                    final schedule = rule?['schedule'] is Map
                        ? Map<String, dynamic>.from(rule!['schedule'] as Map)
                        : <String, dynamic>{};
                    final scheduleEnabled = schedule['enabled'] == true;
                    final iconBase64 = app['iconBase64']?.toString() ?? '';
                    return _AppRuleCard(
                      appName: appName,
                      packageName: packageName,
                      iconBase64: iconBase64,
                      isBlocked: isBlocked,
                      usageText: usageText,
                      minutes: minutes,
                      dailyLimit: dailyLimit,
                      limitIndex: limitIndex,
                      limitCount: limitChoices.length,
                      progress: progress,
                      limitLabel: _limitLabel,
                      scheduleLabel: scheduleEnabled
                          ? '${schedule['start']}–${schedule['end']}'
                          : null,
                      onOpen: () => _openDetails(context, app, rule),
                      onBlocked: (value) =>
                          _setBlocked(key, packageName, appName, value),
                      onLimitChanged: (value) => setState(
                        () => pendingLimits[key] = limitChoices[value],
                      ),
                      onLimitDone: (value) =>
                          _setLimit(key, limitChoices[value]),
                      onSchedule: () =>
                          _pickSchedule(key, packageName, appName, rule),
                    );
                  },
                ),
              ),
            ],
          );
        },
      );
    },
  );
}

class _AppRuleCard extends StatelessWidget {
  const _AppRuleCard({
    required this.appName,
    required this.packageName,
    required this.iconBase64,
    required this.isBlocked,
    required this.usageText,
    required this.minutes,
    required this.dailyLimit,
    required this.limitIndex,
    required this.limitCount,
    required this.progress,
    required this.limitLabel,
    required this.scheduleLabel,
    required this.onOpen,
    required this.onBlocked,
    required this.onLimitChanged,
    required this.onLimitDone,
    required this.onSchedule,
  });

  final String appName;
  final String packageName;
  final String iconBase64;
  final bool isBlocked;
  final String usageText;
  final int minutes;
  final int dailyLimit;
  final int limitIndex;
  final int limitCount;
  final double progress;
  final String Function(int) limitLabel;
  final String? scheduleLabel;
  final VoidCallback onOpen;
  final ValueChanged<bool> onBlocked;
  final ValueChanged<int> onLimitChanged;
  final ValueChanged<int> onLimitDone;
  final VoidCallback onSchedule;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = isBlocked
        ? NigohDesign.coral
        : NigohDesign.accentFor(packageName);
    final barColor = progress >= 1 ? NigohDesign.coral : accent;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: .22)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: .06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    NigohAppIcon(
                      icon: iconBase64,
                      seed: packageName,
                      size: 46,
                      locked: isBlocked,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            appName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: scheme.onSurface,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            usageText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: scheme.onSurface.withValues(alpha: .6),
                            ),
                          ),
                        ],
                      ),
                    ),
                    _StatusTag(
                      text: isBlocked ? 'Баста' : 'Фаъол',
                      color: isBlocked ? NigohDesign.coral : NigohDesign.mint,
                    ),
                    Switch.adaptive(
                      value: isBlocked,
                      activeThumbColor: Colors.white,
                      activeTrackColor: NigohDesign.coral,
                      onChanged: onBlocked,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 6,
                          borderRadius: BorderRadius.circular(8),
                          backgroundColor: accent.withValues(alpha: .12),
                          color: barColor,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        dailyLimit > 0
                            ? '$minutesд / ${limitLabel(dailyLimit)}'
                            : '$minutesд',
                        style: TextStyle(
                          color: barColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: accent,
                    inactiveTrackColor: accent.withValues(alpha: .15),
                    thumbColor: accent,
                    overlayColor: accent.withValues(alpha: .12),
                    activeTickMarkColor: Colors.white70,
                    inactiveTickMarkColor: accent.withValues(alpha: .4),
                    valueIndicatorColor: accent,
                    trackHeight: 4,
                  ),
                  child: Slider(
                    value: limitIndex.toDouble(),
                    min: 0,
                    max: (limitCount - 1).toDouble(),
                    divisions: limitCount - 1,
                    label: limitLabel(dailyLimit),
                    onChanged: (value) => onLimitChanged(value.round()),
                    onChangeEnd: (value) => onLimitDone(value.round()),
                  ),
                ),
                Row(
                  children: [
                    Icon(Icons.timer_outlined, size: 16, color: accent),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Лимит: ${limitLabel(dailyLimit)}',
                        style: TextStyle(
                          color: scheme.onSurface,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: onSchedule,
                      style: TextButton.styleFrom(
                        foregroundColor: scheduleLabel != null
                            ? NigohDesign.violet
                            : scheme.primary,
                        backgroundColor: (scheduleLabel != null
                                ? NigohDesign.violet
                                : scheme.primary)
                            .withValues(alpha: .08),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: Icon(
                        scheduleLabel != null
                            ? Icons.event_available_rounded
                            : Icons.menu_book_rounded,
                        size: 18,
                      ),
                      label: Text(scheduleLabel ?? 'Вақти дарс'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusTag extends StatelessWidget {
  const _StatusTag({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      text,
      style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800),
    ),
  );
}

class ChildProtectionPage extends StatefulWidget {
  const ChildProtectionPage({super.key, required this.uid});
  final String uid;
  @override
  State<ChildProtectionPage> createState() => _ChildProtectionPageState();
}

class _PermissionStep extends StatelessWidget {
  const _PermissionStep({
    required this.number,
    required this.done,
    required this.title,
    required this.subtitle,
    required this.onPressed,
  });

  final int number;
  final bool done;
  final String title;
  final String subtitle;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Material(
    color: done ? const Color(0xFFE7F8F3) : Colors.white,
    borderRadius: BorderRadius.circular(18),
    child: InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: done ? Colors.teal : const Color(0xFFE8EEFF),
              foregroundColor: done ? Colors.white : const Color(0xFF315FEA),
              child: done
                  ? const Icon(Icons.check_rounded, size: 20)
                  : Text(
                      '$number',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 3),
                  Text(subtitle, style: const TextStyle(fontSize: 12.5)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    ),
  );
}

class _ChildProtectionPageState extends State<ChildProtectionPage>
    with WidgetsBindingObserver {
  static const channel = MethodChannel('tj.nigoh/device_control');
  bool checking = true;
  bool enabled = false;
  bool usageAccess = false;
  bool overlayAccess = false;
  bool accessibilityAccess = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) check();
  }

  Future<void> check() async {
    final raw = await channel.invokeMethod<Map<Object?, Object?>>(
      'getProtectionStatus',
    );
    final usage = raw?['usage'] == true;
    final overlay = raw?['overlay'] == true;
    final accessibility = raw?['accessibility'] == true;
    if (mounted) {
      setState(() {
        usageAccess = usage;
        overlayAccess = overlay;
        accessibilityAccess = accessibility;
        enabled = usage && overlay && accessibility;
        checking = false;
      });
    }
  }

  Future<void> openAppDetails() => channel.invokeMethod<void>('openAppDetails');
  Future<void> openUsageSettings() =>
      channel.invokeMethod<void>('openUsageSettings');
  Future<void> openOverlaySettings() =>
      channel.invokeMethod<void>('openOverlaySettings');

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      const Text(
        'Муҳофизати барномаҳо',
        style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900),
      ),
      const SizedBox(height: 6),
      const Text(
        'NIGOH танҳо барномаҳоеро мебандад, ки волидайн дар панели худ интихоб кардааст.',
      ),
      const SizedBox(height: 18),
      Card(
        color: enabled ? const Color(0xFFE7F8F3) : const Color(0xFFFFF3DF),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Icon(
                enabled ? Icons.verified_user : Icons.shield_outlined,
                size: 62,
                color: enabled ? Colors.teal : Colors.orange,
              ),
              const SizedBox(height: 12),
              Text(
                checking
                    ? 'Санҷида истодааст…'
                    : enabled
                    ? 'Муҳофизат фаъол аст'
                    : 'Иҷозати муҳофизат лозим аст',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Барои APK-и аз браузер насбшуда аввал Android метавонад Usage access-ро маҳдуд кунад. Қадамҳоро бо тартиб иҷро намоед.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              _PermissionStep(
                number: 1,
                done: false,
                title: 'App info-ро кушоед',
                subtitle: 'Менюи ⋮-ро пахш карда «Allow restricted settings»-ро интихоб кунед.',
                onPressed: openAppDetails,
              ),
              const SizedBox(height: 10),
              _PermissionStep(
                number: 2,
                done: usageAccess,
                title: 'Usage access',
                subtitle: usageAccess
                    ? 'Иҷозат дода шуд'
                    : 'NIGOH Family-ро интихоб карда фаъол кунед.',
                onPressed: openUsageSettings,
              ),
              const SizedBox(height: 10),
              _PermissionStep(
                number: 3,
                done: overlayAccess,
                title: 'Display over other apps',
                subtitle: overlayAccess
                    ? 'Иҷозат дода шуд'
                    : 'Намоиш болои барномаҳои дигарро фаъол кунед.',
                onPressed: openOverlaySettings,
              ),
              const SizedBox(height: 10),
              _PermissionStep(
                number: 4,
                done: accessibilityAccess,
                title: 'Accessibility — назорати барномаҳо',
                subtitle: accessibilityAccess
                    ? 'Иҷозат дода шуд'
                    : 'Барои бастани фаврии барномаи интихобшуда фаъол кунед.',
                onPressed: () =>
                    channel.invokeMethod<void>('openAccessibilitySettings'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: check,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Аз нав санҷидан'),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),
      StreamBuilder<DatabaseEvent>(
        stream: db('blockedApps/${widget.uid}').onValue,
        builder: (_, snap) {
          final rules = snap.data?.snapshot.value as Map?;
          final count =
              rules?.values
                  .whereType<Map>()
                  .where((value) => value['blocked'] == true)
                  .length ??
              0;
          return Card(
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.lock_outline)),
              title: const Text(
                'Барномаҳои маҳкамшуда',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              trailing: Text(
                '$count',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          );
        },
      ),
    ],
  );
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, required this.user, required this.profile});
  final User user;
  final Map<String, dynamic> profile;
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late final name = TextEditingController(
    text: '${widget.profile['displayName']}',
  );
  Future<void> save() async {
    await widget.user.updateDisplayName(name.text.trim());
    await db('profiles/${widget.user.uid}/displayName').set(name.text.trim());
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Профил нав шуд')));
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
    children: [
      Row(
        children: [
          _ProfileRing(name: name.text, online: true, size: 88),
          const SizedBox(width: 24),
          const Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _ProfileStat(value: '1', label: 'аккаунт'),
                _ProfileStat(value: '24/7', label: 'муҳофизат'),
                _ProfileStat(value: 'Live', label: 'пайваст'),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 14),
      Text(
        name.text,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
      ),
      Text(
        widget.user.email ?? '',
        style: const TextStyle(color: Colors.black54),
      ),
      const SizedBox(height: 18),
      TextField(
        controller: name,
        decoration: const InputDecoration(
          labelText: 'Ному насаб',
          prefixIcon: Icon(Icons.person),
        ),
      ),
      const SizedBox(height: 12),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => Scaffold(
              appBar: AppBar(title: const Text('Маркази иҷозатҳо')),
              body: AccessCenterPage(
                childMode: widget.profile['role'] == 'child',
              ),
            ),
          ),
        ),
        icon: const Icon(Icons.security_rounded),
        label: const Text('Дидани иҷозатҳо'),
      ),
      const SizedBox(height: 10),
      OutlinedButton.icon(
        onPressed: save,
        icon: const Icon(Icons.edit_outlined),
        label: const Text('Таҳрири профил'),
      ),
      const SizedBox(height: 10),
      OutlinedButton.icon(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => Scaffold(
              appBar: AppBar(title: const Text('Навсозии барнома')),
              body: const AppUpdatePage(),
            ),
          ),
        ),
        icon: const Icon(Icons.system_update_alt_rounded),
        label: const Text('Санҷидани навсозӣ'),
      ),
      const SizedBox(height: 10),
      OutlinedButton.icon(
        onPressed: () async {
          await GoogleSignIn.instance.signOut();
          await FirebaseAuth.instance.signOut();
        },
        icon: const Icon(Icons.logout),
        label: const Text('Баромадан'),
      ),
    ],
  );
}

class _ProfileStat extends StatelessWidget {
  const _ProfileStat({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
      Text(label, style: const TextStyle(fontSize: 12)),
    ],
  );
}
