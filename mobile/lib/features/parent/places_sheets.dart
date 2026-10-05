// Файл: эҷод ва таҳрири ҷойҳои бехатар.

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../core/models.dart';
import '../../ui/nigoh_design.dart';
import '../../ui/widgets.dart';
import 'family_controller.dart';
import 'place_rules_sheet.dart';
import 'parent_logic.dart';
import '../../l10n/l10n.dart';

/// Равзанаи AddPlaceSheet-ро барои эҷод ва таҳрири ҷойҳои бехатар нишон медиҳад.
class AddPlaceSheet extends StatefulWidget {
  const AddPlaceSheet({
    super.key,
    required this.controller,
    required this.child,
    this.tapped,
    this.childPosition,
  });

  final FamilyController controller;
  final FamilyChild child;

  /// Қимати tapped-ро барои эҷод ва таҳрири ҷойҳои бехатар нигоҳ медорад.
  final LatLng? tapped;
  final LatLng? childPosition;

  /// Ҳолати AddPlaceSheet-ро барои ҷойҳои бехатар ва таърихи ҳаракат месозад.
  @override
  State<AddPlaceSheet> createState() => _AddPlaceSheetState();
}

/// Ҳолат ва рафтори AddPlaceSheetState-ро барои навсозии интерфейс идора мекунад.
class _AddPlaceSheetState extends State<AddPlaceSheet> {
  final _name = TextEditingController();
  double _radius = 150;
  late bool _useChild = widget.tapped == null;
  bool _saving = false;

  /// Controller ва listener-ҳои AddPlaceSheet-ро озод мекунад.
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  /// Қимати ҳисобшудаи position-ро аз ҳолати ҷорӣ бармегардонад.
  LatLng? get _position => _useChild ? widget.childPosition : widget.tapped;

  /// save тағйироти ҷойҳои бехатар-ро барои истифодаи баъдӣ нигоҳ медорад.
  Future<void> _save() async {
    final position = _position;
    final name = _name.text.trim();
    if (position == null || name.isEmpty) return;
    setState(() => _saving = true);
    try {
      await widget.controller.addPlace(
        widget.child.id,
        name: name,
        latitude: position.latitude,
        longitude: position.longitude,
        radiusMeters: _radius.round(),
      );
      if (!mounted) return;
      showMessage(context, tr('«{name}» илова шуд', {'name': name}));
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showMessage(context, e, error: true);
    }
  }

  /// Формаи ном, радиус ва координатаҳои ҷойи бехатарро нишон медиҳад.
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final position = _position;
    // Қадами дохилии эҷод ва таҳрири ҷойҳои бехатар.
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          20 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr('Ҷойи бехатар'),
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              tr(
                'Масалан, хона ё мактаб. Дар корти фарзанд нишон дода мешавад, ки ӯ дар куҷост.',
              ),
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 14),
            TextField(
              key: const ValueKey('place-name'),
              controller: _name,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              maxLength: 40,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: tr('Ном'),
                hintText: tr('Хона, Мактаб…'),
              ),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (widget.tapped != null)
                  ChoiceChip(
                    avatar: const Icon(Icons.touch_app_rounded, size: 18),
                    label: Text(tr('Нуқтаи интихобшуда')),
                    selected: !_useChild,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _useChild = false),
                  ),
                ChoiceChip(
                  avatar: const Icon(Icons.my_location_rounded, size: 18),
                  label: Text(tr('Ҷойи ҳозираи фарзанд')),
                  selected: _useChild,
                  showCheckmark: false,
                  onSelected: widget.childPosition == null
                      ? null
                      : (_) => setState(() => _useChild = true),
                ),
              ],
            ),
            if (position == null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  tr(
                    'Ҷойи фарзанд маълум нест. Дар харита нуқтаро дароз пахш кунед.',
                  ),
                  style: TextStyle(color: scheme.error, fontSize: 12),
                ),
              ),
            SectionTitle(tr('Андозаи ҷой')),
            Row(
              children: [
                Expanded(
                  child: Text(
                    tr('Радиуси давра дар харита'),
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 12.5,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedSwitcher(
                  duration: Duration(
                    milliseconds: reducedMotion(context) ? 0 : 180,
                  ),
                  child: Pill(
                    key: ValueKey(_radius.round()),
                    tr('{meters} метр', {'meters': _radius.round()}),
                    color: NigohDesign.mint,
                    icon: Icons.adjust_rounded,
                    big: true,
                  ),
                ),
              ],
            ),
            Slider(
              key: const ValueKey('place-radius'),
              value: _radius,
              min: 50,
              max: 1000,
              divisions: 19,
              label: tr('{meters} метр', {'meters': _radius.round()}),
              onChanged: (v) => setState(() => _radius = v),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const ValueKey('place-save'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                ),
                onPressed:
                    _saving || position == null || _name.text.trim().isEmpty
                    ? null
                    : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.shield_rounded),
                label: Text(tr('Ҷойро нигоҳ доштан')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Равзанаи PlacesSheet-ро барои эҷод ва таҳрири ҷойҳои бехатар нишон медиҳад.
class PlacesSheet extends StatefulWidget {
  const PlacesSheet({
    super.key,
    required this.controller,
    required this.childId,
    required this.onAdd,
    required this.onShow,
  });

  final FamilyController controller;
  final int childId;
  final VoidCallback onAdd;
  final ValueChanged<SafePlace> onShow;

  /// Ҳолати PlacesSheet-ро барои ҷойҳои бехатар ва таърихи ҳаракат месозад.
  @override
  State<PlacesSheet> createState() => _PlacesSheetState();
}

/// Ҳолат ва рафтори PlacesSheetState-ро барои навсозии интерфейс идора мекунад.
class _PlacesSheetState extends State<PlacesSheet> {
  /// Равзанаи «Қоидаҳои ин ҷой»-ро мекушояд.
  void _openRules(SafePlace place) {
    final child = widget.controller.childById(widget.childId);
    if (child == null) return;
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => PlaceRulesSheet(
        controller: widget.controller,
        child: child,
        place: place,
      ),
    );
  }

  /// delete маълумотро ҳазф карда, ҳолати вобастаро нав мекунад.
  Future<void> _delete(SafePlace place) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(tr('«{name}»-ро нест кунем?', {'name': place.name})),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(tr('Бекор')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(110, 44)),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(tr('Нест кардан')),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await widget.controller.deletePlace(widget.childId, place);
    } catch (e) {
      if (mounted) showMessage(context, e, error: true);
    }
  }

  /// Рӯйхати ҷойҳои бехатарро бо амалҳои таҳрир ва несткунӣ нишон медиҳад.
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final scheme = Theme.of(context).colorScheme;
      final places = widget.controller.placesFor(widget.childId);
      final child = widget.controller.childById(widget.childId);
      final location = child?.location;
      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * .7,
          ),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            children: [
              Text(
                tr('Ҷойҳои бехатар'),
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                tr(
                  'Барои илова дар харита нуқтаро дароз пахш кунед ё ҷойи ҳозираи фарзандро истифода баред.',
                ),
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
              if (widget.controller.placesError != null) ...[
                const SizedBox(height: 8),
                Text(
                  widget.controller.placesError!,
                  style: TextStyle(color: scheme.error),
                ),
                TextButton(
                  onPressed: () => widget.controller.loadPlaces(widget.childId),
                  child: Text(tr('Аз нав кӯшиш')),
                ),
              ],
              if (places.isEmpty)
                StateMessage(
                  icon: Icons.shield_outlined,
                  color: NigohDesign.mint,
                  title: tr('Ҳоло ҷойи бехатар нест'),
                  text: tr(
                    'Ҷойи аввалро илова кунед — дар корти фарзанд «Дар хона» ё «Дар мактаб» пайдо мешавад.',
                  ),
                  actionLabel: tr('Ҷойи нав илова кардан'),
                  actionIcon: Icons.add_location_alt_rounded,
                  primaryAction: true,
                  onAction: widget.onAdd,
                )
              else ...[
                SectionTitle(
                  tr('Ҷойҳои шумо'),
                  trailing: Text(
                    tr('{count} ҷой', {'count': places.length}),
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                for (final (index, place) in places.indexed)
                  FadeIn(
                    key: ValueKey('place-${place.id}'),
                    index: index,
                    child: _PlaceTile(
                      place: place,
                      distance: location == null
                          ? null
                          : distanceMeters(
                              location.latitude,
                              location.longitude,
                              place.latitude,
                              place.longitude,
                            ),
                      onTap: () => widget.onShow(place),
                      onRules: () => _openRules(place),
                      onDelete: () => _delete(place),
                    ),
                  ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  key: const ValueKey('place-add'),
                  onPressed: widget.onAdd,
                  icon: const Icon(Icons.add_location_alt_rounded),
                  label: Text(tr('Ҷойи нав илова кардан')),
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}

/// Widget-и PlaceTile-ро барои эҷод ва таҳрири ҷойҳои бехатар месозад.
class _PlaceTile extends StatelessWidget {
  const _PlaceTile({
    required this.place,
    required this.distance,
    required this.onTap,
    required this.onRules,
    required this.onDelete,
  });

  final SafePlace place;
  final double? distance;
  final VoidCallback onTap;

  /// Кушодани «Қоидаҳои ин ҷой».
  final VoidCallback onRules;
  final VoidCallback onDelete;

  /// Widget-и PlaceTile-ро барои ҷойҳои бехатар ва таърихи ҳаракат месозад.
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final inside = distance != null && distance! <= place.radiusMeters;
    final d = distance;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: NigohDesign.mint.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            inside ? Icons.shield_rounded : Icons.shield_outlined,
            color: NigohDesign.mint,
          ),
        ),
        title: Text(
          place.name,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          [
            tr('Радиус {radiusMeters} м', {'radiusMeters': place.radiusMeters}),
            if (inside)
              tr('фарзанд дар ин ҷост')
            else if (d != null)
              d >= 1000
                  ? tr('{km} км дур', {'km': (d / 1000).toStringAsFixed(1)})
                  : tr('{meters} м дур', {'meters': d.round()}),
            placeRulesSummary(place),
          ].join(' · '),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              key: ValueKey('place-rules-${place.id}'),
              tooltip: tr('Қоидаҳои ин ҷой'),
              onPressed: onRules,
              icon: Icon(
                Icons.rule_rounded,
                color: place.rules.isNotEmpty || place.notify
                    ? NigohDesign.blue
                    : null,
              ),
            ),
            IconButton(
              tooltip: tr('Нест кардан'),
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

/// Равзанаи HistoryTimelineSheet-ро барои эҷод ва таҳрири ҷойҳои бехатар нишон медиҳад.
class HistoryTimelineSheet extends StatelessWidget {
  const HistoryTimelineSheet({
    super.key,
    required this.points,
    required this.onSelect,
  });

  final List<HistoryPoint> points;
  final ValueChanged<HistoryPoint> onSelect;

  /// Widget-и HistoryTimelineSheet-ро барои ҷойҳои бехатар ва таърихи ҳаракат месозад.
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final items = points.reversed.toList();
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * .7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr('Таърихи 24 соат · {count} нуқта', {
                      'count': points.length,
                    }),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    tr('Нуқтаро пахш кунед, то онро дар харита бинед.'),
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                itemCount: items.length,
                itemBuilder: (context, i) {
                  final p = items[i];
                  final first = i == 0;
                  final last = i == items.length - 1;
                  return InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => onSelect(p),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 22,
                            height: 48,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Positioned(
                                  top: first ? 24 : 0,
                                  bottom: last ? 24 : 0,
                                  child: Container(
                                    width: 2,
                                    color: NigohDesign.violet.withValues(
                                      alpha: .3,
                                    ),
                                  ),
                                ),
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: first
                                        ? NigohDesign.coral
                                        : last
                                        ? NigohDesign.mint
                                        : NigohDesign.violet,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              p.time == null
                                  ? '—'
                                  : '${hhmm(p.time!.toLocal())} · ${timeAgo(p.time)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (p.batteryLevel != null)
                            Text(
                              '${p.batteryLevel}%',
                              style: TextStyle(
                                color: scheme.onSurfaceVariant,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
