// Файл: харита, ҷойгиршавӣ ва таърихи ҳаракати фарзанд.

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/models.dart';
import '../../ui/avatar.dart';
import '../../ui/nigoh_design.dart';
import '../../ui/widgets.dart';
import '../../core/api.dart';
import 'family_controller.dart';
import 'parent_logic.dart';
import 'places_sheets.dart';
import '../../l10n/l10n.dart';

/// Экрани MapScreen-ро барои харита, ҷойгиршавӣ ва таърихи ҳаракати фарзанд месозад.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key, required this.controller});
  final FamilyController controller;

  /// Ҳолати MapScreen-ро барои харита, ҷойгиршавӣ ва ҷойҳои бехатар месозад.
  @override
  State<MapScreen> createState() => _MapScreenState();
}

/// Ҳолат ва рафтори MapScreenState-ро барои навсозии интерфейс идора мекунад.
class _MapScreenState extends State<MapScreen> {
  final _map = MapController();
  bool _mapReady = false;
  LatLng? _shown;
  bool _refreshing = false;

  /// Қимати _showHistory-ро барои харита, ҷойгиршавӣ ва таърихи ҳаракати фарзанд нигоҳ медорад.
  bool _showHistory = false;
  bool _historyLoading = false;
  int? _historyChild;
  List<HistoryPoint>? _history;
  String? _historyError;

  /// Controller ва listener-ҳои MapScreen-ро озод мекунад.
  @override
  void dispose() {
    _map.dispose();
    super.dispose();
  }

  /// follow мантиқи зарурии харита, ҷойгиршавӣ ва таърихи ҳаракати фарзандро иҷро мекунад.
  void _follow(LatLng point) {
    if (_shown == point) return;
    _shown = point;
    if (!_mapReady) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_mapReady) return;
      _map.move(point, _map.camera.zoom);
    });
  }

  /// refresh додаҳои харита ва ҷойгиршавӣ-ро боз мехонад ва MapScreen-ро нав мекунад.
  Future<void> _refresh() async {
    setState(() => _refreshing = true);
    await widget.controller.refresh();
    if (!mounted) return;
    setState(() => _refreshing = false);
    final error = widget.controller.error;
    if (error != null) showMessage(context, error, error: true);
  }

  /// toggleHistory ҳолатро тағйир дода, интерфейс ё server-ро нав мекунад.
  Future<void> _toggleHistory(FamilyChild child) async {
    if (_showHistory) {
      setState(() => _showHistory = false);
      return;
    }
    setState(() => _showHistory = true);
    await _loadHistory(child);
  }

  /// loadHistory додаҳоро мехонад ва ҳолати экранро нав мекунад.
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
        showMessage(context, tr('Дар 24 соати охир нуқтаҳо нестанд'));
      }
    } catch (e) {
      if (!mounted) return;
      final text = e is ApiException
          ? e.message
          : tr('Таърих гирифта нашуд: {e}', {'e': e});
      setState(() {
        _historyError = text;
        _showHistory = false;
      });
      showMessage(context, text, error: true);
    } finally {
      if (mounted) setState(() => _historyLoading = false);
    }
  }

  /// openTimeline экран, dialog ё танзимоти мувофиқро мекушояд.
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

  /// addPlace мантиқи зарурии харита, ҷойгиршавӣ ва таърихи ҳаракати фарзандро иҷро мекунад.
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

  /// openPlaces экран, dialog ё танзимоти мувофиқро мекушояд.
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

  /// Харитаро бо нишонаи фарзанд, ҷойҳои бехатар ва корти ҷойгиршавӣ месозад.
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final child = widget.controller.selected;
      if (child == null) {
        return StateMessage(
          icon: Icons.family_restroom_rounded,
          title: tr('Фарзанд ҳоло нест'),
          text: tr(
            'Аввал телефони фарзандро пайваст кунед — баъд ҷойи ӯ дар ин ҷо нишон дода мешавад.',
          ),
        );
      }
      final location = child.location;
      if (location == null) {
        return StateMessage(
          icon: Icons.location_searching_rounded,
          title: tr('Ҷойгиршавии {name} ҳоло нест', {'name': child.name}),
          text: tr(
            'Дар телефони фарзанд интернет, GPS ва иҷозати ҷойгиршавиро фаъол кунед. Харита пас аз аввалин навсозӣ пайдо мешавад.',
          ),
          actionLabel: tr('Навсозӣ'),
          actionIcon: Icons.refresh_rounded,
          primaryAction: true,
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
                      // Қадами дохилии харита, ҷойгиршавӣ ва таърихи ҳаракати фарзанд.
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
                    width: 58,
                    height: 58,
                    child: _ChildMarker(
                      child: child,
                      url: widget.controller.api.fileUrl(child.childAvatar),
                    ),
                  ),
                ],
              ),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            // Қадами дохилии харита, ҷойгиршавӣ ва таърихи ҳаракати фарзанд.
            child: MediaQuery.withClampedTextScaling(
              maxScaleFactor: _overlayTextScale,
              child: SafeArea(
                bottom: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                      child: Row(
                        children: [
                          _MapChip(
                            key: const ValueKey('history-toggle'),
                            icon: Icons.timeline_rounded,
                            label: tr('Таърихи 24 соат'),
                            tooltip: tr(
                              'Роҳи фарзанд дар 24 соати охир дар харита',
                            ),
                            selected: _showHistory,
                            busy: _historyLoading,
                            onTap: () => _toggleHistory(child),
                          ),
                          if (_showHistory && history.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            _MapChip(
                              icon: Icons.list_rounded,
                              label: tr('{count} нуқта', {
                                'count': history.length,
                              }),
                              tooltip: tr('Рӯйхати нуқтаҳо бо вақт'),
                              onTap: () => _openTimeline(history),
                            ),
                          ],
                          const SizedBox(width: 8),
                          _MapChip(
                            key: const ValueKey('places-open'),
                            icon: Icons.shield_outlined,
                            label: places.isEmpty
                                ? tr('Ҷойҳои бехатар')
                                : tr('{count} ҷойи бехатар', {
                                    'count': places.length,
                                  }),
                            tooltip: tr(
                              'Хона, мактаб — вақте фарзанд дар он ҷост, мебинед',
                            ),
                            onTap: () => _openPlaces(child),
                          ),
                        ],
                      ),
                    ),
                    const _MapHint(),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: MediaQuery.withClampedTextScaling(
              maxScaleFactor: _overlayTextScale,
              child: SafeArea(
                top: false,
                minimum: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                // Қадами дохилии харита, ҷойгиршавӣ ва таърихи ҳаракати фарзанд.
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: ConstrainedBox(
                    key: const ValueKey('map-card-area'),
                    constraints: BoxConstraints(
                      maxWidth: 520,
                      maxHeight: _bottomCardLimit(context),
                    ),
                    child: SingleChildScrollView(
                      reverse: true,
                      physics: const ClampingScrollPhysics(),
                      child: _AnimatedBox(
                        child: _LocationCard(
                          child: child,
                          avatarUrl: widget.controller.api.fileUrl(
                            child.childAvatar,
                          ),
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
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}

/// Қимати _overlayTextScale-ро барои харита, ҷойгиршавӣ ва таърихи ҳаракати фарзанд нигоҳ медорад.
const _overlayTextScale = 1.2;

/// Қимати _bottomCardShare-ро барои харита, ҷойгиршавӣ ва таърихи ҳаракати фарзанд нигоҳ медорад.
const _bottomCardShare = .34;

/// bottomCardLimit мантиқи зарурии харита, ҷойгиршавӣ ва таърихи ҳаракати фарзандро иҷро мекунад.
double _bottomCardLimit(BuildContext context) =>
    (MediaQuery.sizeOf(context).height * _bottomCardShare).clamp(110.0, 280.0);

/// AnimatedBox додаҳо ва рафтори харита ва ҷойгиршавӣ-ро ифода мекунад.
class _AnimatedBox extends StatelessWidget {
  const _AnimatedBox({required this.child});
  final Widget child;

  /// Widget-и AnimatedBox-ро барои харита, ҷойгиршавӣ ва ҷойҳои бехатар месозад.
  @override
  Widget build(BuildContext context) {
    if (reducedMotion(context)) return child;
    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: Alignment.bottomCenter,
      child: child,
    );
  }
}

/// MapHint додаҳо ва рафтори харита ва ҷойгиршавӣ-ро ифода мекунад.
class _MapHint extends StatelessWidget {
  const _MapHint();

  /// Widget-и MapHint-ро барои харита, ҷойгиршавӣ ва ҷойҳои бехатар месозад.
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: scheme.surface.withValues(alpha: .92),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.touch_app_rounded,
              size: 14,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                tr('Нуқтаро дароз пахш кунед — ҷойи бехатар илова мешавад'),
                key: const ValueKey('map-hint'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ChildMarker додаҳо ва рафтори харита ва ҷойгиршавӣ-ро ифода мекунад.
class _ChildMarker extends StatelessWidget {
  const _ChildMarker({required this.child, this.url});
  final FamilyChild child;
  final String? url;

  /// Widget-и ChildMarker-ро барои харита, ҷойгиршавӣ ва ҷойҳои бехатар месозад.
  @override
  Widget build(BuildContext context) {
    final color = child.online ? NigohDesign.blue : NigohDesign.amber;
    return Container(
      key: const ValueKey('child-marker'),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: const [BoxShadow(blurRadius: 12, color: Colors.black26)],
      ),
      child: AvatarView(
        name: child.name,
        url: url,
        size: 52,
        color: color,
        border: Border.all(color: Colors.white, width: 2),
      ),
    );
  }
}

/// Widget-и LocationCard-ро барои харита, ҷойгиршавӣ ва таърихи ҳаракати фарзанд месозад.
class _LocationCard extends StatelessWidget {
  const _LocationCard({
    required this.child,
    required this.location,
    required this.refreshing,
    required this.onRefresh,
    this.avatarUrl,
    this.placeStatus,
    this.inSafePlace = false,
    this.error,
  });

  final String? placeStatus;
  final bool inSafePlace;
  final String? error;
  final String? avatarUrl;

  final FamilyChild child;
  final ChildLocation location;
  final bool refreshing;
  final VoidCallback onRefresh;

  /// Widget-и LocationCard-ро барои харита, ҷойгиршавӣ ва ҷойҳои бехатар месозад.
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final online = location.online;
    final battery = location.batteryLevel;
    final dot = online ? NigohDesign.mint : NigohDesign.amber;
    return Material(
      key: const ValueKey('map-card'),
      color: scheme.surface,
      elevation: 3,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    AvatarView(name: child.name, url: avatarUrl, size: 44),
                    Positioned(
                      right: -1,
                      bottom: -1,
                      child: Container(
                        width: 13,
                        height: 13,
                        decoration: BoxDecoration(
                          color: dot,
                          shape: BoxShape.circle,
                          border: Border.all(color: scheme.surface, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
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
                        tr('Ҷойи охирин: {ago}', {
                          'ago': timeAgo(location.updatedAt),
                        }),
                        key: const ValueKey('map-updated'),
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                IconButton.filledTonal(
                  key: const ValueKey('map-refresh'),
                  tooltip: tr('Ҷойгиршавиро навсозӣ кардан'),
                  onPressed: refreshing ? null : onRefresh,
                  icon: refreshing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            if (battery != null || placeStatus != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  if (placeStatus != null)
                    Flexible(
                      child: _StatusLabel(
                        text: placeStatus!,
                        color: inSafePlace
                            ? NigohDesign.mint
                            : NigohDesign.amber,
                        icon: inSafePlace
                            ? Icons.shield_rounded
                            : Icons.shield_outlined,
                      ),
                    ),
                  if (placeStatus != null && battery != null)
                    const SizedBox(width: 6),
                  if (battery != null)
                    _StatusLabel(
                      text: tr('Батарея {battery}%', {'battery': battery}),
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
              const SizedBox(height: 8),
              Text(
                error!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: scheme.error, fontSize: 12),
              ),
            ],
            const SizedBox(height: 6),
            Text(
              '© OpenStreetMap contributors',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

/// StatusLabel додаҳо ва рафтори харита ва ҷойгиршавӣ-ро ифода мекунад.
class _StatusLabel extends StatelessWidget {
  const _StatusLabel({
    required this.text,
    required this.color,
    required this.icon,
  });

  final String text;
  final Color color;
  final IconData icon;

  /// Widget-и StatusLabel-ро барои харита, ҷойгиршавӣ ва ҷойҳои бехатар месозад.
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}

/// MapChip додаҳо ва рафтори харита ва ҷойгиршавӣ-ро ифода мекунад.
class _MapChip extends StatelessWidget {
  const _MapChip({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.tooltip,
    this.selected = false,
    this.busy = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final String? tooltip;
  final bool selected;
  final bool busy;

  /// Widget-и MapChip-ро барои харита, ҷойгиршавӣ ва ҷойҳои бехатар месозад.
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = selected ? Colors.white : scheme.onSurface;
    final chip = AnimatedContainer(
      duration: Duration(milliseconds: reducedMotion(context) ? 0 : 200),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: selected ? NigohDesign.violet : scheme.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: selected ? NigohDesign.violet : scheme.outlineVariant,
        ),
        boxShadow: const [BoxShadow(blurRadius: 6, color: Colors.black12)],
      ),
      child: Material(
        color: Colors.transparent,
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
      ),
    );
    final hint = tooltip;
    return hint == null ? chip : Tooltip(message: hint, child: chip);
  }
}

/// PathDot додаҳо ва рафтори харита ва ҷойгиршавӣ-ро ифода мекунад.
class _PathDot extends StatelessWidget {
  const _PathDot({required this.color, required this.icon});
  final Color color;
  final IconData icon;

  /// Widget-и PathDot-ро барои харита, ҷойгиршавӣ ва ҷойҳои бехатар месозад.
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

/// PlaceLabel додаҳо ва рафтори харита ва ҷойгиршавӣ-ро ифода мекунад.
class _PlaceLabel extends StatelessWidget {
  const _PlaceLabel({required this.name});
  final String name;

  /// Widget-и PlaceLabel-ро барои харита, ҷойгиршавӣ ва ҷойҳои бехатар месозад.
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
