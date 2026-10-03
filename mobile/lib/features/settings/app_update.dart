// Файл: санҷиш, зеркашӣ ва насби навсозии Android.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/api.dart';
import '../../core/user_journey_logic.dart';
import '../../ui/widgets.dart';
import '../../l10n/l10n.dart';

/// Ин қадам ҷавоби server ё хатои API-ро коркард мекунад.
abstract final class AppUpdate {
  static const channel = MethodChannel('tj.nigoh/update');

  /// Қимати lastError-ро барои санҷиш, зеркашӣ ва насби навсозии Android нигоҳ медорад.
  static final lastError = ValueNotifier<String?>(null);

  /// installedCode мантиқи зарурии санҷиш, зеркашӣ ва насби навсозии Android-ро иҷро мекунад.
  static Future<int> installedCode() async =>
      int.tryParse((await PackageInfo.fromPlatform()).buildNumber) ?? 0;

  /// check дурустӣ ва шартҳои зарурии додаҳоро месанҷад.
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

  static const progressChannel = EventChannel('tj.nigoh/update_progress');

  /// install мантиқи зарурии санҷиш, зеркашӣ ва насби навсозии Android-ро иҷро мекунад.
  static Future<void> install(
    BuildContext context,
    String url,
    String version,
  ) async {
    // Боргирӣ ва насби APK танҳо дар Android дастгирӣ мешавад.
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
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
      // Қадами дохилии санҷиш, зеркашӣ ва насби навсозии Android.
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

/// Додаҳо ва рафтори марбут ба санҷиш, зеркашӣ ва насби навсозии Android-ро ифода мекунад.
class UpdateProgress {
  const UpdateProgress(this.state, {this.progress, this.message});

  /// Қимати state-ро барои санҷиш, зеркашӣ ва насби навсозии Android нигоҳ медорад.
  final String state;
  final double? progress;
  final String? message;

  /// UpdateProgress-ро аз event-и пешрафти Android месозад.
  factory UpdateProgress.fromEvent(Object? raw) {
    if (raw is! Map) return const UpdateProgress('error');
    return UpdateProgress(
      raw['state']?.toString() ?? 'error',
      progress: (raw['progress'] as num?)?.toDouble(),
      message: raw['message']?.toString(),
    );
  }

  /// Қимати label-ро барои санҷиш, зеркашӣ ва насби навсозии Android нигоҳ медорад.
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

/// Равзанаи UpdateProgressDialog-ро барои санҷиш, зеркашӣ ва насби навсозии Android нишон медиҳад.
class UpdateProgressDialog extends StatelessWidget {
  const UpdateProgressDialog({
    super.key,
    required this.version,
    required this.events,
  });

  final String version;
  final Stream<UpdateProgress> events;

  /// Widget-и UpdateProgressDialog-ро барои боргирӣ ва насби навсозӣ месозад.
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
