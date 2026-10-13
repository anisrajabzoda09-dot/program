// Файл: сохтан ва идораи масирҳои бехатар.

import 'package:flutter/material.dart';

import '../../core/models.dart';
import '../../l10n/l10n.dart';
import '../../ui/nigoh_design.dart';
import '../../ui/widgets.dart';
import 'family_controller.dart';

class SafeRoutesSheet extends StatelessWidget {
  const SafeRoutesSheet({
    super.key,
    required this.controller,
    required this.childId,
    required this.onShow,
  });

  final FamilyController controller;
  final int childId;
  final ValueChanged<SafeRoute> onShow;

  Future<void> _add(BuildContext context) async {
    final places = controller.placesFor(childId);
    if (places.length < 2) {
      showMessage(
        context,
        tr('Аввал камаш ду ҷой — масалан «Хона» ва «Мактаб» — илова кунед.'),
        error: true,
      );
      return;
    }
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => AddSafeRouteSheet(
        controller: controller,
        childId: childId,
        places: places,
      ),
    );
  }

  Future<void> _delete(BuildContext context, SafeRoute route) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(tr('«{name}»-ро нест кунем?', {'name': route.name})),
        content: Text(tr('Огоҳиҳои ин масир дигар кор намекунанд.')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(tr('Бекор')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(tr('Нест кардан')),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await controller.deleteRoute(childId, route);
    } catch (error) {
      if (context.mounted) showMessage(context, error, error: true);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final routes = controller.routesFor(childId);
      final scheme = Theme.of(context).colorScheme;
      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .76,
          ),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            children: [
              Text(
                tr('Роҳи бехатар'),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                tr(
                  'Агар фарзанд аз роҳ дур шавад ё сари вақт нарасад, шумо огоҳӣ мегиред.',
                ),
                style: TextStyle(color: scheme.onSurfaceVariant, height: 1.35),
              ),
              const SizedBox(height: 12),
              if (routes.isEmpty)
                StateMessage(
                  icon: Icons.route_rounded,
                  color: NigohDesign.blue,
                  title: tr('Ҳоло масир нест'),
                  text: tr(
                    'Хона ва мактабро интихоб кунед; назорат танҳо дар рӯзу вақти муқарраршуда кор мекунад.',
                  ),
                  actionLabel: tr('Сохтани масир'),
                  actionIcon: Icons.add_road_rounded,
                  primaryAction: true,
                  onAction: () => _add(context),
                )
              else ...[
                for (final route in routes)
                  Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => onShow(route),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
                        child: Row(
                          children: [
                            Icon(
                              Icons.route_rounded,
                              color: route.enabled
                                  ? NigohDesign.blue
                                  : scheme.outline,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    route.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '${route.startName} → ${route.endName} · ${route.startTime}–${route.arriveBy}',
                                    style: TextStyle(
                                      color: scheme.onSurfaceVariant,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                  Text(
                                    _statusText(route),
                                    style: TextStyle(
                                      color: _statusColor(route, scheme),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: route.enabled,
                              onChanged: (value) async {
                                try {
                                  await controller.setRouteEnabled(
                                    childId,
                                    route,
                                    value,
                                  );
                                } catch (error) {
                                  if (context.mounted) {
                                    showMessage(context, error, error: true);
                                  }
                                }
                              },
                            ),
                            IconButton(
                              tooltip: tr('Нест кардан'),
                              onPressed: () => _delete(context, route),
                              icon: const Icon(Icons.delete_outline_rounded),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                FilledButton.icon(
                  onPressed: () => _add(context),
                  icon: const Icon(Icons.add_road_rounded),
                  label: Text(tr('Масири нав')),
                ),
              ],
              const SizedBox(height: 12),
              Text(
                tr(
                  'Махфият: GPS барои назорати оила истифода мешавад; координатаи дақиқ ба AI фиристода намешавад.',
                ),
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 11.5,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      );
    },
  );

  static String _statusText(SafeRoute route) => switch (route.todayStatus) {
    'arrived' => tr('Имрӯз расид'),
    'active' => tr('Дар роҳ'),
    'deviation' => tr('Аз масир дур шуд'),
    'late' || 'pending' => tr('Сари вақт нарасид'),
    'ok' => tr('Ҷавоб дод: ҳамааш хуб'),
    'call' => tr('Занг мепурсад'),
    'sos' => 'SOS',
    _ => route.enabled ? tr('Омода') : tr('Хомӯш'),
  };

  static Color _statusColor(SafeRoute route, ColorScheme scheme) =>
      switch (route.todayStatus) {
        'deviation' || 'late' || 'pending' || 'sos' => scheme.error,
        'arrived' || 'ok' => NigohDesign.mint,
        _ => scheme.onSurfaceVariant,
      };
}

class AddSafeRouteSheet extends StatefulWidget {
  const AddSafeRouteSheet({
    super.key,
    required this.controller,
    required this.childId,
    required this.places,
  });

  final FamilyController controller;
  final int childId;
  final List<SafePlace> places;

  @override
  State<AddSafeRouteSheet> createState() => _AddSafeRouteSheetState();
}

class _AddSafeRouteSheetState extends State<AddSafeRouteSheet> {
  final _name = TextEditingController(text: tr('Хона — мактаб'));
  late int _startId = widget.places.first.id;
  late int _endId = widget.places[1].id;
  TimeOfDay _start = const TimeOfDay(hour: 7, minute: 30);
  TimeOfDay _arrive = const TimeOfDay(hour: 8, minute: 0);
  final Set<int> _days = {1, 2, 3, 4, 5};
  double _corridor = 300;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  String _hhmm(TimeOfDay value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  int _minute(TimeOfDay value) => value.hour * 60 + value.minute;

  Future<void> _pick(bool arrival) async {
    final value = await showTimePicker(
      context: context,
      initialTime: arrival ? _arrive : _start,
    );
    if (value == null || !mounted) return;
    setState(() => arrival ? _arrive = value : _start = value);
  }

  Future<void> _save() async {
    if (_startId == _endId ||
        _days.isEmpty ||
        _minute(_arrive) <= _minute(_start) ||
        _name.text.trim().isEmpty) {
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.controller.addRoute(
        widget.childId,
        name: _name.text.trim(),
        startPlaceId: _startId,
        endPlaceId: _endId,
        startTime: _hhmm(_start),
        arriveBy: _hhmm(_arrive),
        weekdays: _days.toList()..sort(),
        corridorMeters: _corridor.round(),
      );
      if (!mounted) return;
      showMessage(context, tr('Масири бехатар фаъол шуд'));
      Navigator.pop(context, true);
    } catch (error) {
      if (mounted) showMessage(context, error, error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const dayNames = ['Дш', 'Сш', 'Чш', 'Пш', 'Ҷм', 'Шн', 'Як'];
    final valid =
        _startId != _endId &&
        _days.isNotEmpty &&
        _minute(_arrive) > _minute(_start) &&
        _name.text.trim().isNotEmpty;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              tr('Масири нав'),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              tr('Назорат баъд аз вақти оғоз худкор фаъол мешавад.'),
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _name,
              maxLength: 80,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(labelText: tr('Номи масир')),
            ),
            DropdownButtonFormField<int>(
              initialValue: _startId,
              decoration: InputDecoration(labelText: tr('Аз куҷо')),
              items: [
                for (final place in widget.places)
                  DropdownMenuItem(value: place.id, child: Text(place.name)),
              ],
              onChanged: (value) =>
                  setState(() => _startId = value ?? _startId),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<int>(
              initialValue: _endId,
              decoration: InputDecoration(labelText: tr('Ба куҷо')),
              items: [
                for (final place in widget.places)
                  DropdownMenuItem(value: place.id, child: Text(place.name)),
              ],
              onChanged: (value) => setState(() => _endId = value ?? _endId),
            ),
            if (_startId == _endId)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  tr('Ҷойи оғоз ва манзил бояд гуногун бошанд.'),
                  style: TextStyle(color: scheme.error, fontSize: 12),
                ),
              ),
            SectionTitle(tr('Вақт')),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pick(false),
                    icon: const Icon(Icons.directions_walk_rounded),
                    label: Text('${tr('Рафтан')} ${_hhmm(_start)}'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pick(true),
                    icon: const Icon(Icons.flag_rounded),
                    label: Text('${tr('Расидан')} ${_hhmm(_arrive)}'),
                  ),
                ),
              ],
            ),
            if (_minute(_arrive) <= _minute(_start))
              Text(
                tr('Вақти расидан бояд дертар бошад.'),
                style: TextStyle(color: scheme.error, fontSize: 12),
              ),
            SectionTitle(tr('Рӯзҳо')),
            Wrap(
              spacing: 6,
              children: [
                for (var day = 1; day <= 7; day++)
                  FilterChip(
                    label: Text(dayNames[day - 1]),
                    selected: _days.contains(day),
                    onSelected: (selected) => setState(
                      () => selected ? _days.add(day) : _days.remove(day),
                    ),
                  ),
              ],
            ),
            SectionTitle(tr('Паҳнои бехатар')),
            Text(
              tr('Огоҳӣ, агар аз хати масир зиёда аз {meters} м дур шавад.', {
                'meters': _corridor.round(),
              }),
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5),
            ),
            Slider(
              value: _corridor,
              min: 100,
              max: 1000,
              divisions: 18,
              label: '${_corridor.round()} м',
              onChanged: (value) => setState(() => _corridor = value),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              key: const ValueKey('safe-route-save'),
              onPressed: _saving || !valid ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.route_rounded),
              label: Text(tr('Фаъол кардани масир')),
            ),
          ],
        ),
      ),
    );
  }
}
