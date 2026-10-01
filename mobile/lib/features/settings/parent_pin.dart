import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/user_journey_logic.dart';

/// Parent PIN stored natively on this phone (`tj.nigoh/device_control`).
abstract final class ParentPin {
  static const channel = MethodChannel('tj.nigoh/device_control');

  static Future<bool> isSet() async =>
      await channel.invokeMethod<bool>('getLocalPinStatus') ?? false;

  static Future<bool> verify(String pin) async =>
      UserJourneyLogic.validPin(pin) &&
      (await channel.invokeMethod<bool>('verifyLocalPin', {'pin': pin}) ??
          false);

  /// Returns null on success, otherwise a message for the user.
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
        ? 'Рамзи ҷорӣ нодуруст аст.'
        : 'Рамз нигоҳ дошта нашуд. Дубора кӯшиш кунед.';
  }

  /// Asks for the PIN in a dialog; true when it was correct.
  static Future<bool> ask(
    BuildContext context, {
    String title = 'PIN-и волидайн',
    String? text,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _PinDialog(title: title, text: text),
    );
    return ok == true;
  }
}

class _PinDialog extends StatefulWidget {
  const _PinDialog({required this.title, this.text});
  final String title;
  final String? text;

  @override
  State<_PinDialog> createState() => _PinDialogState();
}

class _PinDialogState extends State<_PinDialog> {
  final pin = TextEditingController();
  String? error;
  bool busy = false;

  @override
  void dispose() {
    pin.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final ok = await ParentPin.verify(pin.text.trim());
      if (!mounted) return;
      if (ok) return Navigator.pop(context, true);
      setState(() => error = 'PIN нодуруст аст.');
    } on PlatformException catch (e) {
      if (mounted) setState(() => error = e.message ?? 'PIN санҷида нашуд.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

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
            labelText: 'PIN (4 рақам)',
            counterText: '',
            errorText: error,
          ),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: busy ? null : () => Navigator.pop(context, false),
        child: const Text('Бекор'),
      ),
      FilledButton(
        style: FilledButton.styleFrom(minimumSize: const Size(110, 44)),
        onPressed: busy ? null : submit,
        child: const Text('Тасдиқ'),
      ),
    ],
  );
}
