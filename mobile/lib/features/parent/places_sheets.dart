import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../core/models.dart';
import '../../ui/nigoh_design.dart';
import '../../ui/widgets.dart';
import 'family_controller.dart';
import 'parent_logic.dart';

/// New safe place: name, radius 50–1000 m, position from the map tap or the
/// child's current location. Closes with `true` once saved.
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

  /// Point long-pressed on the map, if any.
  final LatLng? tapped;
  final LatLng? childPosition;

  @override
  State<AddPlaceSheet> createState() => _AddPlaceSheetState();
}

class _AddPlaceSheetState extends State<AddPlaceSheet> {
  final _name = TextEditingController();
  double _radius = 150;
  late bool _useChild = widget.tapped == null;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  LatLng? get _position => _useChild ? widget.childPosition : widget.tapped;

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
      showMessage(context, '«$name» илова шуд');
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showMessage(context, e, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final position = _position;
    return SafeArea(
      child: Padding(
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
            const Text(
              'Ҷойи бехатар',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Масалан, хона ё мактаб. Дар корти фарзанд нишон дода мешавад, '
              'ки ӯ дар куҷост.',
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
              decoration: const InputDecoration(
                labelText: 'Ном',
                hintText: 'Хона, Мактаб…',
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
                    label: const Text('Нуқтаи интихобшуда'),
                    selected: !_useChild,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _useChild = false),
                  ),
                ChoiceChip(
                  avatar: const Icon(Icons.my_location_rounded, size: 18),
                  label: const Text('Ҷойи ҳозираи фарзанд'),
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
                  'Ҷойи фарзанд маълум нест. Дар харита нуқтаро дароз пахш кунед.',
                  style: TextStyle(color: scheme.error, fontSize: 12),
                ),
              ),
            const SizedBox(height: 14),
            Row(
              children: [
                const Text(
                  'Радиус',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                Pill('${_radius.round()} м', color: NigohDesign.mint),
              ],
            ),
            Slider(
              key: const ValueKey('place-radius'),
              value: _radius,
              min: 50,
              max: 1000,
              divisions: 19,
              label: '${_radius.round()} м',
              onChanged: (v) => setState(() => _radius = v),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const ValueKey('place-save'),
                onPressed:
                    _saving || position == null || _name.text.trim().isEmpty
                    ? null
                    : _save,
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Нигоҳ доштан'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// List of a child's safe places with delete.
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

  @override
  State<PlacesSheet> createState() => _PlacesSheetState();
}

class _PlacesSheetState extends State<PlacesSheet> {
  Future<void> _delete(SafePlace place) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('«${place.name}»-ро нест кунем?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Бекор'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Нест кардан'),
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
              const Text(
                'Ҷойҳои бехатар',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                'Барои илова дар харита нуқтаро дароз пахш кунед ё ҷойи '
                'ҳозираи фарзандро истифода баред.',
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
                  child: const Text('Аз нав кӯшиш'),
                ),
              ],
              const SizedBox(height: 12),
              if (places.isEmpty)
                Text(
                  'Ҳоло ҷой нест.',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              for (final place in places)
                _PlaceTile(
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
                  onDelete: () => _delete(place),
                ),
              const SizedBox(height: 12),
              FilledButton.icon(
                key: const ValueKey('place-add'),
                onPressed: widget.onAdd,
                icon: const Icon(Icons.add_location_alt_rounded),
                label: const Text('Илова кардан'),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _PlaceTile extends StatelessWidget {
  const _PlaceTile({
    required this.place,
    required this.distance,
    required this.onTap,
    required this.onDelete,
  });

  final SafePlace place;
  final double? distance;
  final VoidCallback onTap;
  final VoidCallback onDelete;

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
            'Радиус ${place.radiusMeters} м',
            if (inside)
              'фарзанд дар ин ҷост'
            else if (d != null)
              d >= 1000
                  ? '${(d / 1000).toStringAsFixed(1)} км дур'
                  : '${d.round()} м дур',
          ].join(' · '),
        ),
        trailing: IconButton(
          tooltip: 'Нест кардан',
          onPressed: onDelete,
          icon: const Icon(Icons.delete_outline_rounded),
        ),
      ),
    );
  }
}

/// Timeline of the 24 h location points, newest first.
class HistoryTimelineSheet extends StatelessWidget {
  const HistoryTimelineSheet({
    super.key,
    required this.points,
    required this.onSelect,
  });

  final List<HistoryPoint> points;
  final ValueChanged<HistoryPoint> onSelect;

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
              child: Text(
                'Таърихи 24 соат · ${points.length} нуқта',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
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
