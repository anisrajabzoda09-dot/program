// Access center: a checklist page of every Android permission/protection
// NIGOH needs, with buttons that open the matching dialog or settings screen.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

import '../l10n/l10n.dart';

/// A friendly, step-by-step permission setup. Android still owns the final
/// consent screen for special permissions; this page keeps the flow simple.
class AccessCenterPage extends StatefulWidget {
  const AccessCenterPage({super.key, required this.childMode});
  final bool childMode;

  @override
  State<AccessCenterPage> createState() => _AccessCenterPageState();
}

/// Reads the protection status from native code and runs the step actions,
/// re-checking when the app resumes.
class _AccessCenterPageState extends State<AccessCenterPage>
    with WidgetsBindingObserver {
  static const channel = MethodChannel('tj.nigoh/device_control');
  Map<String, dynamic> status = {};
  bool loading = true;
  bool busy = false;
  String? error;

  bool allowed(String key) => status[key] == true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) refresh();
  }

  /// Re-reads which permissions and protections are active.
  Future<void> refresh() async {
    try {
      final result = await channel.invokeMapMethod<String, dynamic>(
        'getProtectionStatus',
      );
      if (!mounted) return;
      setState(() {
        status = result ?? {};
        loading = false;
        error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = tr('Ҳолати иҷозатҳо санҷида нашуд. Дубора кӯшиш кунед.');
      });
    }
  }

  /// Runs a step action once at a time, then refreshes the status.
  Future<void> act(Future<void> Function() action) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await action();
      await refresh();
    } catch (_) {
      if (mounted) {
        setState(
          () => error = tr(
            'Танзимот кушода нашуд. Аз Settings → Apps → NIGOH Family кушоед.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  /// Calls a native method that opens a system settings screen.
  Future<void> open(String method) async {
    await channel.invokeMethod<Object?>(method);
  }

  /// Requests a runtime permission, or opens app settings if it is blocked.
  Future<void> request(ph.Permission permission) async {
    final current = await permission.status;
    if (current.isPermanentlyDenied || current.isRestricted) {
      await ph.openAppSettings();
      return;
    }
    await permission.request();
  }

  /// Opens the dialog or settings screen for the step [key].
  Future<void> runStep(String key) async {
    switch (key) {
      case 'location':
        await request(ph.Permission.locationWhenInUse);
      case 'backgroundLocation':
        if (!allowed('location')) {
          await request(ph.Permission.locationWhenInUse);
        } else {
          await request(ph.Permission.locationAlways);
        }
      case 'gps':
        await Geolocator.openLocationSettings();
      case 'notifications':
        await request(ph.Permission.notification);
      case 'camera':
        await request(ph.Permission.camera);
      case 'usage':
        await open('openUsageSettings');
      case 'overlay':
        await open('openOverlaySettings');
      case 'accessibility':
        await open('openAccessibilitySettings');
      case 'deviceAdmin':
        await open('openDeviceAdminSettings');
    }
  }

  /// Child phone: whether the protections needed for app blocking are on.
  bool get protectionReady =>
      !widget.childMode ||
      (allowed('usage') && allowed('overlay') && allowed('accessibility'));

  /// First required step that is still missing (drives the hero image).
  String get activeKey {
    const required = [
      'location',
      'notifications',
      'usage',
      'overlay',
      'accessibility',
    ];
    for (final key in required) {
      if (!allowed(key)) return key;
    }
    return 'permissions_hero';
  }

  /// Illustration for the step currently being set up.
  String get activeImage {
    switch (activeKey) {
      case 'location':
        return 'assets/permissions/location.jpg';
      case 'usage':
      case 'overlay':
      case 'accessibility':
        return 'assets/permissions/apps.jpg';
      default:
        return 'assets/permissions/permissions_hero.jpg';
    }
  }

  /// The checklist steps with their titles, descriptions and icons.
  List<_PermissionStepData> get steps => [
    _PermissionStepData(
      key: 'location',
      title: tr('Ҷойгиршавӣ'),
      description: tr('Барои дидани ҷойи фарзанд дар харита.'),
      icon: Icons.location_on_rounded,
    ),
    _PermissionStepData(
      key: 'notifications',
      title: tr('Огоҳиномаҳо'),
      description: tr('Барои паёмҳои оила ва дархостҳои нав.'),
      icon: Icons.notifications_rounded,
    ),
    if (widget.childMode)
      _PermissionStepData(
        key: 'usage',
        title: tr('Вақти истифодаи барномаҳо'),
        description: tr('Барои ҳисоб кардани вақти ҳар барнома.'),
        icon: Icons.bar_chart_rounded,
      ),
    if (widget.childMode)
      _PermissionStepData(
        key: 'overlay',
        title: tr('Экрани муҳофизат'),
        description: tr('Барои нишон додани экрани маҳкамкунӣ.'),
        icon: Icons.layers_rounded,
      ),
    if (widget.childMode)
      _PermissionStepData(
        key: 'accessibility',
        title: tr('Назорати барномаҳо'),
        description: tr('Барои маҳкамкунии фаврии барномаи интихобшуда.'),
        icon: Icons.accessibility_new_rounded,
      ),
    _PermissionStepData(
      key: 'camera',
      title: tr('Камера барои QR'),
      description: tr('Ихтиёрӣ: пайвастшавӣ бо QR осонтар мешавад.'),
      icon: Icons.qr_code_scanner_rounded,
      optional: true,
    ),
    if (widget.childMode)
      _PermissionStepData(
        key: 'backgroundLocation',
        title: tr('Ҷойгиршавӣ дар пасзамина'),
        description: tr('Ихтиёрӣ: ҷой ҳангоми баста будани экран нав мешавад.'),
        icon: Icons.location_history_rounded,
        optional: true,
      ),
    if (widget.childMode)
      _PermissionStepData(
        key: 'deviceAdmin',
        title: tr('Муҳофизати несткунӣ'),
        description: tr('Ихтиёрӣ: огоҳӣ пеш аз ғайрифаъолкунӣ.'),
        icon: Icons.admin_panel_settings_rounded,
        optional: true,
      ),
  ];

  _PermissionStepData? get nextRequiredStep {
    for (final step in steps) {
      if (!step.optional && !allowed(step.key)) return step;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final completed = steps.where((step) => allowed(step.key)).length;
    final progress = steps.isEmpty ? 1.0 : completed / steps.length;
    final next = nextRequiredStep;

    return RefreshIndicator(
      onRefresh: refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              Expanded(
                child: Text(
                  tr('Омодасозии NIGOH'),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).maybePop(),
                child: Text(tr('Баъдтар')),
              ),
            ],
          ),
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2563EB), Color(0xFF0EA5E9)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(26),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x332563EB),
                  blurRadius: 20,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.shield_rounded, color: Colors.white),
                      const SizedBox(width: 8),
                      Text(
                        tr('Қадам ба қадам'),
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    tr(
                      'Барои кори дурусти NIGOH чанд иҷозати Android лозим аст.',
                    ),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: .92),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 9,
                      backgroundColor: Colors.white.withValues(alpha: .26),
                      valueColor: const AlwaysStoppedAnimation(Colors.white),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    tr('{done} аз {total} омода', {
                      'done': completed,
                      'total': steps.length,
                    }),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Image.asset(
              activeImage,
              height: 220,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          if (widget.childMode && !protectionReady) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: busy ? null : () => act(() => open('openAppDetails')),
              icon: const Icon(Icons.settings_applications),
              label: Text(tr('Кушодани App info')),
            ),
          ],
          const SizedBox(height: 16),
          if (loading) const LinearProgressIndicator(),
          if (error != null)
            Card(
              color: theme.colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text(error!),
              ),
            ),
          if (!loading && widget.childMode && protectionReady)
            Card(
              color: const Color(0xFFE7F8F3),
              child: ListTile(
                leading: Icon(Icons.check_circle, color: Colors.teal),
                title: Text(
                  tr('Иҷозатҳои бастани барномаҳо дода шуданд'),
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                subtitle: Text(
                  tr(
                    'Акнун волидайн метавонад вақт ва барномаҳоро идора кунад.',
                  ),
                ),
              ),
            ),
          if (!loading && widget.childMode && !protectionReady)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr('Бастани барномаҳо ҳоло омода нест'),
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      tr(
                        'Барои App Control се иҷозати Android лозим аст: Usage access, Accessibility ва Display over other apps.',
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      tr('«Restricted setting» ё «App was denied access»?'),
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      tr(
                        'Аввал қадамҳои кабуди болоиро иҷро кунед, баъд ҳар иҷозатро аз рӯйхати поён боз кунед.',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (!loading && widget.childMode && !protectionReady)
            Card(
              color: const Color(0xFFEFF6FF),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr(
                        'Агар Android «Controlled by restricted setting» гӯяд',
                      ),
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    SizedBox(height: 8),
                    Text(
                      tr(
                        '1. «App info»-ро кушоед.\n'
                        '2. Дар кунҷи боло ⋮ → «Allow restricted settings»-ро интихоб кунед ва бо рамзи телефон тасдиқ намоед.\n'
                        '3. Ба ин саҳифа баргардед ва Usage access, Display over other apps ва Accessibility-ро як-як фаъол кунед.',
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      tr(
                        'Ин танзимро танҳо соҳиби телефон дар Android дода метавонад; NIGOH онро худкор фаъол карда наметавонад.',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
          ...steps.asMap().entries.map((entry) {
            final index = entry.key + 1;
            final step = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _PermissionStepCard(
                number: index,
                data: step,
                done: allowed(step.key),
                onPressed: busy ? null : () => act(() => runStep(step.key)),
              ),
            );
          }),
          const SizedBox(height: 4),
          FilledButton.icon(
            onPressed: busy || next == null
                ? null
                : () => act(() => runStep(next.key)),
            icon: busy
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.arrow_forward_rounded),
            label: Text(
              next == null
                  ? tr('Ҳамаи қадамҳои асосӣ тайёр')
                  : tr('Иҷозати навбатӣ'),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: busy ? null : refresh,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(tr('Аз нав санҷидан')),
          ),
          if (widget.childMode && !protectionReady)
            Card(
              color: const Color(0xFFFFF3DF),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                  tr(
                    'Агар Android иҷозатро боз ҳам маҳкам кунад, онро аз Settings → Apps → NIGOH Family фаъол кунед. Ин маҳдудияти худи Android аст.',
                  ),
                  style: TextStyle(color: Colors.brown.shade900),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Static copy of one checklist step.
class _PermissionStepData {
  const _PermissionStepData({
    required this.key,
    required this.title,
    required this.description,
    required this.icon,
    this.optional = false,
  });

  final String key;
  final String title;
  final String description;
  final IconData icon;
  final bool optional;
}

/// Numbered checklist card with done state and an action button.
class _PermissionStepCard extends StatelessWidget {
  const _PermissionStepCard({
    required this.number,
    required this.data,
    required this.done,
    required this.onPressed,
  });

  final int number;
  final _PermissionStepData data;
  final bool done;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      elevation: done ? 0 : 1,
      color: done ? const Color(0xFFE7F8F3) : null,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: done
                    ? Colors.teal
                    : colorScheme.primary.withValues(alpha: .12),
                foregroundColor: done ? Colors.white : colorScheme.primary,
                child: done
                    ? const Icon(Icons.check_rounded)
                    : Text(
                        '$number',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: done
                      ? Colors.white.withValues(alpha: .75)
                      : colorScheme.primary.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(data.icon, color: colorScheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            data.title,
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                        if (data.optional)
                          Text(
                            tr('ихтиёрӣ'),
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      done ? tr('Иҷозат дода шуд') : data.description,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: done ? Colors.teal.shade800 : null,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                done ? Icons.check_circle : Icons.chevron_right_rounded,
                color: done ? Colors.teal : colorScheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
