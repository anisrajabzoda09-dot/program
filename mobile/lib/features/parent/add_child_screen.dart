import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/user_journey_logic.dart';
import '../../ui/nigoh_design.dart';
import '../../ui/widgets.dart';
import 'family_controller.dart';
import '../../l10n/l10n.dart';

/// Pair a child's phone: scan its QR or type the 6-digit code.
/// Pops with `true` after a successful pairing.
class AddChildScreen extends StatefulWidget {
  const AddChildScreen({super.key, required this.controller});
  final FamilyController controller;

  @override
  State<AddChildScreen> createState() => _AddChildScreenState();
}

class _AddChildScreenState extends State<AddChildScreen> {
  final _code = TextEditingController();
  bool _scanning = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  /// QR payloads may be the bare code or a link/JSON that contains it.
  static String extractCode(String raw) {
    final direct = UserJourneyLogic.pairingCode(raw);
    if (direct.isNotEmpty) return direct;
    final match = RegExp(r'(?<!\d)\d{6}(?!\d)').firstMatch(raw);
    return match?.group(0) ?? '';
  }

  Future<void> _submit(String raw) async {
    if (_busy) return;
    final code = extractCode(raw);
    if (code.isEmpty) {
      setState(() => _error = tr('Код бояд 6 рақам бошад.'));
      return;
    }
    setState(() {
      _busy = true;
      _scanning = false;
      _error = null;
    });
    try {
      await widget.controller.pair(code);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
      showMessage(context, e, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(tr('Илова кардани фарзанд'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _Step(
            number: 1,
            color: NigohDesign.blue,
            title: tr('NIGOH Family-ро дар телефони фарзанд насб кунед'),
            text: tr('Ворид шавед ва «Фарзанд»-ро интихоб кунед.'),
          ),
          _Step(
            number: 2,
            color: NigohDesign.violet,
            title: tr('Ном ва синни фарзандро нависед'),
            text: tr('Дар экран QR ва коди 6-рақама пайдо мешавад.'),
          ),
          _Step(
            number: 3,
            color: NigohDesign.mint,
            title: tr('QR-ро скан кунед ё кодро ворид кунед'),
            text: tr(
              'Пас аз пайваст ҳамаи иҷозатҳоро дар телефони фарзанд диҳед.',
            ),
          ),
          const SizedBox(height: 12),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: _scanning
                ? ClipRRect(
                    key: const ValueKey('scanner'),
                    borderRadius: BorderRadius.circular(20),
                    child: SizedBox(
                      height: 280,
                      child: Stack(
                        children: [
                          MobileScanner(
                            onDetect: (capture) {
                              final value =
                                  capture.barcodes.firstOrNull?.rawValue;
                              if (value != null && !_busy) _submit(value);
                            },
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: IconButton.filledTonal(
                              tooltip: tr('Пӯшидан'),
                              onPressed: () =>
                                  setState(() => _scanning = false),
                              icon: const Icon(Icons.close_rounded),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : SizedBox(
                    key: const ValueKey('scan-button'),
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(54),
                      ),
                      onPressed: _busy
                          ? null
                          : () => setState(() => _scanning = true),
                      icon: const Icon(Icons.qr_code_scanner_rounded),
                      label: Text(tr('Скан кардани QR')),
                    ),
                  ),
          ),
          const SizedBox(height: 22),
          Text(
            tr('Ё кодро дастӣ ворид кунед'),
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _code,
            keyboardType: TextInputType.number,
            maxLength: 6,
            textAlign: TextAlign.center,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(
              fontSize: 26,
              letterSpacing: 10,
              fontWeight: FontWeight.w700,
            ),
            decoration: InputDecoration(
              hintText: '000000',
              counterText: '',
              errorText: _error,
              errorMaxLines: 3,
            ),
            onSubmitted: _submit,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
              onPressed: _busy ? null : () => _submit(_code.text),
              child: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(tr('Пайваст кардан')),
            ),
          ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.number,
    required this.color,
    required this.title,
    required this.text,
  });

  final int number;
  final Color color;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Text(
            '$number',
            style: TextStyle(color: color, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(
                text,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
