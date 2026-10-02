import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api.dart';
import '../../core/home_target.dart';
import '../../core/models.dart';
import '../../core/session.dart';
import '../../ui/avatar.dart';
import '../../ui/nigoh_design.dart';
import '../../ui/widgets.dart';
import '../call/call_screen.dart';
import '../chat/chat_screen.dart';
import '../settings/parent_pin.dart';
import '../settings/settings_screen.dart';
import 'add_child_screen.dart';
import 'apps_screen.dart';
import 'family_controller.dart';
import 'map_screen.dart';
import 'parent_logic.dart';
import 'parent_sheets.dart';
import 'requests_screen.dart';
import 'study_sheet.dart';
import 'weekly_report.dart';
import '../../l10n/l10n.dart';

/// Parent side: family overview, app rules, map, chat and settings.
class ParentHome extends StatefulWidget {
  const ParentHome({super.key, this.controller});

  /// Injected in tests; otherwise created from the session's API.
  final FamilyController? controller;

  @override
  State<ParentHome> createState() => _ParentHomeState();
}

class _ParentHomeState extends State<ParentHome> {
  FamilyController? _controller;
  bool _owned = false;
  int _tab = 0;

  /// Last «mark read» attempt (child-unread-urgent) so it isn't repeated.
  String? _readMarked;

  FamilyController get controller => _controller!;

  @override
  void initState() {
    super.initState();
    homeTarget.addListener(_onHomeTarget);
    // Opened from a notification before this screen existed.
    WidgetsBinding.instance.addPostFrameCallback((_) => _onHomeTarget());
  }

  /// Notification tap: select the child and switch to chat / map / overview,
  /// or open the extra-time requests.
  void _onHomeTarget() {
    final target = homeTarget.value;
    if (target == null || !mounted || _controller == null) return;
    homeTarget.value = null;
    final childId = target.childId;
    if (childId != null) controller.select(childId);
    final tab = switch (target.kind) {
      'chat' => 3,
      'map' => 2,
      _ => 0,
    };
    setState(() => _tab = tab);
    if (target.kind == 'requests') _openRequests();
  }

  /// When a child's chat is visible and has unread messages (or an SOS),
  /// tell the server they were seen; this also clears the SOS banner.
  void _markReadIfNeeded() {
    if (_tab != 3) return;
    final child = controller.selected;
    if (child == null) return;
    if (child.unreadFromChild == 0 && child.lastUrgent == null) return;
    final key = '${child.id}-${child.unreadFromChild}-${child.lastUrgent?.id}';
    if (key == _readMarked) return;
    _readMarked = key;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await controller.markChatRead(child.id);
      } catch (e) {
        if (mounted) showMessage(context, e, error: true);
      }
    });
  }

  void _openRequests() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TimeRequestsScreen(controller: controller),
      ),
    );
  }

  void _openReport(FamilyChild child) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => WeeklyReportScreen(api: controller.api, child: child),
      ),
    );
  }

  void _openBedtime(FamilyChild child) {
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => BedtimeSheet(controller: controller, child: child),
    );
  }

  void _openStudy(FamilyChild child) {
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => StudySheet(controller: controller, child: child),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller != null) return;
    if (widget.controller != null) {
      _controller = widget.controller;
    } else {
      _controller = FamilyController(SessionScope.read(context).api);
      _owned = true;
    }
    controller.start();
  }

  @override
  void dispose() {
    homeTarget.removeListener(_onHomeTarget);
    if (_owned) _controller?.dispose();
    super.dispose();
  }

  Future<void> _addChild() async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => AddChildScreen(controller: controller)),
    );
    if (ok == true && mounted) showMessage(context, tr('Фарзанд пайваст шуд'));
  }

  void _open(int tab, FamilyChild child) {
    controller.select(child.id);
    setState(() => _tab = tab);
  }

  /// Removing a child always needs the parent PIN. Without one yet, the
  /// parent creates it first; then it is checked. False = stop.
  Future<bool> _requirePin(FamilyChild child) async {
    bool hasPin;
    try {
      hasPin = await ParentPin.isSet();
    } catch (e) {
      if (mounted) {
        showMessage(
          context,
          tr('PIN санҷида нашуд: {error}', {
            'error': e is PlatformException ? e.message ?? e.code : e,
          }),
          error: true,
        );
      }
      return false;
    }
    if (!mounted) return false;
    if (!hasPin) {
      final created = await ParentPin.setUp(
        context,
        text: tr(
          'Барои хориҷ кардани фарзанд аввал PIN-и волидайнро гузоред. Ин PIN дар ҳамин телефон нигоҳ дошта мешавад.',
        ),
      );
      if (!created || !mounted) return false;
    }
    final ok = await ParentPin.ask(
      context,
      title: tr('PIN-ро ворид кунед'),
      text: tr('Барои хориҷ кардани {name} PIN-и волидайн лозим аст.', {
        'name': child.name,
      }),
    );
    return ok && mounted;
  }

  Future<void> _removeChild(FamilyChild child) async {
    if (!await _requirePin(child) || !mounted) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(tr('{name}-ро хориҷ кунем?', {'name': child.name})),
        content: Text(
          tr(
            'Қоидаҳо ва чат барои ин фарзанд дигар дастрас намешаванд. Барои пайвасти дубора коди навро скан кунед.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(tr('Бекор')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size(110, 44),
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
              foregroundColor: Theme.of(dialogContext).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(tr('Хориҷ кардан')),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await controller.unlink(child);
      if (mounted) {
        showMessage(context, tr('{name} хориҷ шуд', {'name': child.name}));
      }
    } catch (e) {
      if (mounted) showMessage(context, e, error: true);
    }
  }

  static const _titles = ['Оила', 'Барномаҳо', 'Харита', 'Чат', 'Танзимот'];

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final children = controller.children;
        Widget body;
        if (_tab == 4) {
          body = const SettingsScreen();
        } else if (!controller.loadedOnce && controller.error == null) {
          body = const Center(child: CircularProgressIndicator());
        } else if (children.isEmpty && controller.error != null) {
          body = StateMessage(
            icon: Icons.cloud_off_rounded,
            title: tr('Маълумот гирифта нашуд'),
            text: controller.error,
            actionLabel: tr('Аз нав кӯшиш'),
            onAction: controller.refresh,
            error: true,
          );
        } else if (children.isEmpty) {
          body = _EmptyFamily(onAdd: _addChild);
        } else {
          body = _tabBody(session.displayName, session.avatar);
          _markReadIfNeeded();
        }
        final unread = controller.unreadTotal;
        return Scaffold(
          // Chat and Settings bring their own app bar.
          appBar: _tab >= 3 ? null : AppBar(title: Text(tr(_titles[_tab]))),
          body: SafeArea(
            top: _tab >= 3,
            bottom: false,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: KeyedSubtree(
                key: ValueKey('tab-$_tab-${children.isEmpty}'),
                child: body,
              ),
            ),
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _tab,
            onDestinationSelected: (i) => setState(() => _tab = i),
            destinations: [
              NavigationDestination(
                icon: Badge(
                  isLabelVisible:
                      controller.urgentChildren.isNotEmpty ||
                      controller.pendingRequestsTotal > 0,
                  backgroundColor: controller.urgentChildren.isNotEmpty
                      ? null
                      : NigohDesign.amber,
                  smallSize: 9,
                  child: const Icon(Icons.family_restroom_outlined),
                ),
                selectedIcon: const Icon(Icons.family_restroom_rounded),
                label: tr('Оила'),
              ),
              NavigationDestination(
                icon: Icon(Icons.apps_outlined),
                selectedIcon: Icon(Icons.apps_rounded),
                label: tr('Барномаҳо'),
              ),
              NavigationDestination(
                icon: Icon(Icons.map_outlined),
                selectedIcon: Icon(Icons.map_rounded),
                label: tr('Харита'),
              ),
              NavigationDestination(
                key: const ValueKey('nav-chat'),
                icon: Badge.count(
                  count: unread,
                  isLabelVisible: unread > 0,
                  child: const Icon(Icons.chat_bubble_outline_rounded),
                ),
                selectedIcon: Badge.count(
                  count: unread,
                  isLabelVisible: unread > 0,
                  child: const Icon(Icons.chat_bubble_rounded),
                ),
                label: tr('Чат'),
              ),
              NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings_rounded),
                label: tr('Танзимот'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _tabBody(String parentName, String? parentAvatar) {
    if (_tab == 0) {
      return _Overview(
        controller: controller,
        parentName: parentName,
        parentAvatar: parentAvatar,
        onAdd: _addChild,
        onOpen: _open,
        onRemove: _removeChild,
        onRequests: _openRequests,
        onReport: _openReport,
        onBedtime: _openBedtime,
        onStudy: _openStudy,
      );
    }
    final selected = controller.selected!;
    final Widget content = switch (_tab) {
      1 => AppsScreen(controller: controller),
      2 => MapScreen(controller: controller),
      _ => KeyedSubtree(
        key: ValueKey('chat-${selected.id}'),
        child: ChatScreen(
          childId: selected.id,
          title: selected.name,
          avatarPath: selected.childAvatar,
        ),
      ),
    };
    return Column(
      children: [
        if (controller.children.length > 1)
          _ChildSelector(
            api: controller.api,
            children: controller.children,
            selectedId: selected.id,
            onSelect: controller.select,
            showUnread: _tab == 3,
          ),
        Expanded(child: content),
      ],
    );
  }
}

class _EmptyFamily extends StatelessWidget {
  const _EmptyFamily({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          StateMessage(
            icon: Icons.family_restroom_rounded,
            title: tr('Ҳоло фарзанд пайваст нашудааст'),
            text: tr(
              'Телефони фарзандро пайваст кунед, то барномаҳо, ҷойгиршавӣ ва чатро бинед.',
            ),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size(260, 56)),
            onPressed: onAdd,
            icon: const Icon(Icons.person_add_alt_1_rounded),
            label: Text(tr('Илова кардани фарзанд')),
          ),
        ],
      ),
    ),
  );
}

class _ChildSelector extends StatelessWidget {
  const _ChildSelector({
    required this.api,
    required this.children,
    required this.selectedId,
    required this.onSelect,
    this.showUnread = false,
  });

  final NigohApi api;
  final List<FamilyChild> children;
  final int selectedId;
  final ValueChanged<int> onSelect;
  final bool showUnread;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 56,
    child: ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        for (final child in children)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              avatar: AvatarView(
                name: child.name,
                url: api.fileUrl(child.childAvatar),
                size: 24,
              ),
              label: Badge.count(
                count: child.unreadFromChild,
                isLabelVisible: showUnread && child.unreadFromChild > 0,
                offset: const Offset(14, -6),
                child: Text(child.name),
              ),
              selected: child.id == selectedId,
              showCheckmark: false,
              onSelected: (_) => onSelect(child.id),
            ),
          ),
      ],
    ),
  );
}

class _Overview extends StatelessWidget {
  const _Overview({
    required this.controller,
    required this.parentName,
    this.parentAvatar,
    required this.onAdd,
    required this.onOpen,
    required this.onRemove,
    required this.onRequests,
    required this.onReport,
    required this.onBedtime,
    required this.onStudy,
  });

  final FamilyController controller;
  final String parentName;
  final String? parentAvatar;
  final VoidCallback onAdd;
  final void Function(int tab, FamilyChild child) onOpen;
  final ValueChanged<FamilyChild> onRemove;
  final VoidCallback onRequests;
  final ValueChanged<FamilyChild> onReport;
  final ValueChanged<FamilyChild> onBedtime;
  final ValueChanged<FamilyChild> onStudy;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final sorted = controller.sortedByAttention;
    final deviceAlerts = [
      for (final c in sorted)
        // A phone that never reported is shown on its own card only.
        if (c.paired &&
            (isLowBattery(c) ||
                (c.location?.updatedAt != null && isOfflineChild(c))))
          c,
    ];
    final name = parentName.trim().split(' ').first;
    return RefreshIndicator(
      onRefresh: () => controller.refresh(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        children: [
          for (final child in controller.urgentChildren)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SosBanner(
                key: ValueKey('sos-${child.id}'),
                child: child,
                onChat: () => onOpen(3, child),
                onMap: () => onOpen(2, child),
              ),
            ),
          Row(
            key: const ValueKey('greeting'),
            children: [
              AvatarView(
                name: parentName.trim().isEmpty ? '?' : parentName,
                url: controller.api.fileUrl(parentAvatar),
                size: 48,
                color: NigohDesign.blue,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.isEmpty
                          ? tr('Салом!')
                          : tr('Салом, {name}!', {'name': name}),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tr('Ҳолати имрӯзаи оилаи шумо'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (controller.error != null) ...[
            const SizedBox(height: 12),
            _ErrorBanner(
              message: controller.error!,
              onRetry: controller.refresh,
            ),
          ],
          if (controller.children.any((c) => c.paired)) ...[
            const SizedBox(height: 16),
            _RequestsTile(
              count: controller.pendingRequestsTotal,
              onTap: onRequests,
            ),
          ],
          if (deviceAlerts.isNotEmpty) ...[
            const SizedBox(height: 16),
            _DeviceAlerts(
              children: deviceAlerts,
              onOpen: (child) => onOpen(2, child),
            ),
          ],
          SectionTitle(
            tr('Фарзандон'),
            trailing: Text(
              '${sorted.length}',
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          for (final (index, child) in sorted.indexed)
            FadeIn(
              key: ValueKey('child-${child.id}'),
              index: index,
              child: _ChildCard(
                child: child,
                avatarUrl: controller.api.fileUrl(child.childAvatar),
                places: controller.placesFor(child.id),
                onOpen: (tab) => onOpen(tab, child),
                onRemove: () => onRemove(child),
                onReport: () => onReport(child),
                onBedtime: () => onBedtime(child),
                onStudy: () => onStudy(child),
              ),
            ),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
            ),
            onPressed: onAdd,
            icon: const Icon(Icons.person_add_alt_1_rounded),
            label: Text(tr('Илова кардани фарзанд')),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
      decoration: BoxDecoration(
        color: scheme.error.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.error.withValues(alpha: .25)),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_off_rounded, color: scheme.error, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message, style: TextStyle(color: scheme.error)),
          ),
          TextButton(onPressed: onRetry, child: Text(tr('Аз нав'))),
        ],
      ),
    );
  }
}

class _ChildCard extends StatelessWidget {
  const _ChildCard({
    required this.child,
    this.avatarUrl,
    required this.places,
    required this.onOpen,
    required this.onRemove,
    required this.onReport,
    required this.onBedtime,
    required this.onStudy,
  });

  final FamilyChild child;
  final String? avatarUrl;
  final List<SafePlace> places;
  final ValueChanged<int> onOpen;
  final VoidCallback onRemove;
  final VoidCallback onReport;
  final VoidCallback onBedtime;
  final VoidCallback onStudy;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final offline = isOfflineChild(child, now);
    final seen = child.location?.updatedAt;
    final battery = batteryOf(child);
    final lowBattery = isLowBattery(child);
    final studyActive = child.study.activeAt(now);
    final status = placeStatus(child.location, places);
    final inside =
        status != null &&
        placeContaining(
              child.location!.latitude,
              child.location!.longitude,
              places,
            ) !=
            null;
    final bedtimeActive = child.bedtime.activeAt(DateTime.now());
    final newApps = child.newAppsCount;
    final chips = <Widget>[
      if (offline)
        Pill(
          key: ValueKey('offline-${child.id}'),
          seen == null
              ? tr('Офлайн — маълумот нест')
              : tr('Офлайн — {ago}', {'ago': timeAgo(seen)}),
          color: scheme.outline,
          icon: Icons.cloud_off_rounded,
        ),
      if (battery != null)
        Pill(
          key: ValueKey(
            lowBattery ? 'battery-low-${child.id}' : 'battery-${child.id}',
          ),
          lowBattery
              ? tr('Батарея кам: {battery}%', {'battery': battery})
              : '$battery%',
          color: lowBattery ? scheme.error : NigohDesign.mint,
          icon: lowBattery
              ? Icons.battery_alert_rounded
              : Icons.battery_std_rounded,
        ),
      if (status != null)
        Pill(
          status,
          color: inside ? NigohDesign.mint : NigohDesign.amber,
          icon: inside ? Icons.shield_rounded : Icons.shield_outlined,
        ),
      if (child.unreadFromChild > 0)
        Pill(
          tr('{unreadFromChild} паёми нав', {
            'unreadFromChild': child.unreadFromChild,
          }),
          color: NigohDesign.blue,
          icon: Icons.mark_chat_unread_rounded,
        ),
      if (child.pendingRequests > 0)
        Pill(
          tr('{pendingRequests} дархост', {
            'pendingRequests': child.pendingRequests,
          }),
          color: NigohDesign.amber,
          icon: Icons.more_time_rounded,
        ),
      if (newApps > 0)
        Pill(
          tr('{newApps} барномаи нав', {'newApps': newApps}),
          color: NigohDesign.violet,
          icon: Icons.fiber_new_rounded,
        ),
    ];
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onLongPress: onRemove,
        onTap: () => onOpen(1),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 4, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  AvatarView(name: child.name, url: avatarUrl, size: 48),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          child.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          [
                            if (child.age > 0)
                              tr('{age} сола', {'age': child.age}),
                            seen != null
                                ? tr('дида шуд {ago}', {'ago': timeAgo(seen)})
                                : tr('ҳоло маълумот нест'),
                          ].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!child.paired)
                    Pill(tr('Интизор'), color: NigohDesign.amber)
                  else
                    Pill(
                      offline ? tr('Офлайн') : tr('Онлайн'),
                      color: offline ? scheme.outline : NigohDesign.mint,
                      icon: Icons.circle,
                    ),
                  PopupMenuButton<String>(
                    tooltip: tr('Бештар'),
                    onSelected: (value) {
                      if (value == 'remove') onRemove();
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'remove',
                        child: Text(tr('Хориҷ кардан')),
                      ),
                    ],
                  ),
                ],
              ),
              if (chips.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(spacing: 6, runSpacing: 6, children: chips),
              ],
              if (child.paired) ...[
                const SizedBox(height: 8),
                _InternetRow(
                  key: ValueKey('net-${child.id}'),
                  online: !offline,
                ),
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _Stat(
                      icon: Icons.schedule_rounded,
                      color: NigohDesign.blue,
                      value: formatMinutes(child.usageMinutesToday),
                      label: tr('Вақти экран'),
                    ),
                  ),
                  Expanded(
                    child: _Stat(
                      icon: Icons.lock_outline_rounded,
                      color: NigohDesign.coral,
                      value: '${child.blockedCount}',
                      label: tr('Баста'),
                    ),
                  ),
                  Expanded(
                    child: _Stat(
                      icon: Icons.apps_rounded,
                      color: NigohDesign.violet,
                      value: '${child.apps.length}',
                      label: tr('Барнома'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Row(
                  children: [
                    _QuickAction(
                      icon: Icons.apps_rounded,
                      label: tr('Барномаҳо'),
                      onTap: () => onOpen(1),
                    ),
                    _QuickAction(
                      icon: Icons.map_rounded,
                      label: tr('Харита'),
                      onTap: () => onOpen(2),
                    ),
                    _QuickAction(
                      icon: Icons.chat_bubble_rounded,
                      label: tr('Чат'),
                      onTap: () => onOpen(3),
                    ),
                    if (child.paired)
                      IconButton.filled(
                        key: ValueKey('call-${child.id}'),
                        tooltip: tr('Занг'),
                        style: IconButton.styleFrom(
                          backgroundColor: NigohDesign.mint,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => CallScreen.openOutgoing(
                          context,
                          childId: child.id,
                          peerName: child.name,
                          peerAvatarUrl: avatarUrl,
                        ),
                        icon: const Icon(Icons.call_rounded, size: 20),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: _LinkRow(
                        key: ValueKey('report-${child.id}'),
                        icon: Icons.bar_chart_rounded,
                        color: NigohDesign.blue,
                        label: tr('Ҳисобот'),
                        onTap: onReport,
                      ),
                    ),
                    Expanded(
                      child: _LinkRow(
                        key: ValueKey('bedtime-${child.id}'),
                        icon: bedtimeActive
                            ? Icons.bedtime_rounded
                            : Icons.bedtime_outlined,
                        color: NigohDesign.violet,
                        label: child.bedtime.enabled
                            ? bedtimeLabel(child.bedtime)
                            : tr('Вақти хоб'),
                        trailing: bedtimeActive ? tr('Ҳозир фаъол') : null,
                        onTap: onBedtime,
                      ),
                    ),
                    Expanded(
                      child: Tooltip(
                        message: studyLabel(child.study),
                        child: _LinkRow(
                          key: ValueKey('study-${child.id}'),
                          icon: studyActive
                              ? Icons.school_rounded
                              : Icons.school_outlined,
                          color: NigohDesign.mint,
                          label: tr('Тамаркузи дарс'),
                          trailing: !child.study.enabled
                              ? null
                              : studyActive
                              ? tr('Ҳозир фаъол')
                              : '${child.study.start}–${child.study.end}',
                          onTap: onStudy,
                        ),
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
}

/// «Интернет: пайваст» / «Интернет: пайваст нест».
class _InternetRow extends StatelessWidget {
  const _InternetRow({super.key, required this.online});
  final bool online;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = online ? NigohDesign.mint : scheme.onSurfaceVariant;
    return Row(
      children: [
        Icon(
          online ? Icons.wifi_rounded : Icons.wifi_off_rounded,
          size: 15,
          color: color,
        ),
        const SizedBox(width: 6),
        Text(
          online ? tr('Интернет: пайваст') : tr('Интернет: пайваст нест'),
          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// Phones that need attention: low battery or no report for 20+ minutes.
class _DeviceAlerts extends StatelessWidget {
  const _DeviceAlerts({required this.children, required this.onOpen});
  final List<FamilyChild> children;
  final ValueChanged<FamilyChild> onOpen;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      key: const ValueKey('device-alerts'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          children: [
            for (final c in children)
              ListTile(
                dense: true,
                onTap: () => onOpen(c),
                leading: Icon(
                  isLowBattery(c)
                      ? Icons.battery_alert_rounded
                      : Icons.cloud_off_rounded,
                  color: isLowBattery(c) ? scheme.error : scheme.outline,
                ),
                title: Text(
                  c.name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  [
                    if (isLowBattery(c))
                      tr('Батарея кам: {battery}%', {'battery': batteryOf(c)}),
                    if (isOfflineChild(c))
                      tr('Офлайн — {ago}', {
                        'ago': timeAgo(c.location?.updatedAt),
                      }),
                  ].join(' · '),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
              ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 17),
      ),
      const SizedBox(width: 8),
      Flexible(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilledButton.tonalIcon(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          visualDensity: VisualDensity.compact,
        ),
        onPressed: onTap,
        icon: Icon(icon, size: 16),
        label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    ),
  );
}

/// Small text link with an icon (report, bedtime) under the quick actions.
class _LinkRow extends StatelessWidget {
  const _LinkRow({
    super.key,
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String? trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(12),
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 17, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w600,
                    fontSize: 12.5,
                  ),
                ),
                if (trailing != null)
                  Text(
                    trailing!,
                    style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

/// Entry to the extra-time requests inbox, with the pending count.
class _RequestsTile extends StatelessWidget {
  const _RequestsTile({required this.count, required this.onTap});
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final active = count > 0;
    return Material(
      color: active ? NigohDesign.amber.withValues(alpha: .10) : scheme.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        key: const ValueKey('open-requests'),
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: active
                  ? NigohDesign.amber.withValues(alpha: .45)
                  : scheme.outlineVariant,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: NigohDesign.amber.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.more_time_rounded,
                  color: NigohDesign.amber,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr('Дархостҳои вақт'),
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      active
                          ? tr('Фарзанд вақти иловагӣ мепурсад')
                          : tr('Дархости нав нест'),
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (active)
                Badge.count(
                  key: const ValueKey('requests-badge'),
                  count: count,
                  backgroundColor: NigohDesign.amber,
                  textColor: Colors.black,
                  largeSize: 22,
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

/// Prominent red SOS alert from a child (unread urgent message).
class SosBanner extends StatelessWidget {
  const SosBanner({
    super.key,
    required this.child,
    required this.onChat,
    required this.onMap,
  });

  final FamilyChild child;
  final VoidCallback onChat;
  final VoidCallback onMap;

  @override
  Widget build(BuildContext context) {
    final urgent = child.lastUrgent!;
    const red = Color(0xFFD32F2F);
    final text = urgent.content.trim();
    final time = urgent.createdAt;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: red,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: red.withValues(alpha: .28),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.sos_rounded, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr('{name} кӯмак мехоҳад', {'name': child.name}),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      time == null
                          ? tr('Сигнали SOS')
                          : 'SOS · ${hhmm(time.toLocal())} · ${timeAgo(time)}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .85),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (text.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              text,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, height: 1.35),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  key: ValueKey('sos-chat-${child.id}'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: red,
                  ),
                  onPressed: onChat,
                  icon: const Icon(Icons.chat_bubble_rounded, size: 18),
                  label: Text(tr('Кушодани чат')),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  key: ValueKey('sos-map-${child.id}'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white70),
                  ),
                  onPressed: onMap,
                  icon: const Icon(Icons.location_on_rounded, size: 18),
                  label: Text(tr('Ҷойгиршавӣ')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
