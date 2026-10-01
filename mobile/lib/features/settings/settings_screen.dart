import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/child_profile.dart';
import '../../core/notify_bridge.dart';
import '../../core/session.dart';
import '../../core/user_journey_logic.dart';
import '../onboarding/permissions_wizard.dart';
import '../../ui/nigoh_design.dart';
import '../../ui/widgets.dart';
import 'app_update.dart';
import 'parent_pin.dart';
import 'profile_photo.dart';
import 'theme_mode.dart';

/// Settings tab shared by the parent and child homes. Has its own Scaffold.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with WidgetsBindingObserver {
  bool? hasPin;
  NotifyPermissions? notifyStatus;
  bool notifyLoaded = false;
  String? pinError;
  String version = '';
  bool checkingUpdate = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    loadNotifyStatus();
    loadPin();
    PackageInfo.fromPlatform()
        .then((info) {
          if (mounted) {
            setState(() => version = '${info.version} (${info.buildNumber})');
          }
        })
        .catchError((_) {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Permissions are granted in Android settings; refresh on return.
    if (state == AppLifecycleState.resumed) loadNotifyStatus();
  }

  Future<void> loadNotifyStatus() async {
    final status = await NotifyBridge.permissionStatus();
    if (!mounted) return;
    setState(() {
      notifyStatus = status;
      notifyLoaded = true;
    });
  }

  Future<void> fixNotifications() async {
    final status = notifyStatus;
    if (status != null && status.notifications && !status.fullScreen) {
      await NotifyBridge.openFullScreenSettings();
    } else {
      await NotifyBridge.ensurePermissions(context);
    }
    await loadNotifyStatus();
  }

  Future<void> loadPin() async {
    try {
      final value = await ParentPin.isSet();
      if (mounted) {
        setState(() {
          hasPin = value;
          pinError = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => pinError = e is PlatformException
              ? (e.message ?? 'Ҳолати PIN маълум нашуд.')
              : 'Ҳолати PIN маълум нашуд.',
        );
      }
    }
  }

  Future<void> editName(Session session) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _NameDialog(initial: session.displayName),
    );
    if (name == null || name.trim().isEmpty || !mounted) return;
    try {
      await session.updateName(name);
      if (mounted) showMessage(context, 'Ном нигоҳ дошта шуд.');
    } catch (e) {
      if (mounted) showMessage(context, e, error: true);
    }
  }

  Future<void> editPin() async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => PinSetupDialog(hasPin: hasPin == true),
    );
    if (changed == true && mounted) {
      showMessage(
        context,
        hasPin == true ? 'PIN иваз шуд.' : 'PIN гузошта шуд.',
      );
      setState(() => hasPin = true);
    }
  }

  Future<void> checkUpdate(Session session) async {
    setState(() => checkingUpdate = true);
    await AppUpdate.check(context, session.api);
    if (mounted) setState(() => checkingUpdate = false);
  }

  Future<void> signOut(Session session) async {
    if (session.isChild) {
      bool pinSet;
      try {
        pinSet = await ParentPin.isSet();
      } catch (_) {
        pinSet = false;
      }
      if (!mounted) return;
      if (pinSet) {
        final ok = await ParentPin.ask(
          context,
          text: 'Барои баромадан аз аккаунт PIN-и волидайн лозим аст.',
        );
        if (!ok || !mounted) return;
      }
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Аз аккаунт бароед?'),
        content: const Text('Барои идома боз ворид шудан лозим мешавад.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Бекор'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(110, 44)),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Баромадан'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (session.isChild) await ChildProfile.clear();
    await session.signOut();
  }

  Future<void> requestUninstall() async {
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _UninstallDialog(),
    );
    if (ok == true && mounted) {
      showMessage(context, 'Тасдиқ шуд. Android экрани несткуниро мекушояд.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final child = session.isChild;
    var i = 0;
    return Scaffold(
      appBar: AppBar(title: const Text('Танзимот')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          FadeIn(
            index: i++,
            child: _ProfileCard(
              session: session,
              onEdit: () => editName(session),
            ),
          ),
          const SectionTitle('Амният'),
          FadeIn(
            index: i++,
            child: _Group(
              children: [
                _Tile(
                  icon: Icons.pin_outlined,
                  color: NigohDesign.violet,
                  title: 'PIN-и волидайн',
                  subtitle:
                      pinError ??
                      (hasPin == null
                          ? 'Санҷида мешавад…'
                          : hasPin!
                          ? 'Фаъол аст'
                          : 'Гузошта нашудааст'),
                  subtitleColor: pinError != null ? scheme.error : null,
                  trailing: Text(
                    hasPin == true ? 'Иваз кардан' : 'Гузоштан',
                    style: TextStyle(
                      color: scheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: pinError != null ? loadPin : editPin,
                ),
                const Divider(height: 1),
                _Tile(
                  icon: Icons.verified_user_outlined,
                  color: NigohDesign.mint,
                  title: 'Иҷозатҳо (устод)',
                  subtitle: child
                      ? 'Ҷойгиршавӣ, истифода ва бастани барномаҳо'
                      : 'Огоҳиномаҳо, камера, микрофон ва батарея',
                  onTap: () async {
                    await PermissionsWizard.open(context, childMode: child);
                    if (mounted) await loadNotifyStatus();
                  },
                ),
                if (child) ...[
                  const Divider(height: 1),
                  _Tile(
                    icon: Icons.shield_outlined,
                    color: NigohDesign.amber,
                    title: 'Муҳофизат аз несткунӣ',
                    subtitle: 'NIGOH-ро танҳо бо PIN-и волидайн нест кардан мумкин аст.',
                    trailing: Text(
                      'Нест кардан',
                      style: TextStyle(
                        color: scheme.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onTap: requestUninstall,
                  ),
                ],
              ],
            ),
          ),
          const SectionTitle('Намуд'),
          FadeIn(
            index: i++,
            child: _Group(
              children: [
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: ValueListenableBuilder<ThemeMode>(
                    valueListenable: themeModeSetting,
                    builder: (_, mode, _) => SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<ThemeMode>(
                        showSelectedIcon: false,
                        segments: const [
                          ButtonSegment(
                            value: ThemeMode.system,
                            icon: Icon(Icons.brightness_auto_outlined),
                            label: Text('Система'),
                          ),
                          ButtonSegment(
                            value: ThemeMode.light,
                            icon: Icon(Icons.light_mode_outlined),
                            label: Text('Равшан'),
                          ),
                          ButtonSegment(
                            value: ThemeMode.dark,
                            icon: Icon(Icons.dark_mode_outlined),
                            label: Text('Торик'),
                          ),
                        ],
                        selected: {mode},
                        onSelectionChanged: (value) =>
                            themeModeSetting.set(value.first),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SectionTitle('Барнома'),
          FadeIn(
            index: i++,
            child: _Group(
              children: [
                _Tile(
                  icon: Icons.info_outline_rounded,
                  color: NigohDesign.sky,
                  title: 'Версия',
                  subtitle: version.isEmpty ? '—' : version,
                ),
                const Divider(height: 1),
                ValueListenableBuilder<String?>(
                  valueListenable: AppUpdate.lastError,
                  builder: (_, error, _) => _Tile(
                    icon: Icons.system_update_outlined,
                    color: NigohDesign.blue,
                    title: 'Санҷидани навсозӣ',
                    subtitle: error,
                    subtitleColor: error != null ? scheme.error : null,
                    trailing: checkingUpdate
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.chevron_right_rounded),
                    onTap: checkingUpdate ? null : () => checkUpdate(session),
                  ),
                ),
                const Divider(height: 1),
                ValueListenableBuilder<String?>(
                  valueListenable: NotifyBridge.lastError,
                  builder: (_, error, _) {
                    final status = notifyStatus;
                    final ok = status?.all == true;
                    final subtitle =
                        error ??
                        (!notifyLoaded
                            ? 'Санҷида мешавад…'
                            : status == null
                            ? 'Ҳолат маълум нашуд'
                            : !status.notifications
                            ? 'Хомӯш аст — паёмҳо ва SOS намерасанд'
                            : !status.fullScreen
                            ? 'Барои SOS ва зангҳо иҷозати экрани пурра лозим'
                            : 'Фаъол: паёмҳо, SOS ва зангҳо');
                    return _Tile(
                      icon: Icons.notifications_active_outlined,
                      color: NigohDesign.coral,
                      title: 'Огоҳиномаҳо',
                      subtitle: subtitle,
                      subtitleColor: error != null || (status != null && !ok)
                          ? scheme.error
                          : null,
                      trailing: ok || status == null
                          ? null
                          : Text(
                              status.notifications ? 'Кушодан' : 'Иҷозат додан',
                              style: TextStyle(
                                color: scheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                      onTap: status == null
                          ? loadNotifyStatus
                          : ok
                          ? null
                          : fixNotifications,
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          FadeIn(
            index: i++,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: scheme.error),
              onPressed: () => signOut(session),
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Баромадан аз аккаунт'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.session, required this.onEdit});
  final Session session;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final name = session.displayName.isEmpty
        ? 'Истифодабаранда'
        : session.displayName;
    final roleColor = session.isParent ? NigohDesign.blue : NigohDesign.mint;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            ProfileAvatarButton(session: session, color: roleColor),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (session.email.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      session.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Pill(
                    session.isParent ? 'Волидайн' : 'Фарзанд',
                    color: roleColor,
                    icon: session.isParent
                        ? Icons.family_restroom_rounded
                        : Icons.child_care_rounded,
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Тағйири ном',
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined),
            ),
          ],
        ),
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: Column(children: children),
  );
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.color,
    required this.title,
    this.subtitle,
    this.subtitleColor,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;
  final Color? subtitleColor;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    onTap: onTap,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
    leading: Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color, size: 21),
    ),
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
    subtitle: subtitle == null
        ? null
        : Text(subtitle!, style: TextStyle(color: subtitleColor)),
    trailing:
        trailing ??
        (onTap != null ? const Icon(Icons.chevron_right_rounded) : null),
  );
}

class _NameDialog extends StatefulWidget {
  const _NameDialog({required this.initial});
  final String initial;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final name = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  void save() {
    if (name.text.trim().isEmpty) return;
    Navigator.pop(context, name.text.trim());
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Ном'),
    content: TextField(
      controller: name,
      autofocus: true,
      textCapitalization: TextCapitalization.words,
      onSubmitted: (_) => save(),
      decoration: const InputDecoration(labelText: 'Номи шумо'),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Бекор'),
      ),
      FilledButton(
        style: FilledButton.styleFrom(minimumSize: const Size(110, 44)),
        onPressed: save,
        child: const Text('Нигоҳ доштан'),
      ),
    ],
  );
}

/// Legacy uninstall flow: the parent PIN unlocks Android's uninstall screen.
class _UninstallDialog extends StatefulWidget {
  const _UninstallDialog();

  @override
  State<_UninstallDialog> createState() => _UninstallDialogState();
}

class _UninstallDialogState extends State<_UninstallDialog> {
  final pin = TextEditingController();
  String? error;
  bool busy = false;

  @override
  void dispose() {
    pin.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    final value = pin.text.trim();
    if (!UserJourneyLogic.validPin(value)) {
      return setState(() => error = 'PIN бояд аз 4 рақам иборат бошад.');
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await ParentPin.channel.invokeMapMethod<String, dynamic>(
        'requestUninstallWithPin',
        {'pin': value},
      );
      if (!mounted) return;
      if (result?['ok'] == true) return Navigator.pop(context, true);
      final code = result?['error'];
      setState(() {
        error = code == 'locked'
            ? 'Кӯшишҳо баста шуданд. Баъд аз ${result?['remainingSeconds']} сония дубора кӯшиш кунед.'
            : code == 'no_pin'
            ? 'Аввал PIN-и волидайнро гузоред.'
            : 'PIN нодуруст аст.';
      });
    } on PlatformException catch (e) {
      if (mounted) setState(() => error = e.message ?? 'Амал иҷро нашуд.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    icon: const Icon(Icons.shield_outlined),
    title: const Text('Тасдиқи волидайн'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Барои нест кардани NIGOH PIN-и волидайнро ворид кунед.'),
        const SizedBox(height: 14),
        TextField(
          controller: pin,
          autofocus: true,
          obscureText: true,
          maxLength: 4,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onSubmitted: (_) => submit(),
          decoration: InputDecoration(
            labelText: 'PIN-и волидайн',
            counterText: '',
            errorText: error,
            errorMaxLines: 3,
          ),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: busy ? null : () => Navigator.pop(context, false),
        child: const Text('Бекор'),
      ),
      FilledButton(
        style: FilledButton.styleFrom(minimumSize: const Size(110, 44)),
        onPressed: busy ? null : submit,
        child: const Text('Тасдиқ'),
      ),
    ],
  );
}
