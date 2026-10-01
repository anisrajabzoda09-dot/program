import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/api.dart';
import '../../core/user_journey_logic.dart';
import '../../ui/widgets.dart';

/// Checks `/api/mobile/version` and offers the in-app APK update
/// (native `tj.nigoh/update` → installUpdate).
abstract final class AppUpdate {
  static const channel = MethodChannel('tj.nigoh/update');

  /// Last error of the automatic (silent) check, for a visible status.
  static final lastError = ValueNotifier<String?>(null);

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
      final text = e is ApiException ? e.message : 'Навсозӣ санҷида нашуд.';
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
      if (!silent) showMessage(context, 'Шумо версияи охиринро доред.');
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
              ? 'Версияи нав бо беҳбудиҳо дастрас аст.'
              : notes,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Баъдтар'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size(130, 44)),
            onPressed: () {
              Navigator.pop(dialogContext);
              install(context, url, version);
            },
            icon: const Icon(Icons.download_rounded),
            label: const Text('Навсозӣ'),
          ),
        ],
      ),
    );
  }

  static Future<void> install(
    BuildContext context,
    String url,
    String version,
  ) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) {
      showMessage(context, 'Пайванди навсозӣ дастрас нест.', error: true);
      return;
    }
    try {
      final status = await channel.invokeMethod<String>('installUpdate', {
        'downloadUrl': url,
        'version': version,
      });
      if (!context.mounted) return;
      showMessage(
        context,
        status == 'download_started'
            ? 'Навсозӣ зеркашӣ мешавад. Баъд равзанаи насб худкор кушода мешавад.'
            : status == 'install_permission_required'
            ? 'Иҷозати «Install unknown apps»-ро фаъол кунед ва ба NIGOH баргардед.'
            : 'Навсозӣ омода мешавад.',
      );
    } catch (_) {
      if (context.mounted) {
        showMessage(
          context,
          'Зеркашии навсозӣ оғоз нашуд. Интернетро санҷед.',
          error: true,
        );
      }
    }
  }
}
