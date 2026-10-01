import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/models.dart';
import '../../ui/nigoh_design.dart';
import '../../ui/widgets.dart';
import '../../core/api.dart';
import 'family_controller.dart';
import 'parent_logic.dart';
import 'places_sheets.dart';

/// Last known location of the selected child on an OpenStreetMap map.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key, required this.controller});
  final FamilyController controller;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _map = MapController();
  bool _mapReady = false;
  LatLng? _shown;
  bool _refreshing = false;

  /// 24 h path.
  bool _showHistory = false;
  bool _historyLoading = false;
  int? _historyChild;
  List<HistoryPoint>? _history;
  String? _historyError;

  @override
  void dispose() {
    _map.dispose();
    super.dispose();
  }

  void _follow(LatLng point) {
    if (_shown == point) return;
    _shown = point;
    if (!_mapReady) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_mapReady) return;
      _map.move(point, _map.camera.zoom);
    });
  }

  Future<void> _refresh() async {
    setState(() => _refreshing = true);
    await widget.controller.refresh();
    if (!mounted) return;
    setState(() => _refreshing = false);
    final error = widget.controller.error;
    if (error != null) showMessage(context, error, error: true);
  }

  Future<void> _toggleHistory(FamilyChild child) async {
    if (_showHistory) {
      setState(() => _showHistory = false);
      return;
    }
    setState(() => _showHistory = true);
    await _loadHistory(child);
  }

  Future<void> _loadHistory(FamilyChild child) async {
    setState(() {
      _historyLoading = true;
      _historyError = null;
    });
    try {
      final raw = await widget.controller.api.locationHistory(child.id);
      if (!mounted) return;
      setState(() {
        _history = HistoryPoint.listFromJson(raw);
        _historyChild = child.id;
      });
      if (_history!.isEmpty) {
        showMessage(context, 'Дар 24 соати охир нуқтаҳо нестанд');
      }
    } catch (e) {
      if (!mounted) return;
      final text = e is ApiException ? e.message : 'Таърих гирифта нашуд: $e';
      setState(() {
        _historyError = text;
        _showHistory = false;
      });
      showMessage(context, text, error: true);
    } finally {
      if (mounted) setState(() => _historyLoading = false);
    }
  }

  void _openTimeline(List<HistoryPoint> points) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => HistoryTimelineSheet(
        points: points,
        onSelect: (p) {
          Navigator.pop(context);
          if (_mapReady) _map.move(LatLng(p.latitude, p.longitude), 17);
        },
      ),
    );
  }

  Future<void> _addPlace(FamilyChild child, LatLng? at) async {
    final location = child.location;
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => AddPlaceSheet(
        controller: widget.controller,
        child: child,
        tapped: at,
        childPosition: location == null
            ? null
            : LatLng(location.latitude, location.longitude),
      ),
    );
  }

  void _openPlaces(FamilyChild child) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => PlacesSheet(
        controller: widget.controller,
        childId: child.id,
        onAdd: () {
          Navigator.pop(context);
          _addPlace(child, null);
        },
        onShow: (place) {
          Navigator.pop(context);
          if (_mapReady) {
            _map.move(LatLng(place.latitude, place.longitude), 16);
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final child = widget.controller.selected;
      if (child == null) {
        return const StateMessage(
          icon: Icons.family_restroom_rounded,
          title: 'Фарзанд ҳоло нест',
        );
      }
      final location = child.location;
      if (location == null) {
        return StateMessage(
          icon: Icons.location_searching_rounded,
          title: 'Ҷойгиршавии ${child.name} ҳоло нест',
          text:
              'Дар телефони фарзанд интернет, GPS ва иҷозати ҷойгиршавиро '
              'фаъол кунед. Харита пас аз аввалин навсозӣ пайдо мешавад.',
          actionLabel: 'Навсозӣ',
          onAction: _refresh,
          error: widget.controller.error != null,
        );
      }
      final point = LatLng(location.latitude, location.longitude);
      _follow(point);
      final places = widget.controller.placesFor(child.id);
      final history = _showHistory && _historyChild == child.id
          ? (_history ?? const <HistoryPoint>[])
          : const <HistoryPoint>[];
      final path = [for (final h in history) LatLng(h.latitude, h.longitude)];
      final status = placeStatus(location, places);
      return Stack(
        children: [
          FlutterMap(
            key: ValueKey('map-${child.id}'),
            mapController: _map,
            options: MapOptions(
              initialCenter: point,
              initialZoom: 16,
              onMapReady: () {
                _mapReady = true;
                _shown = point;
              },
              onLongPress: (_, latLng) => _addPlace(child, latLng),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'tj.nigoh.nigoh_family_parent',
              ),
              if (places.isNotEmpty)
                CircleLayer(
                  circles: [
                    for (final place in places)
                      CircleMarker(
                        point: LatLng(place.latitude, place.longitude),
                        radius: place.radiusMeters.toDouble(),
                        useRadiusInMeter: true,
                        color: NigohDesign.mint.withValues(alpha: .16),
                        borderColor: NigohDesign.mint,
                        borderStrokeWidth: 2,
                      ),
                  ],
                ),
              if (path.length >= 2)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: path,
                      strokeWidth: 4,
                      color: NigohDesign.violet.withValues(alpha: .85),
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  for (final place in places)
                    Marker(
                      point: LatLng(place.latitude, place.longitude),
                      width: 130,
                      height: 110,
                      // Label sits above the circle centre, clear of the child.
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: _PlaceLabel(name: place.name),
                      ),
                    ),
                  if (path.length >= 2) ...[
                    Marker(
                      point: path.first,
                      width: 22,
                      height: 22,
                      child: const _PathDot(
                        color: NigohDesign.mint,
                        icon: Icons.play_arrow_rounded,
                      ),
                    ),
                    Marker(
                      point: path.last,
                      width: 22,
                      height: 22,
                      child: const _PathDot(
                        color: NigohDesign.coral,
                        icon: Icons.stop_rounded,
                      ),
                    ),
                  ],
                  Marker(
                    point: point,
                    width: 64,
                    height: 64,
                    child: _ChildMarker(child: child),
                  ),
                ],
              ),
              const RichAttributionWidget(
                attributions: [
                  TextSourceAttribution('© OpenStreetMap contributors'),
                ],
              ),
            ],
          ),
          Positioned(
            left: 12,
            right: 12,
            top: 12,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _MapChip(
                    key: const ValueKey('history-toggle'),
                    icon: Icons.timeline_rounded,
                    label: 'Таърихи 24 соат',
                    selected: _showHistory,
                    busy: _historyLoading,
                    onTap: () => _toggleHistory(child),
                  ),
                  if (_showHistory && history.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    _MapChip(
                      icon: Icons.list_rounded,
                      label: 'Нуқтаҳо (${history.length})',
                      onTap: () => _openTimeline(history),
                    ),
                  ],
                  const SizedBox(width: 8),
                  _MapChip(
                    key: const ValueKey('places-open'),
                    icon: Icons.shield_outlined,
                    label: places.isEmpty
                        ? 'Ҷойҳои бехатар'
                        : 'Ҷойҳо (${places.length})',
                    onTap: () => _openPlaces(child),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: _LocationCard(
              child: child,
              location: location,
              refreshing: _refreshing,
              onRefresh: _refresh,
              placeStatus: status,
              inSafePlace:
                  status != null &&
                  placeContaining(
                        location.latitude,
                        location.longitude,
                        places,
                      ) !=
                      null,
              error: _historyError ?? widget.controller.placesError,
            ),
          ),
        ],
      );
    },
  );
}

class _ChildMarker extends StatelessWidget {
  const _ChildMarker({required this.child});
  final FamilyChild child;

  @override
  Widget build(BuildContext context) {
    final color = child.online ? NigohDesign.blue : NigohDesign.amber;
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 4),
        boxShadow: const [BoxShadow(blurRadius: 14, color: Colors.black26)],
      ),
      alignment: Alignment.center,
      child: Text(
        child.name.isEmpty ? '?' : child.name.characters.first.toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _LocationCard extends StatelessWidget {
  const _LocationCard({
    required this.child,
    required this.location,
    required this.refreshing,
    required this.onRefresh,
    this.placeStatus,
    this.inSafePlace = false,
    this.error,
  });

  final String? placeStatus;
  final bool inSafePlace;
  final String? error;

  final FamilyChild child;
  final ChildLocation location;
  final bool refreshing;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final online = location.online;
    final battery = location.batteryLevel;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: (online ? NigohDesign.mint : NigohDesign.amber)
                    .withValues(alpha: .12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.location_on_rounded,
                color: online ? NigohDesign.mint : NigohDesign.amber,
              ),
            ),
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
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Навсозӣ: ${timeAgo(location.updatedAt)}',
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                  if (battery != null || placeStatus != null) ...[
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (placeStatus != null)
                          Pill(
                            placeStatus!,
                            color: inSafePlace
                                ? NigohDesign.mint
                                : NigohDesign.amber,
                            icon: inSafePlace
                                ? Icons.shield_rounded
                                : Icons.shield_outlined,
                          ),
                        if (battery != null)
                          Pill(
                            'Батарея $battery%',
                            color: battery <= 15
                                ? NigohDesign.coral
                                : NigohDesign.mint,
                            icon: battery <= 15
                                ? Icons.battery_alert_rounded
                                : Icons.battery_std_rounded,
                          ),
                      ],
                    ),
                  ],
                  if (error != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      error!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: scheme.error, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.tonalIcon(
              onPressed: refreshing ? null : onRefresh,
              icon: refreshing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Навсозӣ'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapChip extends StatelessWidget {
  const _MapChip({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
    this.busy = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = selected ? Colors.white : scheme.onSurface;
    return Material(
      color: selected ? NigohDesign.violet : scheme.surface,
      elevation: 2,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: busy ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              busy
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: fg,
                      ),
                    )
                  : Icon(icon, size: 17, color: fg),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(color: fg, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PathDot extends StatelessWidget {
  const _PathDot({required this.color, required this.icon});
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: color,
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white, width: 2),
    ),
    child: Icon(icon, size: 13, color: Colors.white),
  );
}

class _PlaceLabel extends StatelessWidget {
  const _PlaceLabel({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface.withValues(alpha: .92),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: NigohDesign.mint.withValues(alpha: .6)),
    ),
    child: Text(
      name,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: NigohDesign.mint,
      ),
    ),
  );
}
