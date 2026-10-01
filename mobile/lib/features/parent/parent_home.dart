import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/models.dart';
import '../../core/session.dart';
import '../../ui/nigoh_design.dart';
import '../../ui/widgets.dart';
import '../chat/chat_screen.dart';
import '../settings/settings_screen.dart';
import 'add_child_screen.dart';
import 'apps_screen.dart';
import 'family_controller.dart';
import 'map_screen.dart';

const _deviceChannel = MethodChannel('tj.nigoh/device_control');

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

  FamilyController get controller => _controller!;

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
    if (_owned) _controller?.dispose();
    super.dispose();
  }

  Future<void> _addChild() async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AddChildScreen(controller: controller),
      ),
    );
    if (ok == true && mounted) showMessage(context, 'Фарзанд пайваст шуд');
  }

  void _open(int tab, FamilyChild child) {
    controller.select(child.id);
    setState(() => _tab = tab);
  }

  /// True when removal may continue (no local PIN, or the PIN was correct).
  Future<bool> _verifyPin() async {
    bool hasPin;
    try {
      hasPin =
          await _deviceChannel.invokeMethod<bool>('getLocalPinStatus') ?? false;
    } on MissingPluginException {
      hasPin = false;
    } on PlatformException catch (e) {
      if (mounted) {
        showMessage(context, 'PIN санҷида нашуд: ${e.message}', error: true);
      }
      return false;
    }
    if (!hasPin) return true;
    if (!mounted) return false;
    final input = TextEditingController();
    var wrong = false;
    var checking = false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (_, setDialogState) => AlertDialog(
          icon: const Icon(Icons.lock_rounded),
          title: const Text('PIN-ро ворид кунед'),
          content: TextField(
            controller: input,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: 4,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'PIN-и волидайн',
              errorText: wrong ? 'PIN нодуруст аст' : null,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Бекор'),
            ),
            FilledButton(
              onPressed: checking
                  ? null
                  : () async {
                      setDialogState(() => checking = true);
                      bool valid;
                      try {
                        valid =
                            await _deviceChannel.invokeMethod<bool>(
                              'verifyLocalPin',
                              {'pin': input.text.trim()},
                            ) ??
                            false;
                      } on PlatformException {
                        valid = false;
                      }
                      if (valid && dialogContext.mounted) {
                        Navigator.pop(dialogContext, true);
                      } else {
                        setDialogState(() {
                          wrong = true;
                          checking = false;
                        });
                      }
                    },
              child: const Text('Тасдиқ'),
            ),
          ],
        ),
      ),
    );
    input.dispose();
    return ok == true;
  }

  Future<void> _removeChild(FamilyChild child) async {
    if (!await _verifyPin() || !mounted) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${child.name}-ро хориҷ кунем?'),
        content: const Text(
          'Қоидаҳо ва чат барои ин фарзанд дигар дастрас намешаванд. '
          'Барои пайвасти дубора коди навро скан кунед.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Бекор'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
              foregroundColor: Theme.of(dialogContext).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Хориҷ кардан'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await controller.unlink(child);
      if (mounted) showMessage(context, '${child.name} хориҷ шуд');
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
            title: 'Маълумот гирифта нашуд',
            text: controller.error,
            actionLabel: 'Аз нав кӯшиш',
            onAction: controller.refresh,
            error: true,
          );
        } else if (children.isEmpty) {
          body = _EmptyFamily(onAdd: _addChild);
        } else {
          body = _tabBody(session.displayName);
        }
        return Scaffold(
          // Chat and Settings bring their own app bar.
          appBar: _tab >= 3 ? null : AppBar(title: Text(_titles[_tab])),
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
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.family_restroom_outlined),
                selectedIcon: Icon(Icons.family_restroom_rounded),
                label: 'Оила',
              ),
              NavigationDestination(
                icon: Icon(Icons.apps_outlined),
                selectedIcon: Icon(Icons.apps_rounded),
                label: 'Барномаҳо',
              ),
              NavigationDestination(
                icon: Icon(Icons.map_outlined),
                selectedIcon: Icon(Icons.map_rounded),
                label: 'Харита',
              ),
              NavigationDestination(
                icon: Icon(Icons.chat_bubble_outline_rounded),
                selectedIcon: Icon(Icons.chat_bubble_rounded),
                label: 'Чат',
              ),
              NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings_rounded),
                label: 'Танзимот',
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _tabBody(String parentName) {
    if (_tab == 0) {
      return _Overview(
        controller: controller,
        parentName: parentName,
        onAdd: _addChild,
        onOpen: _open,
        onRemove: _removeChild,
      );
    }
    final selected = controller.selected!;
    final Widget content = switch (_tab) {
      1 => AppsScreen(controller: controller),
      2 => MapScreen(controller: controller),
      _ => KeyedSubtree(
        key: ValueKey('chat-${selected.id}'),
        child: ChatScreen(childId: selected.id, title: selected.name),
      ),
    };
    return Column(
      children: [
        if (controller.children.length > 1)
          _ChildSelector(
            children: controller.children,
            selectedId: selected.id,
            onSelect: controller.select,
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
          const StateMessage(
            icon: Icons.family_restroom_rounded,
            title: 'Ҳоло фарзанд пайваст нашудааст',
            text:
                'Телефони фарзандро пайваст кунед, то барномаҳо, ҷойгиршавӣ '
                'ва чатро бинед.',
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size(260, 56)),
            onPressed: onAdd,
            icon: const Icon(Icons.person_add_alt_1_rounded),
            label: const Text('Илова кардани фарзанд'),
          ),
        ],
      ),
    ),
  );
}

class _ChildSelector extends StatelessWidget {
  const _ChildSelector({
    required this.children,
    required this.selectedId,
    required this.onSelect,
  });

  final List<FamilyChild> children;
  final int selectedId;
  final ValueChanged<int> onSelect;

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
              avatar: _Avatar(name: child.name, size: 24),
              label: Text(child.name),
              selected: child.id == selectedId,
              showCheckmark: false,
              onSelected: (_) => onSelect(child.id),
            ),
          ),
      ],
    ),
  );
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, this.size = 48});
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = NigohDesign.accentFor(name);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: .14),
        shape: BoxShape.circle,
      ),
      child: Text(
        name.isEmpty ? '?' : name.characters.first.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: size * .42,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _Overview extends StatelessWidget {
  const _Overview({
    required this.controller,
    required this.parentName,
    required this.onAdd,
    required this.onOpen,
    required this.onRemove,
  });

  final FamilyController controller;
  final String parentName;
  final VoidCallback onAdd;
  final void Function(int tab, FamilyChild child) onOpen;
  final ValueChanged<FamilyChild> onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final name = parentName.trim().split(' ').first;
    return RefreshIndicator(
      onRefresh: () => controller.refresh(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        children: [
          Text(
            name.isEmpty ? 'Салом!' : 'Салом, $name!',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Ҳолати имрӯзаи оилаи шумо',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
          if (controller.error != null) ...[
            const SizedBox(height: 12),
            _ErrorBanner(
              message: controller.error!,
              onRetry: controller.refresh,
            ),
          ],
          const SizedBox(height: 8),
          for (final (index, child) in controller.children.indexed)
            FadeIn(
              key: ValueKey('child-${child.id}'),
              index: index,
              child: _ChildCard(
                child: child,
                onOpen: (tab) => onOpen(tab, child),
                onRemove: () => onRemove(child),
              ),
            ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
            ),
            onPressed: onAdd,
            icon: const Icon(Icons.person_add_alt_1_rounded),
            label: const Text('Илова кардани фарзанд'),
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
          TextButton(onPressed: onRetry, child: const Text('Аз нав')),
        ],
      ),
    );
  }
}

class _ChildCard extends StatelessWidget {
  const _ChildCard({
    required this.child,
    required this.onOpen,
    required this.onRemove,
  });

  final FamilyChild child;
  final ValueChanged<int> onOpen;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final online = child.online;
    final seen = child.location?.updatedAt;
    return Card(
      margin: const EdgeInsets.only(top: 12),
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
                  _Avatar(name: child.name),
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
                            if (child.age > 0) '${child.age} сола',
                            seen != null
                                ? 'дида шуд ${timeAgo(seen)}'
                                : 'ҳоло маълумот нест',
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
                    const Pill('Интизор', color: NigohDesign.amber)
                  else
                    Pill(
                      online ? 'Онлайн' : 'Офлайн',
                      color: online ? NigohDesign.mint : scheme.outline,
                      icon: Icons.circle,
                    ),
                  PopupMenuButton<String>(
                    tooltip: 'Бештар',
                    onSelected: (value) {
                      if (value == 'remove') onRemove();
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'remove',
                        child: Text('Хориҷ кардан'),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _Stat(
                      icon: Icons.schedule_rounded,
                      color: NigohDesign.blue,
                      value: formatMinutes(child.usageMinutesToday),
                      label: 'Вақти экран',
                    ),
                  ),
                  Expanded(
                    child: _Stat(
                      icon: Icons.lock_outline_rounded,
                      color: NigohDesign.coral,
                      value: '${child.blockedCount}',
                      label: 'Баста',
                    ),
                  ),
                  Expanded(
                    child: _Stat(
                      icon: Icons.apps_rounded,
                      color: NigohDesign.violet,
                      value: '${child.apps.length}',
                      label: 'Барнома',
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
                      label: 'Барномаҳо',
                      onTap: () => onOpen(1),
                    ),
                    _QuickAction(
                      icon: Icons.map_rounded,
                      label: 'Харита',
                      onTap: () => onOpen(2),
                    ),
                    _QuickAction(
                      icon: Icons.chat_bubble_rounded,
                      label: 'Чат',
                      onTap: () => onOpen(3),
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
