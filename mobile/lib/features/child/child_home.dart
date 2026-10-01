import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/session.dart';
import '../../pages/access_center_page.dart';
import '../../ui/nigoh_design.dart';
import '../../ui/widgets.dart';
import '../chat/chat_screen.dart';
import '../settings/settings_screen.dart';
import 'child_rules.dart';
import 'child_sync.dart';
import 'child_widgets.dart';

/// QR payload read by the parent's scanner (`UserJourneyLogic.pairingCode`
/// keeps only the 6 digits).
String pairingQrData(String code) => 'nigoh://pair/$code';

/// Home of the child's phone: pairing / status (with SOS, bedtime and screen
/// time), «Қоидаҳои ман», chat with the parent and settings. Owns the [ChildSync] background engine.
class ChildHome extends StatefulWidget {
  const ChildHome({super.key, this.sync});

  /// Injected engine (tests); by default one is created from the session.
  final ChildSync? sync;

  @override
  State<ChildHome> createState() => _ChildHomeState();
}

class _ChildHomeState extends State<ChildHome> with WidgetsBindingObserver {
  ChildSync? _sync;
  bool _ownsSync = false;
  int _tab = 0;
  bool _accessShown = false;

  ChildSync get sync => _sync!;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_sync != null) return;
    _ownsSync = widget.sync == null;
    _sync = widget.sync ?? ChildSync(api: SessionScope.read(context).api);
    _sync!.addListener(_onSync);
    _sync!.start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sync?.removeListener(_onSync);
    if (_ownsSync) _sync?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) sync.tick();
  }

  void _onSync() {
    if (!mounted) return;
    setState(() {});
    // Like the old app: open the permission wizard once if something
    // required is missing.
    if (!_accessShown &&
        sync.protectionKnown &&
        sync.missingPermissions.isNotEmpty) {
      _accessShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _openAccess());
    }
  }

  Future<void> _openAccess() async {
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Иҷозатҳо')),
          body: const AccessCenterPage(childMode: true),
        ),
      ),
    );
    if (mounted) await sync.refreshProtection();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final Widget page;
    switch (_tab) {
      case 1:
        page = sync.paired
            ? ChildRulesScreen(sync: sync)
            : const SafeArea(
                child: StateMessage(
                  icon: Icons.rule_rounded,
                  title: 'Ҳоло қоида нест',
                  text: 'Аввал телефонро бо волидайн пайваст кунед.',
                ),
              );
      case 2:
        final id = sync.childId;
        page = id == null
            ? Scaffold(
                appBar: AppBar(title: const Text('Чат')),
                body: sync.loading
                    ? const Center(child: CircularProgressIndicator())
                    : StateMessage(
                        icon: Icons.chat_bubble_outline_rounded,
                        title: 'Чат ҳоло омода нест',
                        text: sync.lastError ?? 'Пайвастшавӣ ба сервер…',
                        actionLabel: 'Аз нав кӯшиш',
                        onAction: sync.forceSync,
                        error: sync.lastError != null,
                      ),
              )
            : ChatScreen(
                key: ValueKey('chat-$id'),
                childId: id,
                title: sync.parentName ?? 'Волидайн',
              );
      case 3:
        page = const SettingsScreen();
      default:
        page = _HomeTab(sync: sync, onOpenAccess: _openAccess);
    }
    // The chat marks messages read while open, so no badge on that tab.
    final unread = _tab == 2 ? 0 : (sync.child?.unreadFromParent ?? 0);
    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: KeyedSubtree(key: ValueKey(_tab), child: page),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Асосӣ',
          ),
          const NavigationDestination(
            icon: Icon(Icons.rule_outlined),
            selectedIcon: Icon(Icons.rule_rounded),
            label: 'Қоидаҳо',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: unread > 0,
              label: Text('$unread'),
              child: const Icon(Icons.chat_bubble_outline_rounded),
            ),
            selectedIcon: const Icon(Icons.chat_bubble_rounded),
            label: 'Чат',
          ),
          const NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded),
            label: 'Танзимот',
          ),
        ],
      ),
    );
  }
}

class _HomeTab extends StatelessWidget {
  const _HomeTab({required this.sync, required this.onOpenAccess});
  final ChildSync sync;
  final VoidCallback onOpenAccess;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: sync.forceSync,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
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

// ---------------------------------------------------------------------------
// Not paired: QR + code
// ---------------------------------------------------------------------------

class _PairingView extends StatefulWidget {
  const _PairingView({super.key, required this.sync});
  final ChildSync sync;

  @override
  State<_PairingView> createState() => _PairingViewState();
}

class _PairingViewState extends State<_PairingView> {
  bool _busy = false;

  Future<void> _newCode() async {
    setState(() => _busy = true);
    try {
      await widget.sync.regenerateCode();
      if (mounted) showMessage(context, 'Коди нав сохта шуд');
    } catch (e) {
      if (mounted) showMessage(context, e, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

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
        const Text(
          'Пайвастшавӣ бо волидайн',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          'Волидайн ин QR-ро дар телефони худ скан мекунад.',
          style: TextStyle(color: scheme.onSurfaceVariant, height: 1.4),
        ),
        const SizedBox(height: 18),
        FadeIn(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
              child: Column(
                children: [
                  if (code == null || code.isEmpty)
                    SizedBox(
                      height: 220,
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
                  else
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        // White behind the QR so it scans in dark mode too.
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: QrImageView(
                        data: pairingQrData(code),
                        size: 200,
                        backgroundColor: Colors.white,
                      ),
                    ),
                  const SizedBox(height: 16),
                  if (spaced != null && spaced.isNotEmpty)
                    SelectableText(
                      spaced,
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 6,
                        color: scheme.onSurface,
                      ),
                    ),
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
                    label: const Text('Коди нав'),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SectionTitle('Чӣ тавр пайваст шавем'),
        const _Step(
          index: 1,
          text: 'Волидайн NIGOH Family-ро дар телефони худ мекушояд.',
        ),
        const _Step(
          index: 2,
          text: '«Илова кардани фарзанд»-ро интихоб мекунад.',
        ),
        const _Step(
          index: 3,
          text: 'QR-ро скан мекунад ё ин 6 рақамро ворид менамояд.',
        ),
        if (sync.lastError != null && code != null && code.isNotEmpty) ...[
          const SizedBox(height: 12),
          _ErrorCard(text: sync.lastError!, onRetry: sync.forceSync),
        ],
      ],
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.index, required this.text});
  final int index;
  final String text;

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

// ---------------------------------------------------------------------------
// Paired: status cards
// ---------------------------------------------------------------------------

class _PairedView extends StatelessWidget {
  const _PairedView({
    super.key,
    required this.sync,
    required this.onOpenAccess,
  });
  final ChildSync sync;
  final VoidCallback onOpenAccess;

  Future<void> _sendSos(BuildContext context) => sendChildSos(context, sync);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final missing = sync.missingPermissions;
    final protectionOk = sync.protectionKnown && missing.isEmpty;
    final child = sync.child;
    final bedtimeActive = child?.bedtime.activeAt(sync.now()) ?? false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: NigohDesign.mint.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.link_rounded, color: NigohDesign.mint),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Пайваст бо ${sync.parentName ?? 'волидайн'}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'NIGOH Family дар ин телефон фаъол аст.',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        if (bedtimeActive) ...[
          FadeIn(child: BedtimeNotice(bedtime: child!.bedtime)),
          const SizedBox(height: 12),
        ],
        if (sync.lastError != null) ...[
          FadeIn(
            child: _ErrorCard(text: sync.lastError!, onRetry: sync.forceSync),
          ),
          const SizedBox(height: 12),
        ],
        FadeIn(
          child: SosButton(onTriggered: () => _sendSos(context)),
        ),
        const SectionTitle('Вақти экрани ман'),
        FadeIn(
          index: 1,
          child: ScreenTimeCard(apps: child?.apps ?? const []),
        ),
        const SectionTitle('Ҳолати телефон'),
        FadeIn(
          index: 1,
          child: _StatusCard(
            icon: Icons.shield_rounded,
            color: protectionOk ? NigohDesign.mint : NigohDesign.amber,
            title: 'Ҳимоя',
            value: !sync.protectionKnown
                ? 'Санҷида мешавад…'
                : protectionOk
                ? 'Ҳамаи иҷозатҳо дода шудаанд'
                : '${missing.length} иҷозат намерасад',
            detail: protectionOk ? null : missing.join(', '),
            action: protectionOk || !sync.protectionKnown
                ? null
                : FilledButton.tonal(
                    onPressed: onOpenAccess,
                    child: const Text('Танзим кардан'),
                  ),
          ),
        ),
        const SizedBox(height: 12),
        FadeIn(
          index: 2,
          child: _StatusCard(
            icon: Icons.apps_rounded,
            color: NigohDesign.blue,
            title: 'Барномаҳо',
            value: sync.lastAppsSync == null
                ? 'Ҳоло фиристода нашудааст'
                : '${sync.appsCount} барнома',
            detail: sync.lastAppsSync == null
                ? null
                : 'Навсозӣ: ${timeAgo(sync.lastAppsSync)}',
          ),
        ),
        const SizedBox(height: 12),
        FadeIn(
          index: 3,
          child: _StatusCard(
            icon: Icons.location_on_rounded,
            color: NigohDesign.violet,
            title: 'Ҷойгиршавӣ',
            value: sync.lastLocationSync == null
                ? 'Ҳоло фиристода нашудааст'
                : 'Фиристода шуд',
            detail: sync.lastLocationSync == null
                ? null
                : timeAgo(sync.lastLocationSync),
          ),
        ),
      ],
    );
  }
}

/// Sends the SOS (message_type 'urgent') with the latest coordinates and
/// battery level; the result is always shown.
Future<void> sendChildSos(BuildContext context, ChildSync sync) async {
  final id = sync.childId;
  if (id == null) {
    showMessage(context, 'Ҳоло ба сервер пайваст нестем.', error: true);
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
      showMessage(context, 'SOS фиристода шуд. Волидайн огоҳ карда шуданд.');
    }
  } catch (e) {
    if (context.mounted) showMessage(context, e, error: true);
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.value,
    this.detail,
    this.action,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String value;
  final String? detail;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color),
            ),
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
                  if (detail != null && detail!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      detail!,
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ],
                  if (action != null) ...[const SizedBox(height: 10), action!],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatefulWidget {
  const _ErrorCard({required this.text, required this.onRetry});
  final String text;
  final Future<void> Function() onRetry;

  @override
  State<_ErrorCard> createState() => _ErrorCardState();
}

class _ErrorCardState extends State<_ErrorCard> {
  bool _busy = false;

  Future<void> _retry() async {
    setState(() => _busy = true);
    try {
      await widget.onRetry();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

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
                  label: const Text('Аз нав кӯшиш'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
