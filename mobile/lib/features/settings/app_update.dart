import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api.dart';
import '../../core/platform.dart';
import '../../core/user_journey_logic.dart';
import '../../ui/widgets.dart';
import '../../l10n/l10n.dart';

/// Checks `/api/mobile/version` and offers the in-app APK update
/// (native `tj.nigoh/update` → installUpdate).
abstract final class AppUpdate {
  static const channel = MethodChannel('tj.nigoh/update');

  /// Last error of the automatic (silent) check, for a visible status.
  static final lastError = ValueNotifier<String?>(null);

  /// Download page for the desktop app (no in-app installer there).
  static final downloadPage = Uri.parse('https://nigohfamily.qobus.tj/get');

  /// Opens [downloadPage] in the browser (replaced in tests).
  static Future<bool> Function(Uri url) openUrl = (url) =>
      launchUrl(url, mode: LaunchMode.externalApplication);

  static Future<int> installedCode() async =>
      int.tryParse((await PackageInfo.fromPlatform()).buildNumber) ?? 0;

  /// [silent]: automatic start-up check — no "up to date" message and errors
  /// are kept in [lastError] instead of a snackbar.
  static Future<void> check(
    BuildContext context,
    NigohApi api, {
    bool silent = false,
  }) async {
    Map<String, dynamic> release;
    int current;
    try {
      current = await installedCode();
      release = await api.version(current);
      lastError.value = null;
    } catch (e) {
      final text = e is ApiException ? e.message : tr('Навсозӣ санҷида нашуд.');
      lastError.value = text;
      if (!silent && context.mounted) showMessage(context, text, error: true);
      return;
    }
    if (!context.mounted) return;
    if (isDesktop) return _desktop(context, release, current, silent: silent);
    final latest = (release['version_code'] as num?)?.toInt() ?? 0;
    final url = release['download_url']?.toString() ?? '';
    final available =
        release['update_available'] == true &&
        UserJourneyLogic.shouldOfferUpdate(latest, current) &&
        url.isNotEmpty;
    if (!available) {
      if (!silent) showMessage(context, tr('Шумо версияи охиринро доред.'));
      return;
    }
    final version = release['version']?.toString() ?? '$latest';
    final notes = release['release_notes']?.toString().trim();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.system_update_rounded, size: 36),
        title: Text('NIGOH Family $version'),
        content: Text(
          notes == null || notes.isEmpty
              ? tr('Версияи нав бо беҳбудиҳо дастрас аст.')
              : notes,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(tr('Баъдтар')),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size(130, 44)),
            onPressed: () {
              Navigator.pop(dialogContext);
              install(context, url, version);
            },
            icon: const Icon(Icons.download_rounded),
            label: Text(tr('Навсозӣ')),
          ),
        ],
      ),
    );
  }

  /// Desktop: no APK installer; show the latest version and a link to the
  /// download page. The silent start-up check only speaks up when newer.
  static Future<void> _desktop(
    BuildContext context,
    Map<String, dynamic> release,
    int current, {
    required bool silent,
  }) async {
    final latest = (release['version_code'] as num?)?.toInt() ?? 0;
    final newer =
        release['update_available'] == true &&
        UserJourneyLogic.shouldOfferUpdate(latest, current);
    if (silent && !newer) return;
    final version =
        release['version']?.toString() ?? (latest > 0 ? '$latest' : '—');
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: const ValueKey('desktop-update'),
        icon: const Icon(Icons.system_update_rounded, size: 36),
        title: Text(tr('Версияи охирин: {version}', {'version': version})),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Text(
            newer
                ? tr(
                    'Версияи нав дастрас аст. Онро аз сайт боргирӣ кунед ва насб кунед.',
                  )
                : tr('Барномаи нав аз сайти NIGOH Family боргирӣ мешавад.'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(tr('Пӯшидан')),
          ),
          FilledButton.icon(
            key: const ValueKey('desktop-update-open'),
            style: FilledButton.styleFrom(minimumSize: const Size(130, 44)),
            onPressed: () async {
              Navigator.pop(dialogContext);
              var ok = false;
              try {
                ok = await openUrl(downloadPage);
              } catch (_) {
                ok = false;
              }
              if (!ok && context.mounted) {
                showMessage(
                  context,
                  tr('Саҳифа кушода нашуд: {url}', {'url': '$downloadPage'}),
                  error: true,
                );
              }
            },
            icon: const Icon(Icons.open_in_new_rounded),
            label: Text(tr('Кушодани саҳифаи боргирӣ')),
          ),
        ],
      ),
    );
  }

  static const progressChannel = EventChannel('tj.nigoh/update_progress');

  /// One tap: download → verify signature → install over the current app.
  /// Data, sign-in and permissions stay. Progress is shown in a dialog.
  static Future<void> install(
    BuildContext context,
    String url,
    String version,
  ) async {
    if (!isAndroidApp) return; // The APK installer exists only on Android.
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) {
      showMessage(context, tr('Пайванди навсозӣ дастрас нест.'), error: true);
      return;
    }
    final events = progressChannel
        .receiveBroadcastStream()
        .map((e) => UpdateProgress.fromEvent(e))
        .asBroadcastStream();
    String? status;
    try {
      // Listen before starting so no early progress event is lost.
      final first = events.first.catchError(
        (_) => const UpdateProgress('error'),
      );
      status = await channel.invokeMethod<String>('installUpdate', {
        'downloadUrl': url,
        'version': version,
      });
      unawaited(first);
    } catch (_) {
      if (context.mounted) {
        showMessage(
          context,
          tr('Навсозӣ оғоз нашуд. Интернетро санҷед.'),
          error: true,
        );
      }
      return;
    }
    if (!context.mounted) return;
    if (status == 'install_permission_required') {
      showMessage(
        context,
        tr(
          'Як бор иҷозат диҳед: «Иҷозати насб аз ин манбаъ»-ро фаъол кунед ва ба NIGOH баргардед — навсозӣ худаш идома меёбад.',
        ),
      );
    }
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => UpdateProgressDialog(version: version, events: events),
    );
  }
}

/// State reported by the native updater.
class UpdateProgress {
  const UpdateProgress(this.state, {this.progress, this.message});

  /// downloading | verifying | installing | done | error
  final String state;
  final double? progress;
  final String? message;

  factory UpdateProgress.fromEvent(Object? raw) {
    if (raw is! Map) return const UpdateProgress('error');
    return UpdateProgress(
      raw['state']?.toString() ?? 'error',
      progress: (raw['progress'] as num?)?.toDouble(),
      message: raw['message']?.toString(),
    );
  }

  String get label => switch (state) {
    'downloading' => tr('Боргирӣ… {percent}%', {
      'percent': ((progress ?? 0) * 100).round(),
    }),
    'verifying' => tr('Санҷиши имзо…'),
    'installing' => message ?? tr('Насб…'),
    'done' => tr('Навсозӣ насб шуд.'),
    _ => message ?? tr('Навсозӣ насб нашуд.'),
  };
}

class UpdateProgressDialog extends StatelessWidget {
  const UpdateProgressDialog({
    super.key,
    required this.version,
    required this.events,
  });

  final String version;
  final Stream<UpdateProgress> events;

  @override
  Widget build(BuildContext context) => StreamBuilder<UpdateProgress>(
    stream: events,
    initialData: const UpdateProgress('downloading', progress: 0),
    builder: (context, snap) {
      final p = snap.data!;
      final failed = p.state == 'error';
      final finished = failed || p.state == 'done';
      final scheme = Theme.of(context).colorScheme;
      return AlertDialog(
        icon: Icon(
          failed ? Icons.error_outline_rounded : Icons.system_update_rounded,
          size: 36,
          color: failed ? scheme.error : scheme.primary,
        ),
        title: Text(tr('Навсозӣ то {version}', {'version': version})),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(p.label, textAlign: TextAlign.center),
            if (!finished) ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: p.state == 'downloading' ? p.progress : null,
                minHeight: 6,
                borderRadius: BorderRadius.circular(6),
              ),
              const SizedBox(height: 12),
              Text(
                tr('Маълумот, воридшавӣ ва иҷозатҳо нигоҳ дошта мешаванд.'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (finished || p.state == 'installing')
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(failed ? tr('Пӯшидан') : tr('Хуб')),
            ),
        ],
      );
    },
  );
}
