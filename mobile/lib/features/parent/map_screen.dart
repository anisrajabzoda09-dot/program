import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/models.dart';
import '../../ui/nigoh_design.dart';
import '../../ui/widgets.dart';
import 'family_controller.dart';

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
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'tj.nigoh.nigoh_family_parent',
              ),
              MarkerLayer(
                markers: [
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
            left: 16,
            right: 16,
            bottom: 16,
            child: _LocationCard(
              child: child,
              location: location,
              refreshing: _refreshing,
              onRefresh: _refresh,
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
  });

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
                  if (battery != null) ...[
                    const SizedBox(height: 4),
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
