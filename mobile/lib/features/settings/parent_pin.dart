import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/platform.dart';
import '../../core/user_journey_logic.dart';
import '../../l10n/l10n.dart';

/// Parent PIN stored on this device: natively on Android
/// (`tj.nigoh/device_control`), as a salted hash in shared preferences on the
/// desktop app (no Android channel there).
abstract final class ParentPin {
  static const channel = MethodChannel('tj.nigoh/device_control');

  static Future<bool> isSet() async => isDesktop
      ? DesktopPinStore.isSet()
      : await channel.invokeMethod<bool>('getLocalPinStatus') ?? false;

  static Future<bool> verify(String pin) async {
    if (!UserJourneyLogic.validPin(pin)) return false;
    if (isDesktop) return DesktopPinStore.verify(pin);
    return await channel.invokeMethod<bool>('verifyLocalPin', {'pin': pin}) ??
        false;
  }

  /// Returns null on success, otherwise a message for the user.
  static Future<String?> change({
    required String currentPin,
    required String newPin,
  }) async {
    final result = isDesktop
        ? await DesktopPinStore.change(currentPin: currentPin, newPin: newPin)
        : await channel.invokeMapMethod<String, dynamic>('setLocalPin', {
            'currentPin': currentPin,
            'newPin': newPin,
          });
    if (result?['ok'] == true) return null;
    return result?['error'] == 'wrong_current_pin'
        ? tr('Рамзи ҷорӣ нодуруст аст.')
        : tr('Рамз нигоҳ дошта нашуд. Дубора кӯшиш кунед.');
  }

  /// Opens [PinSetupDialog] to create a PIN (or change it when [hasPin]);
  /// true when a new PIN was saved.
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

  /// Asks for the PIN in a dialog; true when it was correct.
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
      setState(() => error = tr('PIN нодуруст аст.'));
    } on PlatformException catch (e) {
      if (mounted) {
        setState(() => error = e.message ?? tr('PIN санҷида нашуд.'));
      }
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

/// Set (first time) or change the parent PIN — legacy SecurityCodePage flow.
class PinSetupDialog extends StatefulWidget {
  const PinSetupDialog({super.key, required this.hasPin, this.text});
  final bool hasPin;

  /// Optional reason shown above the fields (e.g. why a PIN is needed now).
  final String? text;

  @override
  State<PinSetupDialog> createState() => _PinSetupDialogState();
}

class _PinSetupDialogState extends State<PinSetupDialog> {
  final current = TextEditingController();
  final next = TextEditingController();
  final confirm = TextEditingController();
  String? error;
  bool saving = false;

  @override
  void dispose() {
    current.dispose();
    next.dispose();
    confirm.dispose();
    super.dispose();
  }

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

/// Desktop parent PIN: `salt:sha256(salt + pin)` in shared preferences.
abstract final class DesktopPinStore {
  static const key = 'nigoh.desktop_pin';

  static Future<bool> isSet() async =>
      (await SharedPreferences.getInstance()).getString(key) != null;

  static String _hash(String salt, String pin) =>
      sha256.convert(utf8.encode('$salt:$pin')).toString();

  static Future<bool> verify(String pin) async {
    final stored = (await SharedPreferences.getInstance()).getString(key);
    if (stored == null) return false;
    final parts = stored.split(':');
    return parts.length == 2 && _hash(parts[0], pin) == parts[1];
  }

  /// Same result shape as the native `setLocalPin`.
  static Future<Map<String, dynamic>> change({
    required String currentPin,
    required String newPin,
  }) async {
    if (!UserJourneyLogic.validPin(newPin)) return {'ok': false};
    if (await isSet() && !await verify(currentPin)) {
      return {'ok': false, 'error': 'wrong_current_pin'};
    }
    final random = Random.secure();
    final salt = base64Url.encode(
      List<int>.generate(16, (_) => random.nextInt(256)),
    );
    final saved = await (await SharedPreferences.getInstance()).setString(
      key,
      '$salt:${_hash(salt, newPin)}',
    );
    return {'ok': saved};
  }
}
