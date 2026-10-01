import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/models.dart';
import '../../ui/nigoh_design.dart';
import '../../ui/widgets.dart';
import 'family_controller.dart';

class _Entry {
  const _Entry(this.child, this.request);
  final FamilyChild child;
  final TimeRequest request;
}

/// Inbox of extra-time requests from all children: pending first (approve
/// with 15/30/60 or the requested minutes, or deny), recent decisions below.
class TimeRequestsScreen extends StatefulWidget {
  const TimeRequestsScreen({super.key, required this.controller});
  final FamilyController controller;

  @override
  State<TimeRequestsScreen> createState() => _TimeRequestsScreenState();
}

class _TimeRequestsScreenState extends State<TimeRequestsScreen> {
  List<_Entry>? _entries;
  String? _error;
  bool _loading = false;
  final Set<int> _busy = {};

  FamilyController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final entries = <_Entry>[];
      for (final child in controller.children.where((c) => c.paired)) {
        final raw = await controller.api.timeRequests(child.id);
        entries.addAll(raw.map((r) => _Entry(child, TimeRequest.fromJson(r))));
      }
      entries.sort((a, b) {
        final ta = a.request.createdAt, tb = b.request.createdAt;
        if (ta == null || tb == null) return b.request.id - a.request.id;
        return tb.compareTo(ta);
      });
      if (!mounted) return;
      setState(() => _entries = entries);
    } catch (e) {
      if (!mounted) return;
      setState(
        () => _error = e is ApiException
            ? e.message
            : 'Дархостҳо гирифта нашуд: $e',
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _approve(_Entry entry) async {
    final minutes = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (_) => _ApproveSheet(entry: entry),
    );
    if (minutes == null || !mounted) return;
    await _decide(entry, approve: true, minutes: minutes);
  }

  Future<void> _decide(
    _Entry entry, {
    required bool approve,
    int? minutes,
  }) async {
    setState(() => _busy.add(entry.request.id));
    try {
      await controller.decideRequest(
        entry.child.id,
        entry.request.id,
        approve: approve,
        minutes: minutes,
      );
      if (!mounted) return;
      showMessage(
        context,
        approve
            ? '${entry.request.appName}: +$minutes дақ иҷозат дода шуд'
            : 'Дархост рад карда шуд',
      );
      await _load();
    } catch (e) {
      if (mounted) showMessage(context, e, error: true);
    } finally {
      if (mounted) setState(() => _busy.remove(entry.request.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final entries = _entries;
    Widget body;
    if (entries == null && _error == null) {
      body = const Center(child: CircularProgressIndicator());
    } else if (entries == null) {
      body = StateMessage(
        icon: Icons.cloud_off_rounded,
        title: 'Дархостҳо гирифта нашуд',
        text: _error,
        actionLabel: 'Аз нав кӯшиш',
        onAction: _load,
        error: true,
      );
    } else {
      final pending = entries
          .where((e) => e.request.status == 'pending')
          .toList();
      final decided = entries
          .where((e) => e.request.status != 'pending')
          .take(15)
          .toList();
      body = RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
          children: [
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            SectionTitle('Интизори ҷавоб (${pending.length})'),
            if (pending.isEmpty)
              const _EmptyNote(
                icon: Icons.inbox_rounded,
                text:
                    'Дархости нав нест. Вақте фарзанд вақти иловагӣ '
                    'пурсад, он дар ин ҷо пайдо мешавад.',
              ),
            for (final (index, entry) in pending.indexed)
              FadeIn(
                key: ValueKey('req-${entry.request.id}'),
                index: index,
                child: _RequestCard(
                  entry: entry,
                  busy: _busy.contains(entry.request.id),
                  onApprove: () => _approve(entry),
                  onDeny: () => _decide(entry, approve: false),
                ),
              ),
            if (decided.isNotEmpty) ...[
              const SectionTitle('Ҷавобҳои охирин'),
              for (final entry in decided) _DecidedTile(entry: entry),
            ],
          ],
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Дархостҳои вақт'),
        actions: [
          IconButton(
            tooltip: 'Навсозӣ',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: body,
      ),
    );
  }
}

class _EmptyNote extends StatelessWidget {
  const _EmptyNote({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(icon, color: scheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: TextStyle(color: scheme.onSurfaceVariant)),
          ),
        ],
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.entry,
    required this.busy,
    required this.onApprove,
    required this.onDeny,
  });

  final _Entry entry;
  final bool busy;
  final VoidCallback onApprove;
  final VoidCallback onDeny;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final r = entry.request;
    final app = entry.child.apps
        .where((a) => a.packageName == r.packageName)
        .firstOrNull;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: NigohDesign.amber.withValues(alpha: .45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              NigohAppIcon(
                icon: app?.iconBase64 ?? '',
                seed: r.packageName,
                size: 42,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.appName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      '${entry.child.name} · ${timeAgo(r.createdAt)}',
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Pill(
                '+${r.minutes} дақ',
                color: NigohDesign.amber,
                icon: Icons.more_time_rounded,
              ),
            ],
          ),
          if ((r.reason ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: .5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('«${r.reason!.trim()}»'),
            ),
          ],
          const SizedBox(height: 12),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: busy
                ? const LinearProgressIndicator(key: ValueKey('busy'))
                : Row(
                    key: const ValueKey('idle'),
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          key: ValueKey('deny-${r.id}'),
                          onPressed: onDeny,
                          icon: const Icon(Icons.close_rounded, size: 18),
                          label: const Text('Рад кардан'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          key: ValueKey('approve-${r.id}'),
                          onPressed: onApprove,
                          icon: const Icon(Icons.check_rounded, size: 18),
                          label: const Text('Иҷозат'),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _ApproveSheet extends StatelessWidget {
  const _ApproveSheet({required this.entry});
  final _Entry entry;

  @override
  Widget build(BuildContext context) {
    final requested = entry.request.minutes;
    final options = <int>{requested, 15, 30, 60}.toList();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Чанд дақиқа барои ${entry.request.appName}?',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              '${entry.child.name} $requested дақ пурсид. Вақт танҳо барои имрӯз илова мешавад.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final m in options)
                  m == requested
                      ? FilledButton(
                          key: ValueKey('grant-$m'),
                          onPressed: () => Navigator.pop(context, m),
                          child: Text('+$m дақ (дархост)'),
                        )
                      : FilledButton.tonal(
                          key: ValueKey('grant-$m'),
                          onPressed: () => Navigator.pop(context, m),
                          child: Text('+$m дақ'),
                        ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DecidedTile extends StatelessWidget {
  const _DecidedTile({required this.entry});
  final _Entry entry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final r = entry.request;
    final approved = r.status == 'approved';
    final color = approved ? NigohDesign.mint : scheme.outline;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(
            approved ? Icons.check_circle_rounded : Icons.cancel_rounded,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${r.appName} · ${entry.child.name}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '${approved ? 'Иҷозат' : 'Рад'} · ${timeAgo(r.createdAt)}',
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
