import 'package:flutter/material.dart';

import 'widgets.dart';

class NigohBottomBarItem {
  const NigohBottomBarItem({
    this.key,
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final Key? key;
  final Widget icon;
  final Widget selectedIcon;
  final String label;
}

class NigohBottomBar extends StatelessWidget {
  const NigohBottomBar({
    super.key,
    required this.selectedIndex,
    required this.items,
    required this.onSelected,
  });

  final int selectedIndex;
  final List<NigohBottomBarItem> items;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final noMotion = reducedMotion(context);
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(10, 0, 10, 8),
      child: Material(
        color: scheme.surfaceContainer,
        elevation: 0,
        shadowColor: Colors.black.withValues(alpha: .16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: .7)),
        ),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          height: 72,
          child: Row(
            children: [
              for (var index = 0; index < items.length; index++)
                Expanded(
                  child: _BottomBarButton(
                    item: items[index],
                    selected: selectedIndex == index,
                    duration: noMotion
                        ? Duration.zero
                        : const Duration(milliseconds: 220),
                    onTap: () => onSelected(index),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomBarButton extends StatelessWidget {
  const _BottomBarButton({
    required this.item,
    required this.selected,
    required this.duration,
    required this.onTap,
  });

  final NigohBottomBarItem item;
  final bool selected;
  final Duration duration;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final foreground = selected ? scheme.primary : scheme.onSurfaceVariant;
    return Semantics(
      key: item.key,
      button: true,
      selected: selected,
      label: item.label,
      child: InkWell(
        onTap: onTap,
        customBorder: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
          child: AnimatedContainer(
            duration: duration,
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              color: selected
                  ? scheme.primary.withValues(alpha: .10)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedSwitcher(
                  duration: duration,
                  child: IconTheme(
                    key: ValueKey(selected),
                    data: IconThemeData(color: foreground, size: 23),
                    child: selected ? item.selectedIcon : item.icon,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.fade,
                  softWrap: false,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 10.5,
                    height: 1,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    letterSpacing: selected ? -.1 : 0,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
