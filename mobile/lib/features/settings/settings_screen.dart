// Файл: танзимоти ҳисоб, забон, theme ва амният.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/child_profile.dart';
import '../../core/notify_bridge.dart';
import '../../core/session.dart';
import '../../core/user_journey_logic.dart';
import '../onboarding/permissions_wizard.dart';
import '../../ui/language_picker.dart';
import '../../ui/nigoh_design.dart';
import '../../ui/day_night_switch.dart';
import '../../ui/widgets.dart';
import 'app_update.dart';
import 'parent_pin.dart';
import 'profile_photo.dart';
import 'theme_mode.dart';
import '../../l10n/l10n.dart';

/// Экрани SettingsScreen-ро барои танзимоти ҳисоб, забон, theme ва амният месозад.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  /// Ҳолати SettingsScreen-ро барои танзимоти ҳисоб ва барнома месозад.
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

/// Ҳолат ва рафтори SettingsScreenState-ро барои навсозии интерфейс идора мекунад.
class _SettingsScreenState extends State<SettingsScreen>
    with WidgetsBindingObserver {
  bool? hasPin;
  NotifyPermissions? notifyStatus;
  bool notifyLoaded = false;
  String? pinError;
  String version = '';
  bool checkingUpdate = false;

  /// Вазъи огоҳинома, PIN ва версияи насбшударо барои экрани танзимот мехонад.
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

  /// Controller ва listener-ҳои SettingsScreen-ро озод мекунад.
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Ба тағйири lifecycle-и SettingsScreen ҷавоб медиҳад.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // loadNotifyStatus иҷозати зарурии Android-ро месанҷад ё дархост мекунад.
    if (state == AppLifecycleState.resumed) loadNotifyStatus();
  }

  /// loadNotifyStatus додаҳоро мехонад ва ҳолати экранро нав мекунад.
  Future<void> loadNotifyStatus() async {
    final status = await NotifyBridge.permissionStatus();
    if (!mounted) return;
    setState(() {
      notifyStatus = status;
      notifyLoaded = true;
    });
  }

  /// fixNotifications мантиқи зарурии танзимоти ҳисоб, забон, theme ва амниятро иҷро мекунад.
  Future<void> fixNotifications() async {
    final status = notifyStatus;
    if (status != null && status.notifications && !status.fullScreen) {
      await NotifyBridge.openFullScreenSettings();
    } else {
      await NotifyBridge.ensurePermissions(context);
    }
    await loadNotifyStatus();
  }

  /// loadPin додаҳоро мехонад ва ҳолати экранро нав мекунад.
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
              ? (e.message ?? tr('Ҳолати PIN маълум нашуд.'))
              : tr('Ҳолати PIN маълум нашуд.'),
        );
      }
    }
  }

  /// editName мантиқи зарурии танзимоти ҳисоб, забон, theme ва амниятро иҷро мекунад.
  Future<void> editName(Session session) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _NameDialog(initial: session.displayName),
    );
    if (name == null || name.trim().isEmpty || !mounted) return;
    try {
      await session.updateName(name);
      if (mounted) showMessage(context, tr('Ном нигоҳ дошта шуд.'));
    } catch (e) {
      if (mounted) showMessage(context, e, error: true);
    }
  }

  /// editPin мантиқи зарурии танзимоти ҳисоб, забон, theme ва амниятро иҷро мекунад.
  Future<void> editPin() async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => PinSetupDialog(hasPin: hasPin == true),
    );
    if (changed == true && mounted) {
      showMessage(
        context,
        hasPin == true ? tr('PIN иваз шуд.') : tr('PIN гузошта шуд.'),
      );
      setState(() => hasPin = true);
    }
  }

  /// checkUpdate дурустӣ ва шартҳои зарурии додаҳоро месанҷад.
  Future<void> checkUpdate(Session session) async {
    setState(() => checkingUpdate = true);
    await AppUpdate.check(context, session.api);
    if (mounted) setState(() => checkingUpdate = false);
  }

  /// signOut мантиқи зарурии танзимоти ҳисоб, забон, theme ва амниятро иҷро мекунад.
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
          text: tr('Барои баромадан аз аккаунт PIN-и волидайн лозим аст.'),
        );
        if (!ok || !mounted) return;
      }
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(tr('Аз аккаунт бароед?')),
        content: Text(tr('Барои идома боз ворид шудан лозим мешавад.')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(tr('Бекор')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(110, 44)),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(tr('Баромадан')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (session.isChild) await ChildProfile.clear();
    await session.signOut();
  }

  /// requestUninstall иҷозат ё маълумоти лозимро дархост мекунад.
  Future<void> requestUninstall() async {
    if (hasPin == false) {
      final setNow = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(Icons.pin_outlined),
          title: Text(tr('PIN-и волидайн гузошта нашудааст')),
          content: Text(
            tr(
              'Нест кардани NIGOH танҳо бо PIN-и волидайн мумкин аст. '
              'Аввал волидайн PIN гузорад.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(tr('Бекор')),
            ),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(110, 44)),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(tr('Гузоштани PIN')),
            ),
          ],
        ),
      );
      if (setNow == true && mounted) await editPin();
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _UninstallDialog(),
    );
    if (ok == true && mounted) {
      showMessage(
        context,
        tr('Тасдиқ шуд. Android экрани несткуниро мекушояд.'),
      );
    }
  }

  /// Экрани танзимотро бо профил, PIN, огоҳиномаҳо, мавзӯъ ва навсозӣ месозад.
  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final child = session.isChild;
    var i = 0;
    return Scaffold(
      appBar: AppBar(title: Text(tr('Танзимот'))),
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
          const SizedBox(height: 12),
          ScreenHint(
            child
                ? tr(
                    'Ин телефон бо волидайн пайваст аст. Дар ин ҷо PIN, забон ва намуди барномаро тағйир диҳед.',
                  )
                : tr(
                    'Дар ин ҷо PIN-и волидайн, иҷозатҳо, забон ва намуди барномаро танзим кунед.',
                  ),
            icon: Icons.info_outline_rounded,
          ),
          SectionTitle(
            tr('Амният'),
            subtitle: tr('PIN-и волидайн ва иҷозатҳои Android.'),
          ),
          FadeIn(
            index: i++,
            child: _Group(
              children: [
                _Tile(
                  icon: Icons.pin_outlined,
                  color: NigohDesign.violet,
                  title: tr('PIN-и волидайн'),
                  subtitle:
                      pinError ??
                      (hasPin == null
                          ? tr('Санҷида мешавад…')
                          : hasPin!
                          ? tr('Фаъол аст — амалҳои муҳим PIN мепурсанд')
                          : tr('Гузошта нашудааст — ҳоло ҳимоя нест')),
                  subtitleColor: pinError != null ? scheme.error : null,
                  trailing: Text(
                    hasPin == true ? tr('Иваз кардан') : tr('Гузоштан'),
                    style: TextStyle(
                      color: scheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: pinError != null ? loadPin : editPin,
                ),
                const Divider(height: 1),
                _Tile(
                  key: const ValueKey('settings-wizard'),
                  icon: Icons.verified_user_outlined,
                  color: NigohDesign.mint,
                  title: tr('Иҷозатҳои Android'),
                  subtitle: child
                      ? tr('Ҷойгиршавӣ, истифода ва бастани барномаҳо')
                      : tr('Огоҳиномаҳо, камера, микрофон ва батарея'),
                  trailing: Text(
                    tr('Санҷидан'),
                    style: TextStyle(
                      color: scheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () async {
                    await PermissionsWizard.open(context, childMode: child);
                    if (mounted) await loadNotifyStatus();
                  },
                ),
              ],
            ),
          ),
          SectionTitle(tr('Намуд'), subtitle: tr('Ранг ва забони барнома.')),
          FadeIn(
            index: i++,
            child: _Group(
              children: [
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: ValueListenableBuilder<ThemeMode>(
                    valueListenable: themeModeSetting,
                    builder: (context, mode, _) => Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    tr('Режими торик'),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    tr('Шабона ба чашм осонтар.'),
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            DayNightSwitch(
                              key: const ValueKey('settings-day-night'),
                              value:
                                  mode == ThemeMode.dark ||
                                  (mode == ThemeMode.system &&
                                      MediaQuery.platformBrightnessOf(
                                            context,
                                          ) ==
                                          Brightness.dark),
                              semanticLabel: tr('Режими торик'),
                              onChanged: (dark) => themeModeSetting.set(
                                dark ? ThemeMode.dark : ThemeMode.light,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: SegmentedButton<ThemeMode>(
                            showSelectedIcon: false,
                            segments: [
                              ButtonSegment(
                                value: ThemeMode.system,
                                icon: const Icon(
                                  Icons.brightness_auto_outlined,
                                ),
                                label: Text(tr('Система')),
                              ),
                              ButtonSegment(
                                value: ThemeMode.light,
                                icon: const Icon(Icons.light_mode_outlined),
                                label: Text(tr('Равшан')),
                              ),
                              ButtonSegment(
                                value: ThemeMode.dark,
                                icon: const Icon(Icons.dark_mode_outlined),
                                label: Text(tr('Торик')),
                              ),
                            ],
                            selected: {mode},
                            onSelectionChanged: (value) =>
                                themeModeSetting.set(value.first),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 1),
                _Tile(
                  key: const ValueKey('settings-language'),
                  icon: Icons.language_rounded,
                  color: NigohDesign.sky,
                  title: tr('Забони барнома'),
                  subtitle: tr('Ҳоло: {language}', {
                    'language': AppLanguage.names[appLanguage.value],
                  }),
                  trailing: Text(
                    tr('Иваз кардан'),
                    style: TextStyle(
                      color: scheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () => showLanguageSheet(context),
                ),
              ],
            ),
          ),
          SectionTitle(
            tr('Барнома'),
            subtitle: tr('Версия, навсозӣ ва огоҳиномаҳо.'),
          ),
          FadeIn(
            index: i++,
            child: _Group(
              children: [
                _Tile(
                  icon: Icons.info_outline_rounded,
                  color: NigohDesign.sky,
                  title: tr('Версия'),
                  subtitle: version.isEmpty ? '—' : version,
                ),
                const Divider(height: 1),
                ValueListenableBuilder<String?>(
                  valueListenable: AppUpdate.lastError,
                  builder: (_, error, _) => _Tile(
                    icon: Icons.system_update_outlined,
                    color: NigohDesign.blue,
                    title: tr('Санҷидани навсозӣ'),
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
                            ? tr('Санҷида мешавад…')
                            : status == null
                            ? tr('Ҳолат маълум нашуд')
                            : !status.notifications
                            ? tr('Хомӯш аст — паёмҳо ва SOS намерасанд')
                            : !status.fullScreen
                            ? tr(
                                'Барои SOS ва зангҳо иҷозати экрани пурра лозим',
                              )
                            : tr('Фаъол: паёмҳо, SOS ва зангҳо'));
                    return _Tile(
                      icon: Icons.notifications_active_outlined,
                      color: NigohDesign.coral,
                      title: tr('Огоҳиномаҳо'),
                      subtitle: subtitle,
                      subtitleColor: error != null || (status != null && !ok)
                          ? scheme.error
                          : null,
                      trailing: ok || status == null
                          ? null
                          : Text(
                              status.notifications
                                  ? tr('Дидан')
                                  : tr('Иҷозат додан'),
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
          // Қадами дохилии танзимоти ҳисоб, забон, theme ва амният.
          if (child) ...[
            SectionTitle(
              tr('Нест кардани барнома'),
              subtitle: tr(
                'NIGOH пинҳон нест. Барномаро нест кардан мумкин аст, вале PIN-и волидайн лозим аст.',
              ),
            ),
            FadeIn(
              index: i++,
              child: _Group(
                children: [
                  _Tile(
                    key: const ValueKey('settings-uninstall'),
                    icon: Icons.delete_outline_rounded,
                    color: NigohDesign.coral,
                    title: tr('Нест кардани барнома'),
                    subtitle: hasPin == false
                        ? tr('Аввал волидайн PIN гузорад.')
                        : tr(
                            'PIN-и волидайнро мепурсад, баъд Android экрани несткуниро мекушояд.',
                          ),
                    trailing: Text(
                      tr('Нест кардан'),
                      style: TextStyle(
                        color: scheme.error,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    onTap: requestUninstall,
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          FadeIn(
            index: i++,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: scheme.error,
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: () => signOut(session),
              icon: const Icon(Icons.logout_rounded),
              label: Text(tr('Баромадан аз аккаунт')),
            ),
          ),
        ],
      ),
    );
  }
}

/// Widget-и ProfileCard-ро барои танзимоти ҳисоб, забон, theme ва амният месозад.
class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.session, required this.onEdit});
  final Session session;
  final VoidCallback onEdit;

  /// Widget-и ProfileCard-ро барои танзимоти ҳисоб ва барнома месозад.
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final name = session.displayName.isEmpty
        ? tr('Истифодабаранда')
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
                    session.isParent ? tr('Волидайн') : tr('Фарзанд'),
                    color: roleColor,
                    icon: session.isParent
                        ? Icons.family_restroom_rounded
                        : Icons.child_care_rounded,
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: tr('Тағйири ном'),
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined),
            ),
          ],
        ),
      ),
    );
  }
}

/// Додаҳо ва рафтори марбут ба танзимоти ҳисоб, забон, theme ва амниятро ифода мекунад.
class _Group extends StatelessWidget {
  const _Group({required this.children});
  final List<Widget> children;

  /// Widget-и Group-ро барои танзимоти ҳисоб ва барнома месозад.
  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: Column(children: children),
  );
}

/// Widget-и Tile-ро барои танзимоти ҳисоб, забон, theme ва амният месозад.
class _Tile extends StatelessWidget {
  const _Tile({
    super.key,
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

  /// Widget-и Tile-ро барои танзимоти ҳисоб ва барнома месозад.
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
    // Огоҳиномаи воридшударо дар Tile ба амали мувофиқ равона мекунад.
    subtitle: subtitle == null
        ? null
        : AnimatedSwitcher(
            duration: reducedMotion(context)
                ? Duration.zero
                : const Duration(milliseconds: 220),
            layoutBuilder: (current, previous) => Stack(
              alignment: AlignmentDirectional.centerStart,
              children: [...previous, ?current],
            ),
            child: Text(
              subtitle!,
              key: ValueKey(subtitle),
              style: TextStyle(color: subtitleColor),
            ),
          ),
    trailing:
        trailing ??
        (onTap != null ? const Icon(Icons.chevron_right_rounded) : null),
  );
}

/// Равзанаи NameDialog-ро барои танзимоти ҳисоб, забон, theme ва амният нишон медиҳад.
class _NameDialog extends StatefulWidget {
  const _NameDialog({required this.initial});
  final String initial;

  /// Ҳолати NameDialog-ро барои танзимоти ҳисоб ва барнома месозад.
  @override
  State<_NameDialog> createState() => _NameDialogState();
}

/// Ҳолат ва рафтори NameDialogState-ро барои навсозии интерфейс идора мекунад.
class _NameDialogState extends State<_NameDialog> {
  late final name = TextEditingController(text: widget.initial);

  /// Controller ва listener-ҳои NameDialog-ро озод мекунад.
  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  /// save тағйироти танзимот-ро барои истифодаи баъдӣ нигоҳ медорад.
  void save() {
    if (name.text.trim().isEmpty) return;
    Navigator.pop(context, name.text.trim());
  }

  /// Widget-и NameDialog-ро барои танзимоти ҳисоб ва барнома месозад.
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(tr('Ном')),
    content: TextField(
      controller: name,
      autofocus: true,
      textCapitalization: TextCapitalization.words,
      onSubmitted: (_) => save(),
      decoration: InputDecoration(labelText: tr('Номи шумо')),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(tr('Бекор')),
      ),
      FilledButton(
        style: FilledButton.styleFrom(minimumSize: const Size(110, 44)),
        onPressed: save,
        child: Text(tr('Нигоҳ доштан')),
      ),
    ],
  );
}

/// Равзанаи UninstallDialog-ро барои танзимоти ҳисоб, забон, theme ва амният нишон медиҳад.
class _UninstallDialog extends StatefulWidget {
  const _UninstallDialog();

  /// Ҳолати UninstallDialog-ро барои танзимоти ҳисоб ва барнома месозад.
  @override
  State<_UninstallDialog> createState() => _UninstallDialogState();
}

/// Ҳолат ва рафтори UninstallDialogState-ро барои навсозии интерфейс идора мекунад.
class _UninstallDialogState extends State<_UninstallDialog> {
  final pin = TextEditingController();
  String? error;
  bool busy = false;

  /// Controller ва listener-ҳои UninstallDialog-ро озод мекунад.
  @override
  void dispose() {
    pin.dispose();
    super.dispose();
  }

  /// submit дархости танзимот-ро ба API мефиристад ва натиҷаро коркард мекунад.
  Future<void> submit() async {
    final value = pin.text.trim();
    if (!UserJourneyLogic.validPin(value)) {
      return setState(() => error = tr('PIN бояд аз 4 рақам иборат бошад.'));
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      // Қадами дохилии танзимоти ҳисоб, забон, theme ва амният.
      final correct = await ParentPin.verify(value);
      if (!mounted) return;
      if (!correct) {
        return setState(
          () => error = tr('PIN нодуруст аст. Барнома нест карда нашуд.'),
        );
      }
      final result = await ParentPin.channel.invokeMapMethod<String, dynamic>(
        'requestUninstallWithPin',
        {'pin': value},
      );
      if (!mounted) return;
      if (result?['ok'] == true) return Navigator.pop(context, true);
      final code = result?['error'];
      setState(() {
        error = code == 'locked'
            ? tr(
                'Кӯшишҳо баста шуданд. Баъд аз {seconds} сония дубора кӯшиш кунед.',
                {'seconds': result?['remainingSeconds']},
              )
            : code == 'no_pin'
            ? tr('Аввал PIN-и волидайнро гузоред.')
            : tr('PIN нодуруст аст. Барнома нест карда нашуд.');
      });
    } on PlatformException catch (e) {
      if (mounted) setState(() => error = e.message ?? tr('Амал иҷро нашуд.'));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  /// Widget-и UninstallDialog-ро барои танзимоти ҳисоб ва барнома месозад.
  @override
  Widget build(BuildContext context) => AlertDialog(
    icon: const Icon(Icons.delete_outline_rounded, color: NigohDesign.coral),
    title: Text(tr('Нест кардани барнома')),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          tr(
            'Нест кардани NIGOH танҳо бо PIN-и волидайн мумкин аст. '
            'PIN-ро ворид кунед — баъд Android экрани несткуниро мекушояд.',
          ),
          style: const TextStyle(height: 1.4),
        ),
        const SizedBox(height: 14),
        TextField(
          key: const Key('uninstall-pin'),
          controller: pin,
          autofocus: true,
          obscureText: true,
          maxLength: 4,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onSubmitted: (_) => submit(),
          decoration: InputDecoration(
            labelText: tr('PIN-и волидайн'),
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
        child: Text(tr('Бекор')),
      ),
      FilledButton.icon(
        key: const Key('uninstall-confirm'),
        style: FilledButton.styleFrom(
          minimumSize: const Size(140, 46),
          backgroundColor: NigohDesign.coral,
          foregroundColor: Colors.white,
        ),
        onPressed: busy ? null : submit,
        icon: busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.delete_outline_rounded),
        label: Text(tr('Нест кардан')),
      ),
    ],
  );
}
