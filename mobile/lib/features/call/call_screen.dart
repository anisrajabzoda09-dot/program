import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api.dart';
import '../../core/platform.dart';
import '../../core/session.dart';
import 'call_controller.dart';
import 'rtc_engine.dart';
import '../../l10n/l10n.dart';

/// Full-screen voice call (Telegram-like). Always dark, whatever the app theme.
class CallScreen extends StatefulWidget {
  const CallScreen({
    super.key,
    required this.controller,
    required this.peerName,
    this.peerAvatarUrl,
    this.closeDelay = const Duration(milliseconds: 1500),
  });

  final CallController controller;
  final String peerName;

  /// Absolute URL of the other side's photo (letter shown if null/failing).
  final String? peerAvatarUrl;

  /// How long the end reason stays visible before the screen closes.
  final Duration closeDelay;

  /// Overridable for tests (no real WebRTC / permission plugin there).
  static RtcEngine Function() engineFactory = FlutterRtcEngine.new;
  static Future<bool> Function() micPermission = requestMicrophonePermission;

  static bool _open = false;

  /// True while a call screen is shown (prevents two calls at once).
  static bool get isOpen => _open;

  static CallController _controller(NigohApi api) => CallController(
    api: api,
    engine: engineFactory(),
    micPermission: micPermission,
  );

  /// Calls [childId]'s other side (parent → child, child → parent).
  static Future<void> openOutgoing(
    BuildContext context, {
    required int childId,
    required String peerName,
    String? peerAvatarUrl,
  }) async {
    if (_open) return;
    final api = SessionScope.read(context).api;
    final controller = _controller(api);
    unawaited(controller.startOutgoing(childId));
    await _push(
      Navigator.of(context),
      controller,
      peerName,
      peerAvatarUrl: peerAvatarUrl,
    );
  }

  /// Shows an incoming call; with [acceptNow] it is answered immediately
  /// (the user already tapped «Қабул» in the notification).
  static Future<void> openIncoming(
    NavigatorState navigator, {
    required int callId,
    required int childId,
    required String peerName,
    bool acceptNow = false,
  }) async {
    if (_open) return;
    final api = SessionScope.read(navigator.context).api;
    final controller = _controller(api)..startIncoming(callId);
    if (acceptNow) unawaited(controller.accept());
    await _push(navigator, controller, peerName);
  }

  static Future<void> _push(
    NavigatorState navigator,
    CallController controller,
    String peerName, {
    String? peerAvatarUrl,
  }) async {
    _open = true;
    try {
      await navigator.push(
        PageRouteBuilder<void>(
          transitionDuration: const Duration(milliseconds: 250),
          pageBuilder: (_, _, _) => CallScreen(
            controller: controller,
            peerName: peerName,
            peerAvatarUrl: peerAvatarUrl,
          ),
          transitionsBuilder: (_, animation, _, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      );
    } finally {
      _open = false;
    }
  }

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );
  Timer? _closeTimer;

  CallController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    _c.addListener(_onChange);
    _sync();
  }

  void _onChange() {
    _sync();
    if (mounted) setState(() {});
  }

  void _sync() {
    final ringing =
        _c.state == CallState.outgoing ||
        _c.state == CallState.incoming ||
        _c.state == CallState.connecting;
    if (ringing && !_pulse.isAnimating) {
      _pulse.repeat();
    } else if (!ringing && _pulse.isAnimating) {
      _pulse.stop();
    }
    if (_c.ended && _closeTimer == null) {
      _closeTimer = Timer(widget.closeDelay, () {
        if (mounted) Navigator.of(context).maybePop();
      });
    }
  }

  @override
  void dispose() {
    _c.removeListener(_onChange);
    _closeTimer?.cancel();
    _pulse.dispose();
    _c.dispose(); // hangs up if still running — never leaves the mic open
    super.dispose();
  }

  String get _status => switch (_c.state) {
    CallState.idle || CallState.outgoing => tr('Занг задан…'),
    CallState.incoming => tr('Занги даромада'),
    CallState.connecting => tr('Пайвастшавӣ…'),
    CallState.active => formatCallDuration(_c.duration),
    CallState.ended => _c.endMessage ?? tr('Занг тамом шуд'),
  };

  bool get _endIsProblem =>
      _c.ended &&
      _c.endReason != CallEndReason.hangup &&
      _c.endReason != CallEndReason.remoteEnded;

  @override
  Widget build(BuildContext context) {
    final name = widget.peerName.trim();
    final letter = name.isEmpty ? '?' : name.characters.first.toUpperCase();
    return PopScope(
      canPop: _c.ended,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _c.hangUp();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Theme(
          data: ThemeData(
            brightness: Brightness.dark,
            useMaterial3: true,
            colorSchemeSeed: const Color(0xFF2F6BFF),
          ),
          child: Scaffold(
            backgroundColor: const Color(0xFF05070D),
            body: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF1B3A6B),
                    Color(0xFF0E1A33),
                    Color(0xFF05070D),
                  ],
                  stops: [0, 0.55, 1],
                ),
              ),
              child: SafeArea(
                child: LayoutBuilder(
                  builder: (context, box) => SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: box.maxHeight),
                      child: IntrinsicHeight(child: _content(name, letter)),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _content(String name, String letter) => Column(
    children: [
      const SizedBox(height: 48),
      _Avatar(letter: letter, url: widget.peerAvatarUrl, pulse: _pulse),
      const SizedBox(height: 24),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Text(
          name.isEmpty ? tr('Занг') : name,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      const SizedBox(height: 10),
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: Text(
          _status,
          key: ValueKey(_c.state == CallState.active ? 'active' : _status),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _endIsProblem ? const Color(0xFFFF8A80) : Colors.white70,
            fontSize: 16,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
      const Spacer(),
      const SizedBox(height: 32),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
        child: _controls(),
      ),
    ],
  );

  Widget _controls() {
    if (_c.state == CallState.incoming) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _RoundButton(
            icon: Icons.call_end_rounded,
            label: tr('Рад'),
            color: const Color(0xFFE53935),
            onTap: _c.decline,
          ),
          _RoundButton(
            icon: Icons.call_rounded,
            label: tr('Қабул'),
            color: const Color(0xFF2EB872),
            onTap: _c.accept,
          ),
        ],
      );
    }
    final ended = _c.ended;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Desktop plays through the computer's speakers/headset anyway.
        if (!isDesktop)
          _RoundButton(
            icon: _c.speaker
                ? Icons.volume_up_rounded
                : Icons.volume_down_rounded,
            label: tr('Динамик'),
            active: _c.speaker,
            onTap: ended ? null : _c.toggleSpeaker,
          ),
        _RoundButton(
          icon: _c.muted ? Icons.mic_off_rounded : Icons.mic_rounded,
          label: tr('Микрофон'),
          active: _c.muted,
          onTap: ended ? null : _c.toggleMute,
        ),
        _RoundButton(
          icon: Icons.call_end_rounded,
          label: tr('Хотима'),
          color: const Color(0xFFE53935),
          onTap: ended ? null : _c.hangUp,
        ),
      ],
    );
  }
}

/// mm:ss (or h:mm:ss for long calls).
String formatCallDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return h > 0 ? '$h:$m:$s' : '$m:$s';
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.letter, required this.pulse, this.url});
  final String letter;
  final String? url;
  final AnimationController pulse;

  static const _size = 128.0;

  Widget get letterText => Text(
    letter,
    style: const TextStyle(
      color: Colors.white,
      fontSize: 52,
      fontWeight: FontWeight.w600,
    ),
  );

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _size * 1.9,
      height: _size * 1.9,
      child: AnimatedBuilder(
        animation: pulse,
        builder: (context, child) => Stack(
          alignment: Alignment.center,
          children: [
            if (pulse.isAnimating)
              for (final offset in const [0.0, 0.5])
                _ring((pulse.value + offset) % 1),
            child!,
          ],
        ),
        child: Container(
          width: _size,
          height: _size,
          alignment: Alignment.center,
          clipBehavior: Clip.antiAlias,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF5B8CFF), Color(0xFF2F55D4)],
            ),
          ),
          child: url == null || url!.isEmpty
              ? letterText
              : Image.network(
                  url!,
                  width: _size,
                  height: _size,
                  fit: BoxFit.cover,
                  // Letter until the first frame arrives (and on errors).
                  frameBuilder: (_, child, frame, sync) =>
                      sync || frame != null ? child : letterText,
                  errorBuilder: (_, _, _) => letterText,
                ),
        ),
      ),
    );
  }

  Widget _ring(double t) {
    final size = _size * (1 + 0.85 * t);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.10 * (1 - t)),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color? color;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final bg =
        color ?? (active ? Colors.white : Colors.white.withValues(alpha: 0.14));
    final fg = color != null
        ? Colors.white
        : (active ? const Color(0xFF0E1A33) : Colors.white);
    return Opacity(
      opacity: onTap == null ? 0.5 : 1,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: bg,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: SizedBox(
                width: 68,
                height: 68,
                child: Icon(icon, color: fg, size: 30),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
