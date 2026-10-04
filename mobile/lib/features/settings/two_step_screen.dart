// Файл: экрани «Ҳимояи дуқабата» — фаъол кардани Authenticator бо QR, рамзҳои эҳтиётӣ ва хомӯш кардан.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/api.dart';
import '../../l10n/l10n.dart';
import '../../ui/nigoh_design.dart';
import '../../ui/widgets.dart';

/// Экрани ҳимояи дуқабата барои ҳисоби ҷорӣ.
class TwoStepScreen extends StatefulWidget {
  const TwoStepScreen({super.key, required this.api});

  final NigohApi api;

  /// Ҳолати TwoStepScreen-ро месозад.
  @override
  State<TwoStepScreen> createState() => _TwoStepScreenState();
}

/// Ҳолатҳо: бор шудан, хомӯш, танзим (QR), рамзҳои эҳтиётӣ, фаъол.
class _TwoStepScreenState extends State<TwoStepScreen> {
  Map<String, dynamic>? status;
  Map<String, dynamic>? setup;
  List<String>? recoveryCodes;
  Object? loadError;
  bool busy = false;
  final code = TextEditingController();

  /// Ҳолатро аз сервер мегирад.
  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Майдонро озод мекунад.
  @override
  void dispose() {
    code.dispose();
    super.dispose();
  }

  /// Ҳолати Authenticator-ро аз сервер мехонад.
  Future<void> _load() async {
    setState(() => loadError = null);
    try {
      final s = await widget.api.totpStatus();
      if (mounted) setState(() => status = s);
    } catch (e) {
      if (mounted) setState(() => loadError = e);
    }
  }

  /// Амали серверро бо ҳолати «интизор» ва нишон додани хато иҷро мекунад.
  Future<void> _run(Future<void> Function() action) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) showMessage(context, e, error: true);
      code.clear();
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  /// Калиди навро мегирад ва QR-ро нишон медиҳад.
  Future<void> _start() => _run(() async {
    final s = await widget.api.totpSetup();
    setState(() => setup = s);
  });

  /// Аввалин рамзро месанҷад ва рамзҳои эҳтиётиро нишон медиҳад.
  Future<void> _confirm() => _run(() async {
    final r = await widget.api.totpConfirm(code.text.trim());
    code.clear();
    setState(() {
      setup = null;
      status = r;
      recoveryCodes = _codes(r);
    });
  });

  /// Бо рамз хомӯш мекунад.
  Future<void> _disable() => _run(() async {
    final r = await widget.api.totpDisable(code.text.trim());
    code.clear();
    setState(() => status = r);
    if (mounted) showMessage(context, tr('Ҳимояи дуқабата хомӯш шуд'));
  });

  /// Рамзҳои эҳтиётии нав месозад.
  Future<void> _regenerate() => _run(() async {
    final r = await widget.api.totpRecovery(code.text.trim());
    code.clear();
    setState(() {
      status = r;
      recoveryCodes = _codes(r);
    });
  });

  /// Рӯйхати рамзҳоро аз ҷавоби сервер ҷудо мекунад.
  static List<String> _codes(Map<String, dynamic> r) =>
      (r['recovery_codes'] as List? ?? const [])
          .map((c) => c.toString())
          .toList();

  /// Экранро вобаста ба ҳолат месозад.
  @override
  Widget build(BuildContext context) {
    final s = status;
    return Scaffold(
      appBar: AppBar(title: Text(tr('Ҳимояи дуқабата'))),
      body: SafeArea(
        child: loadError != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('$loadError', textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _load,
                        child: Text(tr('Аз нав кӯшиш')),
                      ),
                    ],
                  ),
                ),
              )
            : s == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _StatusCard(
                    enabled: s['enabled'] == true,
                    left: (s['recovery_left'] as num?)?.toInt() ?? 0,
                  ),
                  const SizedBox(height: 16),
                  if (recoveryCodes != null)
                    _RecoveryCodes(
                      codes: recoveryCodes!,
                      onDone: () => setState(() => recoveryCodes = null),
                    )
                  else if (s['available'] != true)
                    Text(tr('Ин имконият дар сервер ҳоло танзим нашудааст.'))
                  else if (setup != null)
                    _SetupView(
                      setup: setup!,
                      code: code,
                      busy: busy,
                      onConfirm: _confirm,
                    )
                  else if (s['enabled'] != true)
                    _OffView(busy: busy, onStart: _start)
                  else
                    _OnView(
                      code: code,
                      busy: busy,
                      onDisable: _disable,
                      onRegenerate: _regenerate,
                    ),
                  const SizedBox(height: 20),
                  Text(
                    tr(
                      'Пас аз 5 рамзи нодуруст ҳисоб 15 дақиқа қулф мешавад. Ҳар рамз танҳо як бор ва 30 сония эътибор дорад.',
                    ),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Корти ҳолат: фаъол ё хомӯш ва чанд рамзи эҳтиётӣ боқист.
class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.enabled, required this.left});

  final bool enabled;
  final int left;

  /// Кортро бо ранги ҳолат месозад.
  @override
  Widget build(BuildContext context) {
    final color = enabled ? NigohDesign.mint : NigohDesign.amber;
    return Container(
      key: const ValueKey('two-step-status'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            enabled ? Icons.verified_user_rounded : Icons.shield_outlined,
            color: color,
            size: 32,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  enabled
                      ? tr('Ҳимояи дуқабата фаъол аст')
                      : tr('Ҳимояи дуқабата хомӯш аст'),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                if (enabled)
                  Text(tr('Рамзҳои эҳтиётии боқимонда: {n}', {'n': left})),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Ҳолати хомӯш: шарҳ ва тугмаи «Фаъол кардан».
class _OffView extends StatelessWidget {
  const _OffView({required this.busy, required this.onStart});

  final bool busy;
  final VoidCallback onStart;

  /// Шарҳ ва тугмаро месозад.
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        tr(
          'Ҳатто агар касе пароли шуморо донад, бе рамзи 6-рақамаи телефони шумо ворид шуда наметавонад. Барномаи Google Authenticator ё Microsoft Authenticator лозим аст.',
        ),
      ),
      const SizedBox(height: 16),
      FilledButton.icon(
        key: const ValueKey('two-step-start'),
        onPressed: busy ? null : onStart,
        icon: const Icon(Icons.qr_code_2_rounded),
        label: Text(tr('Фаъол кардан')),
      ),
    ],
  );
}

/// Танзим: QR, калиди дастӣ ва майдони рамз.
class _SetupView extends StatelessWidget {
  const _SetupView({
    required this.setup,
    required this.code,
    required this.busy,
    required this.onConfirm,
  });

  final Map<String, dynamic> setup;
  final TextEditingController code;
  final bool busy;
  final VoidCallback onConfirm;

  /// QR-ро дар заминаи сафед (барои скан дар режими торик) нишон медиҳад.
  @override
  Widget build(BuildContext context) {
    final secret = setup['secret']?.toString() ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          tr('1. Ин рамзи QR-ро дар барномаи Authenticator скан кунед'),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        Center(
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: QrImageView(
              key: const ValueKey('two-step-qr'),
              data: setup['uri']?.toString() ?? '',
              size: 200,
              backgroundColor: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(tr('Ё калидро дастӣ ворид кунед:'), textAlign: TextAlign.center),
        SelectableText(
          secret.replaceAllMapped(RegExp(r'.{4}'), (m) => '${m[0]} ').trim(),
          key: const ValueKey('two-step-secret'),
          textAlign: TextAlign.center,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 15),
        ),
        const SizedBox(height: 16),
        Text(
          tr('2. Рамзи 6-рақамаро аз барнома нависед'),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        TextField(
          key: const ValueKey('two-step-code'),
          controller: code,
          keyboardType: TextInputType.number,
          maxLength: 6,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 24, letterSpacing: 6),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(counterText: ''),
          onSubmitted: (_) => onConfirm(),
        ),
        const SizedBox(height: 12),
        FilledButton(
          key: const ValueKey('two-step-confirm'),
          onPressed: busy ? null : onConfirm,
          child: Text(tr('Тасдиқ')),
        ),
      ],
    );
  }
}

/// Ҳолати фаъол: хомӯш кардан ё рамзҳои эҳтиётии нав (ҳарду бо рамз).
class _OnView extends StatelessWidget {
  const _OnView({
    required this.code,
    required this.busy,
    required this.onDisable,
    required this.onRegenerate,
  });

  final TextEditingController code;
  final bool busy;
  final VoidCallback onDisable;
  final VoidCallback onRegenerate;

  /// Майдони рамз ва ду тугмаро месозад.
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(tr('Рамзи ҷорӣ ё рамзи эҳтиётиро ворид кунед.')),
      const SizedBox(height: 8),
      TextField(
        key: const ValueKey('two-step-code'),
        controller: code,
        maxLength: 9,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 22, letterSpacing: 4),
        decoration: const InputDecoration(counterText: ''),
      ),
      const SizedBox(height: 12),
      OutlinedButton(
        key: const ValueKey('two-step-recovery'),
        onPressed: busy ? null : onRegenerate,
        child: Text(tr('Рамзҳои эҳтиётии нав')),
      ),
      const SizedBox(height: 8),
      FilledButton.tonal(
        key: const ValueKey('two-step-disable'),
        onPressed: busy ? null : onDisable,
        child: Text(tr('Хомӯш кардан')),
      ),
    ],
  );
}

/// Рамзҳои эҳтиётӣ — танҳо як бор нишон дода мешаванд; нусха гирифтан мумкин аст.
class _RecoveryCodes extends StatelessWidget {
  const _RecoveryCodes({required this.codes, required this.onDone});

  final List<String> codes;
  final VoidCallback onDone;

  /// Рӯйхати рамзҳо ва тугмаҳои «Нусха» ва «Тайёр»-ро месозад.
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          tr('Рамзҳои эҳтиётиро нигоҳ доред'),
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
        const SizedBox(height: 6),
        Text(
          tr(
            'Агар телефонро гум кунед, бо яке аз ин рамзҳо ворид шуда метавонед. Ҳар рамз танҳо як бор кор мекунад. Онҳо дигар нишон дода намешаванд.',
          ),
          style: TextStyle(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final c in codes)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  c,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 16),
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          key: const ValueKey('two-step-copy'),
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: codes.join('\n')));
            if (context.mounted) showMessage(context, tr('Нусха гирифта шуд'));
          },
          icon: const Icon(Icons.copy_rounded),
          label: Text(tr('Нусха гирифтан')),
        ),
        const SizedBox(height: 8),
        FilledButton(
          key: const ValueKey('two-step-done'),
          onPressed: onDone,
          child: Text(tr('Тайёр')),
        ),
      ],
    );
  }
}
