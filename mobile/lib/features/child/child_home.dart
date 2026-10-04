// Файл: саҳифаи асосии фарзанд ва ҳолати маҳдудиятҳо.

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/home_target.dart';
import '../../core/models.dart';
import '../../core/session.dart';
import '../../ui/nigoh_design.dart';
import '../../ui/widgets.dart';
import '../chat/chat_screen.dart';
import '../onboarding/permissions_wizard.dart';
import '../settings/settings_screen.dart';
import 'child_rules.dart';
import 'child_sync.dart';
import 'child_widgets.dart';
import '../../l10n/l10n.dart';

/// pairingQrData дархостро ба API мефиристад ва натиҷаро коркард мекунад.
String pairingQrData(String code) => 'nigoh://pair/$code';

/// Додаҳо ва рафтори марбут ба саҳифаи асосии фарзанд ва ҳолати маҳдудиятҳоро ифода мекунад.
class ChildHome extends StatefulWidget {
  const ChildHome({super.key, this.sync});

  /// Қимати sync-ро барои саҳифаи асосии фарзанд ва ҳолати маҳдудиятҳо нигоҳ медорад.
  final ChildSync? sync;

  /// Ҳолати ChildHome-ро барои саҳифаи асосӣ ва пайвасткунии фарзанд месозад.
  @override
  State<ChildHome> createState() => _ChildHomeState();
}

/// Ҳолат ва рафтори ChildHomeState-ро барои навсозии интерфейс идора мекунад.
class _ChildHomeState extends State<ChildHome> with WidgetsBindingObserver {
  ChildSync? _sync;
  bool _ownsSync = false;
  int _tab = 0;
  bool _accessShown = false;

  /// Қимати ҳисобшудаи sync-ро аз ҳолати ҷорӣ бармегардонад.
  ChildSync get sync => _sync!;

  /// Ҳадафи аз огоҳинома омадаро мешунавад ва бахши мувофиқи экрани фарзандро мекушояд.
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    homeTarget.addListener(_onHomeTarget);
    // Огоҳиномаи воридшударо дар ChildHome ба амали мувофиқ равона мекунад.
    WidgetsBinding.instance.addPostFrameCallback((_) => _onHomeTarget());
  }

  /// onHomeTarget рӯйдодро коркард карда, ҳолати вобастаро нав мекунад.
  void _onHomeTarget() {
    final target = homeTarget.value;
    if (target == null || !mounted) return;
    homeTarget.value = null;
    final tab = switch (target.kind) {
      'chat' => 2,
      'requests' => 1,
      _ => 0,
    };
    setState(() => _tab = tab);
  }

  /// Пас аз тағйири dependency-ҳо ҳолати вобастаро нав мекунад.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_sync != null) return;
    _ownsSync = widget.sync == null;
    _sync = widget.sync ?? ChildSync(api: SessionScope.read(context).api);
    _sync!.addListener(_onSync);
    _sync!.start();
  }

  /// Controller ва listener-ҳои ChildHome-ро озод мекунад.
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    homeTarget.removeListener(_onHomeTarget);
    _sync?.removeListener(_onSync);
    if (_ownsSync) _sync?.dispose();
    super.dispose();
  }

  /// Ба тағйири lifecycle-и ChildHome ҷавоб медиҳад.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) sync.tick();
  }

  /// onSync рӯйдодро коркард карда, ҳолати вобастаро нав мекунад.
  void _onSync() {
    if (!mounted) return;
    setState(() {});
    // openAccess иҷозати зарурии Android-ро месанҷад ё дархост мекунад.
    if (!_accessShown &&
        !PermissionsWizard.shownThisSession &&
        sync.protectionKnown &&
        sync.missingPermissions.isNotEmpty) {
      _accessShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _openAccess());
    }
  }

  /// openAccess экран, dialog ё танзимоти мувофиқро мекушояд.
  Future<void> _openAccess() async {
    if (!mounted) return;
    _accessShown = true;
    await PermissionsWizard.open(context, childMode: true);
    if (mounted) await sync.refreshProtection();
    if (mounted) setState(() {});
  }

  /// Экрани фарзандро бо Home, қоидаҳо, чат ва танзимот месозад.
  @override
  Widget build(BuildContext context) {
    final Widget page;
    switch (_tab) {
      case 1:
        page = sync.paired
            ? ChildRulesScreen(sync: sync)
            : SafeArea(
                child: StateMessage(
                  icon: Icons.rule_rounded,
                  title: tr('Ҳоло қоида нест'),
                  text: tr('Аввал телефонро бо волидайн пайваст кунед.'),
                  actionLabel: tr('Кушодани пайвастшавӣ'),
                  onAction: () => setState(() => _tab = 0),
                ),
              );
      case 2:
        final id = sync.childId;
        page = id == null
            ? Scaffold(
                appBar: AppBar(title: Text(tr('Чат'))),
                body: sync.loading
                    ? const Center(child: CircularProgressIndicator())
                    : StateMessage(
                        icon: Icons.chat_bubble_outline_rounded,
                        title: tr('Чат ҳоло омода нест'),
                        text: sync.lastError ?? tr('Пайвастшавӣ ба сервер…'),
                        actionLabel: tr('Аз нав кӯшиш'),
                        onAction: sync.forceSync,
                        error: sync.lastError != null,
                      ),
              )
            : ChatScreen(
                key: ValueKey('chat-$id'),
                childId: id,
                title: sync.parentName ?? tr('Волидайн'),
                avatarPath: sync.child?.parentAvatar,
              );
      case 3:
        page = const SettingsScreen();
      default:
        page = _HomeTab(sync: sync, onOpenAccess: _openAccess);
    }
    // Қадами дохилии unread барои саҳифаи фарзанд.
    final unread = _tab == 2 ? 0 : (sync.child?.unreadFromParent ?? 0);
    return Scaffold(
      body: AnimatedSwitcher(
        duration: childReducedMotion(context)
            ? Duration.zero
            : const Duration(milliseconds: 220),
        child: KeyedSubtree(key: ValueKey(_tab), child: page),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home_rounded),
            label: tr('Асосӣ'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.rule_outlined),
            selectedIcon: const Icon(Icons.rule_rounded),
            label: tr('Қоидаҳо'),
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: unread > 0,
              label: Text('$unread'),
              child: const Icon(Icons.chat_bubble_outline_rounded),
            ),
            selectedIcon: const Icon(Icons.chat_bubble_rounded),
            label: tr('Чат'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings_rounded),
            label: tr('Танзимот'),
          ),
        ],
      ),
    );
  }
}

/// Додаҳо ва рафтори марбут ба саҳифаи асосии фарзанд ва ҳолати маҳдудиятҳоро ифода мекунад.
class _HomeTab extends StatelessWidget {
  const _HomeTab({required this.sync, required this.onOpenAccess});
  final ChildSync sync;
  final VoidCallback onOpenAccess;

  /// Widget-и HomeTab-ро барои саҳифаи асосӣ ва пайвасткунии фарзанд месозад.
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: sync.forceSync,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          children: [
            AnimatedSwitcher(
              duration: childReducedMotion(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 250),
              child: sync.loading && sync.childId == null
                  ? const Padding(
                      key: ValueKey('loading'),
                      padding: EdgeInsets.only(top: 120),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : sync.paired
                  ? _PairedView(
                      key: const ValueKey('paired'),
                      sync: sync,
                      onOpenAccess: onOpenAccess,
                    )
                  : _PairingView(key: const ValueKey('pairing'), sync: sync),
            ),
          ],
        ),
      ),
    );
  }
}

// Қадами дохилии PairingView барои саҳифаи фарзанд.

/// Widget-и PairingView-ро барои саҳифаи асосии фарзанд ва ҳолати маҳдудиятҳо месозад.
class _PairingView extends StatefulWidget {
  const _PairingView({super.key, required this.sync});
  final ChildSync sync;

  /// Ҳолати PairingView-ро барои саҳифаи асосӣ ва пайвасткунии фарзанд месозад.
  @override
  State<_PairingView> createState() => _PairingViewState();
}

/// Ҳолат ва рафтори PairingViewState-ро барои навсозии интерфейс идора мекунад.
class _PairingViewState extends State<_PairingView> {
  bool _busy = false;

  /// newCode мантиқи зарурии саҳифаи асосии фарзанд ва ҳолати маҳдудиятҳоро иҷро мекунад.
  Future<void> _newCode() async {
    setState(() => _busy = true);
    try {
      await widget.sync.regenerateCode();
      if (mounted) showMessage(context, tr('Коди нав сохта шуд'));
    } catch (e) {
      if (mounted) showMessage(context, e, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Widget-и PairingView-ро барои саҳифаи асосӣ ва пайвасткунии фарзанд месозад.
  @override
  Widget build(BuildContext context) {
    final sync = widget.sync;
    final scheme = Theme.of(context).colorScheme;
    final code = sync.pairingCode;
    final spaced = code == null || code.length != 6
        ? code
        : '${code.substring(0, 3)} ${code.substring(3)}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          tr('Пайвастшавӣ бо волидайн'),
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          tr('Ин телефонро ба волидайн пайваст кунед — як маротиба.'),
          style: TextStyle(color: scheme.onSurfaceVariant, height: 1.4),
        ),
        const SizedBox(height: 18),
        FadeIn(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
              child: Column(
                children: [
                  Text(
                    tr('Волидайн ин QR-ро дар телефони худ скан мекунад.'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 14),
                  AnimatedSwitcher(
                    duration: childReducedMotion(context)
                        ? Duration.zero
                        : const Duration(milliseconds: 250),
                    child: code == null || code.isEmpty
                        ? SizedBox(
                            key: const ValueKey('qr-wait'),
                            height: 224,
                            child: Center(
                              child: sync.lastError != null
                                  ? Text(
                                      sync.lastError!,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: scheme.error),
                                    )
                                  : const CircularProgressIndicator(),
                            ),
                          )
                        : Container(
                            key: const ValueKey('qr'),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              // Қадами дохилии circular барои саҳифаи фарзанд.
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: QrImageView(
                              data: pairingQrData(code),
                              size: 200,
                              backgroundColor: Colors.white,
                            ),
                          ),
                  ),
                  if (spaced != null && spaced.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    Text(
                      tr('Ё ин коди 6-рақама'),
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 6),
                    FittedBox(
                      child: SelectableText(
                        spaced,
                        style: TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 8,
                          color: scheme.primary,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  TextButton.icon(
                    onPressed: _busy ? null : _newCode,
                    icon: _busy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh_rounded),
                    label: Text(tr('Коди нав')),
                  ),
                ],
              ),
            ),
          ),
        ),
        SectionTitle(tr('Чӣ тавр пайваст шавем')),
        FadeIn(
          index: 1,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
              child: Column(
                children: [
                  _Step(
                    index: 1,
                    text: tr(
                      'Волидайн NIGOH Family-ро дар телефони худ мекушояд.',
                    ),
                  ),
                  _Step(
                    index: 2,
                    text: tr('«Илова кардани фарзанд»-ро интихоб мекунад.'),
                  ),
                  _Step(
                    index: 3,
                    text: tr(
                      'QR-ро скан мекунад ё ин 6 рақамро ворид менамояд.',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (sync.lastError != null && code != null && code.isNotEmpty) ...[
          const SizedBox(height: 12),
          _ErrorCard(text: sync.lastError!, onRetry: sync.forceSync),
        ],
      ],
    );
  }
}

/// Додаҳо ва рафтори марбут ба саҳифаи асосии фарзанд ва ҳолати маҳдудиятҳоро ифода мекунад.
class _Step extends StatelessWidget {
  const _Step({required this.index, required this.text});
  final int index;
  final String text;

  /// Widget-и Step-ро барои саҳифаи асосӣ ва пайвасткунии фарзанд месозад.
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: .12),
              shape: BoxShape.circle,
            ),
            child: Text(
              '$index',
              style: TextStyle(
                color: scheme.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(text, style: const TextStyle(height: 1.35)),
            ),
          ),
        ],
      ),
    );
  }
}

// Қадами дохилии PairedView барои саҳифаи фарзанд.

/// Widget-и PairedView-ро барои саҳифаи асосии фарзанд ва ҳолати маҳдудиятҳо месозад.
class _PairedView extends StatelessWidget {
  const _PairedView({
    super.key,
    required this.sync,
    required this.onOpenAccess,
  });
  final ChildSync sync;
  final VoidCallback onOpenAccess;

  /// sendSos дархостро ба API мефиристад ва натиҷаро коркард мекунад.
  Future<void> _sendSos(BuildContext context) => sendChildSos(context, sync);

  /// Widget-и PairedView-ро барои саҳифаи асосӣ ва пайвасткунии фарзанд месозад.
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final missing = sync.missingPermissions;
    final protectionOk = sync.protectionKnown && missing.isEmpty;
    final child = sync.child;
    final bedtimeActive = child?.bedtime.activeAt(sync.now()) ?? false;
    final studyActive =
        !bedtimeActive && (child?.study.activeAt(sync.now()) ?? false);
    final appsOk = sync.lastAppsSync != null;
    final locationOk = sync.lastLocationSync != null;
    final needsPermissions = sync.protectionKnown && !protectionOk;
    final protectionCard = FadeIn(
      index: 2,
      child: _StatusCard(
        icon: Icons.shield_rounded,
        ok: protectionOk,
        unknown: !sync.protectionKnown,
        title: tr('Ҳимоя'),
        value: !sync.protectionKnown
            ? tr('Санҷида мешавад…')
            : protectionOk
            ? tr('Ҳамаи иҷозатҳо дода шудаанд')
            : tr('{n} иҷозат намерасад', {'n': missing.length}),
        hint: protectionOk
            ? tr('Қоидаҳои волидайн дар ин телефон кор мекунанд.')
            : tr('Бе ин иҷозатҳо қоидаҳо кор намекунанд: {list}', {
                'list': missing.map(tr).join(', '),
              }),
        action: !sync.protectionKnown
            ? null
            : protectionOk
            ? TextButton(onPressed: onOpenAccess, child: Text(tr('Иҷозатҳо')))
            : FilledButton.icon(
                onPressed: onOpenAccess,
                icon: const Icon(Icons.build_rounded, size: 18),
                label: Text(tr('Дуруст кардан')),
              ),
      ),
    );
    // Филтри сайтҳо: танҳо вақте нишон дода мешавад, ки волидайн онро фаъол кардаанд.
    final filter = child?.webFilter ?? const WebFilter();
    final filterOk = sync.webFilterState == WebFilter.stateActive;
    final filterNeedsAction = filter.enabled && !filterOk;
    final filterCard = !filter.enabled
        ? null
        : FadeIn(
            index: 5,
            child: _StatusCard(
              key: const ValueKey('child-web-filter'),
              icon: Icons.travel_explore_rounded,
              ok: filterOk,
              okColor: NigohDesign.mint,
              title: tr('Филтри сайтҳо'),
              value: filterOk
                  ? tr('Фаъол: {level}', {
                      'level': filter.level == WebFilter.levelKids
                          ? tr('То 12 сола')
                          : tr('13–17 сола'),
                    })
                  : tr('Иҷозат лозим аст'),
              hint: filterOk
                  ? tr(
                      'Сайтҳое, ки барои синну соли шумо нестанд, кушода намешаванд.',
                    )
                  : tr(
                      'Волидайн филтри сайтҳоро фаъол карданд. «Иҷозат додан»-ро пахш кунед ва дар тирезаи Android «OK»-ро интихоб кунед.',
                    ),
              action: filterOk
                  ? null
                  : FilledButton.icon(
                      key: const ValueKey('child-web-filter-allow'),
                      onPressed: sync.requestWebFilterPermission,
                      icon: const Icon(Icons.vpn_lock_rounded, size: 18),
                      label: Text(tr('Иҷозат додан')),
                    ),
            ),
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const ChildIconTile(
              icon: Icons.link_rounded,
              color: NigohDesign.mint,
              size: 48,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr('Пайваст бо {name}', {
                      'name': sync.parentName ?? tr('волидайн'),
                    }),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    tr('NIGOH Family дар ин телефон фаъол аст.'),
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        AnimatedSize(
          duration: childReducedMotion(context)
              ? Duration.zero
              : const Duration(milliseconds: 250),
          alignment: Alignment.topCenter,
          curve: Curves.easeOutCubic,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (bedtimeActive) ...[
                FadeIn(child: BedtimeNotice(bedtime: child!.bedtime)),
                const SizedBox(height: 12),
              ],
              if (studyActive) ...[
                FadeIn(child: StudyNotice(study: child!.study)),
                const SizedBox(height: 12),
              ],
              if (sync.lastError != null) ...[
                FadeIn(
                  child: _ErrorCard(
                    text: sync.lastError!,
                    onRetry: sync.forceSync,
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
        // Қадами дохилии SizedBox барои саҳифаи фарзанд.
        if (needsPermissions) ...[protectionCard, const SizedBox(height: 12)],
        if (filterNeedsAction && filterCard != null) ...[
          filterCard,
          const SizedBox(height: 12),
        ],
        FadeIn(child: SosButton(onTriggered: () => _sendSos(context))),
        SectionTitle(tr('Ҳолати телефон')),
        FadeIn(index: 1, child: ScreenTimeCard(apps: child?.apps ?? const [])),
        const SizedBox(height: 12),
        if (!needsPermissions) ...[protectionCard, const SizedBox(height: 12)],
        const SizedBox(height: 12),
        FadeIn(
          index: 3,
          child: _StatusCard(
            icon: Icons.apps_rounded,
            ok: appsOk,
            okColor: NigohDesign.blue,
            title: tr('Барномаҳо'),
            value: appsOk
                ? tr('{n} барнома', {'n': sync.appsCount})
                : tr('Ҳоло фиристода нашудааст'),
            hint: appsOk
                ? tr('Волидайн рӯйхати барномаҳои ин телефонро мебинанд.')
                : tr('Рӯйхати барномаҳо ҳоло ба волидайн нарасидааст.'),
            detail: appsOk
                ? tr('Навсозӣ: {time}', {'time': timeAgo(sync.lastAppsSync)})
                : null,
            action: appsOk
                ? null
                : _RetryButton(
                    label: tr('Ҳозир фиристодан'),
                    onTap: sync.forceSync,
                  ),
          ),
        ),
        const SizedBox(height: 12),
        FadeIn(
          index: 4,
          child: _StatusCard(
            icon: Icons.location_on_rounded,
            ok: locationOk,
            okColor: NigohDesign.violet,
            title: tr('Ҷойгиршавӣ'),
            value: locationOk
                ? tr('Фиристода шуд')
                : tr('Ҳоло фиристода нашудааст'),
            hint: locationOk
                ? tr('Волидайн мебинанд, ки шумо дар куҷо ҳастед.')
                : tr('Ҷои шумо ҳоло ба волидайн нарасидааст.'),
            detail: locationOk ? timeAgo(sync.lastLocationSync) : null,
            action: locationOk
                ? null
                : _RetryButton(
                    label: tr('Аз нав кӯшиш'),
                    onTap: sync.forceSync,
                  ),
          ),
        ),
        if (!filterNeedsAction && filterCard != null) ...[
          const SizedBox(height: 12),
          filterCard,
        ],
      ],
    );
  }
}

/// Widget-и RetryButton-ро барои саҳифаи асосии фарзанд ва ҳолати маҳдудиятҳо месозад.
class _RetryButton extends StatefulWidget {
  const _RetryButton({required this.label, required this.onTap});
  final String label;
  final Future<void> Function() onTap;

  /// Ҳолати RetryButton-ро барои саҳифаи асосӣ ва пайвасткунии фарзанд месозад.
  @override
  State<_RetryButton> createState() => _RetryButtonState();
}

/// Ҳолат ва рафтори RetryButtonState-ро барои навсозии интерфейс идора мекунад.
class _RetryButtonState extends State<_RetryButton> {
  bool _busy = false;

  /// run мантиқи зарурии саҳифаи асосии фарзанд ва ҳолати маҳдудиятҳоро иҷро мекунад.
  Future<void> _run() async {
    setState(() => _busy = true);
    try {
      await widget.onTap();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Widget-и RetryButton-ро барои саҳифаи асосӣ ва пайвасткунии фарзанд месозад.
  @override
  Widget build(BuildContext context) => FilledButton.tonalIcon(
    onPressed: _busy ? null : _run,
    icon: _busy
        ? const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : const Icon(Icons.sync_rounded, size: 18),
    label: Text(widget.label),
  );
}

/// sendChildSos дархостро ба API мефиристад ва натиҷаро коркард мекунад.
Future<void> sendChildSos(BuildContext context, ChildSync sync) async {
  final id = sync.childId;
  if (id == null) {
    showMessage(context, tr('Ҳоло ба сервер пайваст нестем.'), error: true);
    return;
  }
  final position = sync.lastPosition;
  final server = sync.child?.location;
  final battery = await sync.readBattery() ?? sync.batteryLevel;
  final text = sosMessageText(
    latitude: position?.latitude ?? server?.latitude,
    longitude: position?.longitude ?? server?.longitude,
    battery: battery,
  );
  try {
    await sync.api.sendChat(id, text, messageType: 'urgent');
    if (context.mounted) {
      showMessage(
        context,
        tr('SOS фиристода шуд. Волидайн огоҳ карда шуданд.'),
      );
    }
  } catch (e) {
    if (context.mounted) showMessage(context, e, error: true);
  }
}

/// Widget-и StatusCard-ро барои саҳифаи асосии фарзанд ва ҳолати маҳдудиятҳо месозад.
class _StatusCard extends StatelessWidget {
  const _StatusCard({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.hint,
    required this.ok,
    this.unknown = false,
    this.okColor = NigohDesign.mint,
    this.detail,
    this.action,
  });

  final IconData icon;
  final String title;
  final String value;

  /// Қимати hint-ро барои саҳифаи асосии фарзанд ва ҳолати маҳдудиятҳо нигоҳ медорад.
  final String hint;

  /// Қимати ok-ро барои саҳифаи асосии фарзанд ва ҳолати маҳдудиятҳо нигоҳ медорад.
  final bool ok;

  /// Қимати unknown-ро барои саҳифаи асосии фарзанд ва ҳолати маҳдудиятҳо нигоҳ медорад.
  final bool unknown;
  final Color okColor;
  final String? detail;
  final Widget? action;

  /// Widget-и StatusCard-ро барои саҳифаи асосӣ ва пайвасткунии фарзанд месозад.
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = unknown
        ? scheme.onSurfaceVariant
        : ok
        ? okColor
        : NigohDesign.amber;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ChildIconTile(icon: icon, color: color),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        value,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!unknown) ...[
                  const SizedBox(width: 8),
                  AnimatedSwitcher(
                    duration: childReducedMotion(context)
                        ? Duration.zero
                        : const Duration(milliseconds: 250),
                    child: Pill(
                      ok ? tr('Хуб') : tr('Диққат'),
                      key: ValueKey(ok),
                      color: ok ? okColor : NigohDesign.amber,
                      icon: ok
                          ? Icons.check_circle_rounded
                          : Icons.error_outline_rounded,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            Text(
              hint,
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 13,
                height: 1.35,
              ),
            ),
            if (detail != null && detail!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                detail!,
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 12.5,
                ),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: 12),
              Align(alignment: Alignment.centerLeft, child: action!),
            ],
          ],
        ),
      ),
    );
  }
}

/// Widget-и ErrorCard-ро барои саҳифаи асосии фарзанд ва ҳолати маҳдудиятҳо месозад.
class _ErrorCard extends StatefulWidget {
  const _ErrorCard({required this.text, required this.onRetry});
  final String text;
  final Future<void> Function() onRetry;

  /// Ҳолати ErrorCard-ро барои саҳифаи асосӣ ва пайвасткунии фарзанд месозад.
  @override
  State<_ErrorCard> createState() => _ErrorCardState();
}

/// Ҳолат ва рафтори ErrorCardState-ро барои навсозии интерфейс идора мекунад.
class _ErrorCardState extends State<_ErrorCard> {
  bool _busy = false;

  /// retry мантиқи зарурии саҳифаи асосии фарзанд ва ҳолати маҳдудиятҳоро иҷро мекунад.
  Future<void> _retry() async {
    setState(() => _busy = true);
    try {
      await widget.onRetry();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Widget-и ErrorCard-ро барои саҳифаи асосӣ ва пайвасткунии фарзанд месозад.
  @override
  Widget build(BuildContext context) {
    const color = NigohDesign.amber;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: .35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.text, style: const TextStyle(height: 1.35)),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: _busy ? null : _retry,
                  icon: _busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh_rounded),
                  label: Text(tr('Аз нав кӯшиш')),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
