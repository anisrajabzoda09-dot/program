// Файл: сохтан ва санҷидани PIN-и волид.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/user_journey_logic.dart';
import '../../l10n/l10n.dart';

/// PIN-и волидайнро тавассути channel-и муҳофизати Android идора мекунад.
abstract final class ParentPin {
  static const channel = MethodChannel('tj.nigoh/device_control');

  /// isSet иҷро шудани шарти вобастаро муайян мекунад.
  static Future<bool> isSet() async =>
      await channel.invokeMethod<bool>('getLocalPinStatus') ?? false;

  /// verify дурустӣ ва шартҳои зарурии додаҳоро месанҷад.
  static Future<bool> verify(String pin) async {
    if (!UserJourneyLogic.validPin(pin)) return false;
    return await channel.invokeMethod<bool>('verifyLocalPin', {'pin': pin}) ??
        false;
  }

  /// change ҳолатро тағйир дода, интерфейс ё server-ро нав мекунад.
  static Future<String?> change({
    required String currentPin,
    required String newPin,
  }) async {
    final result = await channel.invokeMapMethod<String, dynamic>(
      'setLocalPin',
      {'currentPin': currentPin, 'newPin': newPin},
    );
    if (result?['ok'] == true) return null;
    return result?['error'] == 'wrong_current_pin'
        ? tr('Рамзи ҷорӣ нодуруст аст.')
        : tr('Рамз нигоҳ дошта нашуд. Дубора кӯшиш кунед.');
  }

  /// setUp ҳолатро тағйир дода, интерфейс ё server-ро нав мекунад.
  static Future<bool> setUp(
    BuildContext context, {
    bool hasPin = false,
    String? text,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => PinSetupDialog(hasPin: hasPin, text: text),
    );
    return ok == true;
  }

  /// ask иҷозат ё маълумоти лозимро дархост мекунад.
  static Future<bool> ask(
    BuildContext context, {
    String? title,
    String? text,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) =>
          _PinDialog(title: title ?? tr('PIN-и волидайн'), text: text),
    );
    return ok == true;
  }
}

/// Равзанаи PinDialog-ро барои сохтан ва санҷидани PIN-и волид нишон медиҳад.
class _PinDialog extends StatefulWidget {
  const _PinDialog({required this.title, this.text});
  final String title;
  final String? text;

  /// Ҳолати PinDialog-ро барои санҷиш ва гузоштани PIN-и волидайн месозад.
  @override
  State<_PinDialog> createState() => _PinDialogState();
}

/// Ҳолат ва рафтори PinDialogState-ро барои навсозии интерфейс идора мекунад.
class _PinDialogState extends State<_PinDialog> {
  final pin = TextEditingController();
  String? error;
  bool busy = false;

  /// Controller ва listener-ҳои PinDialog-ро озод мекунад.
  @override
  void dispose() {
    pin.dispose();
    super.dispose();
  }

  /// submit дархости PIN-и волидайн-ро ба API мефиристад ва натиҷаро коркард мекунад.
  Future<void> submit() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final ok = await ParentPin.verify(pin.text.trim());
      if (!mounted) return;
      if (ok) return Navigator.pop(context, true);
      setState(() => error = tr('PIN нодуруст аст.'));
    } on PlatformException catch (e) {
      if (mounted) {
        setState(() => error = e.message ?? tr('PIN санҷида нашуд.'));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  /// Widget-и PinDialog-ро барои санҷиш ва гузоштани PIN-и волидайн месозад.
  @override
  Widget build(BuildContext context) => AlertDialog(
    icon: const Icon(Icons.lock_outline_rounded),
    title: Text(widget.title),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.text != null) ...[
          Text(widget.text!),
          const SizedBox(height: 14),
        ],
        TextField(
          controller: pin,
          autofocus: true,
          obscureText: true,
          maxLength: 4,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onSubmitted: (_) => submit(),
          decoration: InputDecoration(
            labelText: tr('PIN (4 рақам)'),
            counterText: '',
            errorText: error,
          ),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: busy ? null : () => Navigator.pop(context, false),
        child: Text(tr('Бекор')),
      ),
      FilledButton(
        style: FilledButton.styleFrom(minimumSize: const Size(110, 44)),
        onPressed: busy ? null : submit,
        child: Text(tr('Тасдиқ')),
      ),
    ],
  );
}

/// Равзанаи PinSetupDialog-ро барои сохтан ва санҷидани PIN-и волид нишон медиҳад.
class PinSetupDialog extends StatefulWidget {
  const PinSetupDialog({super.key, required this.hasPin, this.text});
  final bool hasPin;

  /// Қимати text-ро барои сохтан ва санҷидани PIN-и волид нигоҳ медорад.
  final String? text;

  /// Ҳолати PinSetupDialog-ро барои санҷиш ва гузоштани PIN-и волидайн месозад.
  @override
  State<PinSetupDialog> createState() => _PinSetupDialogState();
}

/// Ҳолат ва рафтори PinSetupDialogState-ро барои навсозии интерфейс идора мекунад.
class _PinSetupDialogState extends State<PinSetupDialog> {
  final current = TextEditingController();
  final next = TextEditingController();
  final confirm = TextEditingController();
  String? error;
  bool saving = false;

  /// Controller ва listener-ҳои PinSetupDialog-ро озод мекунад.
  @override
  void dispose() {
    current.dispose();
    next.dispose();
    confirm.dispose();
    super.dispose();
  }

  /// save тағйироти PIN-и волидайн-ро барои истифодаи баъдӣ нигоҳ медорад.
  Future<void> save() async {
    final newPin = next.text.trim();
    if (!UserJourneyLogic.validPin(newPin)) {
      return setState(() => error = tr('PIN бояд аз 4 рақам иборат бошад.'));
    }
    if (newPin != confirm.text.trim()) {
      return setState(() => error = tr('Такрори PIN мувофиқ нест.'));
    }
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final failure = await ParentPin.change(
        currentPin: widget.hasPin ? current.text.trim() : '',
        newPin: newPin,
      );
      if (!mounted) return;
      if (failure == null) return Navigator.pop(context, true);
      setState(() => error = failure);
    } on PlatformException catch (e) {
      if (mounted) {
        setState(() => error = e.message ?? tr('PIN нигоҳ дошта нашуд.'));
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  /// field мантиқи зарурии сохтан ва санҷидани PIN-и волидро иҷро мекунад.
  Widget field(
    TextEditingController controller,
    String label, {
    bool focus = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextField(
      controller: controller,
      autofocus: focus,
      obscureText: true,
      maxLength: 4,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(labelText: label, counterText: ''),
    ),
  );

  /// Widget-и PinSetupDialog-ро барои санҷиш ва гузоштани PIN-и волидайн месозад.
  @override
  Widget build(BuildContext context) => AlertDialog(
    icon: const Icon(Icons.pin_outlined),
    title: Text(widget.hasPin ? tr('Иваз кардани PIN') : tr('Гузоштани PIN')),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.text ??
                tr(
                  'PIN дар ҳамин телефон нигоҳ дошта мешавад ва барои амалҳои муҳим лозим аст.',
                ),
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          if (widget.hasPin) field(current, tr('PIN-и ҷорӣ'), focus: true),
          field(
            next,
            widget.hasPin ? tr('PIN-и нав') : tr('PIN (4 рақам)'),
            focus: !widget.hasPin,
          ),
          field(confirm, tr('Такрори PIN')),
          if (error != null)
            Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: saving ? null : () => Navigator.pop(context, false),
        child: Text(tr('Бекор')),
      ),
      FilledButton(
        style: FilledButton.styleFrom(minimumSize: const Size(110, 44)),
        onPressed: saving ? null : save,
        child: Text(tr('Нигоҳ доштан')),
      ),
    ],
  );
}
