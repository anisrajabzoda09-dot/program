import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/models.dart';
import '../../core/session.dart';
import '../../ui/widgets.dart';

/// Text sent with a call request.
const chatCallText = 'Занг зад — лутфан ба телефон занг занед';

/// Family chat between a parent and one child, used on both phones.
/// Polls the server every 4 seconds while visible.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.childId, required this.title});
  final int childId;
  final String title;

  static const pollInterval = Duration(seconds: 4);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _Pending {
  _Pending(this.content, this.type);
  final String content;
  final String type;
  bool failed = false;
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _messages = <int, ChatMessage>{};
  final _pending = <_Pending>[];
  Timer? _timer;
  bool _loaded = false;
  bool _loading = false;
  bool _sending = false;
  String? _loadError;
  int _lastId = 0;

  NigohApi get _api => SessionScope.read(context).api;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _input.addListener(_onInput);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _load();
      _startPolling();
    });
  }

  void _onInput() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant ChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.childId != widget.childId) {
      _messages.clear();
      _pending.clear();
      _lastId = 0;
      _loaded = false;
      _loadError = null;
      _load();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _load();
      _startPolling();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _timer?.cancel();
      _timer = null;
    }
  }

  void _startPolling() {
    _timer?.cancel();
    _timer = Timer.periodic(ChatScreen.pollInterval, (_) => _load());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_loading || !mounted) return;
    _loading = true;
    final childId = widget.childId;
    try {
      final raw = await _api.chat(childId, afterId: _lastId);
      if (!mounted || childId != widget.childId) return;
      final added = _merge(raw.map(ChatMessage.fromJson));
      setState(() {
        _loaded = true;
        _loadError = null;
      });
      if (added) _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadError = e is ApiException ? e.message : '$e');
    } finally {
      _loading = false;
    }
  }

  /// Adds messages by id; returns true when something new arrived.
  bool _merge(Iterable<ChatMessage> items) {
    var added = false;
    for (final m in items) {
      if (!_messages.containsKey(m.id)) added = true;
      _messages[m.id] = m;
      if (m.id > _lastId) _lastId = m.id;
    }
    return added;
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      // The list is reversed: offset 0 is the newest message.
      _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    _input.clear();
    final pending = _Pending(text, 'text');
    setState(() => _pending.add(pending));
    _scrollToBottom();
    await _deliver(pending);
  }

  Future<void> _retry(_Pending pending) async {
    if (_sending) return;
    setState(() => pending.failed = false);
    await _deliver(pending);
  }

  Future<void> _deliver(_Pending pending) async {
    setState(() => _sending = true);
    try {
      final data = await _api.sendChat(
        widget.childId,
        pending.content,
        messageType: pending.type,
      );
      if (!mounted) return;
      final raw = data['message'];
      setState(() {
        _pending.remove(pending);
        if (raw is Map) {
          _merge([ChatMessage.fromJson(Map<String, dynamic>.from(raw))]);
        }
      });
      if (raw is! Map) unawaited(_load());
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() => pending.failed = true);
      showMessage(context, e, error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _call() async {
    try {
      final data = await _api.sendChat(
        widget.childId,
        chatCallText,
        messageType: 'call',
      );
      if (!mounted) return;
      final raw = data['message'];
      if (raw is Map) {
        setState(
          () => _merge([ChatMessage.fromJson(Map<String, dynamic>.from(raw))]),
        );
        _scrollToBottom();
      }
      showMessage(context, 'Хоҳиши занг фиристода шуд');
    } catch (e) {
      if (mounted) showMessage(context, e, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final myRole = SessionScope.of(context).role ?? '';
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            tooltip: 'Хоҳиши занг',
            icon: const Icon(Icons.phone_rounded),
            onPressed: _call,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          if (_loadError != null && _loaded) _ErrorBanner(_loadError!, _load),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _body(myRole),
            ),
          ),
          _InputBar(
            controller: _input,
            canSend: _input.text.trim().isNotEmpty && !_sending,
            onSend: _send,
          ),
        ],
      ),
    );
  }

  Widget _body(String myRole) {
    if (!_loaded) {
      if (_loadError != null) {
        return StateMessage(
          key: const ValueKey('error'),
          icon: Icons.cloud_off_rounded,
          title: 'Паёмҳо бор нашуданд',
          text: _loadError,
          actionLabel: 'Аз нав кӯшиш',
          onAction: _load,
          error: true,
        );
      }
      return const Center(
        key: ValueKey('loading'),
        child: CircularProgressIndicator(),
      );
    }
    final items = _messages.values.toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    if (items.isEmpty && _pending.isEmpty) {
      return const StateMessage(
        key: ValueKey('empty'),
        icon: Icons.chat_bubble_outline_rounded,
        title: 'Ҳоло паём нест',
        text: 'Аввалин паёмро нависед.',
      );
    }
    // Built oldest → newest with day separators, shown reversed so the list
    // starts at the bottom.
    final rows = <Widget>[];
    DateTime? lastDay;
    for (final m in items) {
      final local = m.createdAt?.toLocal();
      if (local != null) {
        final day = DateTime(local.year, local.month, local.day);
        if (lastDay == null || day != lastDay) {
          rows.add(_DaySeparator(day));
          lastDay = day;
        }
      }
      final mine = m.senderRole == myRole;
      rows.add(
        m.type == 'call'
            ? _CallChip(message: m, mine: mine)
            : _Bubble(text: m.content, mine: mine, time: _hhmm(m.createdAt)),
      );
    }
    for (final p in _pending) {
      rows.add(
        _Bubble(
          text: p.content,
          mine: true,
          time: p.failed ? 'Фиристода нашуд' : 'Фиристода мешавад…',
          pending: !p.failed,
          failed: p.failed,
          onRetry: () => _retry(p),
        ),
      );
    }
    final reversed = rows.reversed.toList();
    return ListView.builder(
      key: const ValueKey('list'),
      controller: _scroll,
      reverse: true,
      padding: const EdgeInsets.all(12),
      itemCount: reversed.length,
      itemBuilder: (_, i) => reversed[i],
    );
  }
}

String _two(int v) => v.toString().padLeft(2, '0');

String _hhmm(DateTime? time) {
  if (time == null) return '';
  final t = time.toLocal();
  return '${_two(t.hour)}:${_two(t.minute)}';
}

class _DaySeparator extends StatelessWidget {
  const _DaySeparator(this.day);
  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(day).inDays;
    final label = diff == 0
        ? 'Имрӯз'
        : diff == 1
        ? 'Дирӯз'
        : '${_two(day.day)}.${_two(day.month)}.${day.year}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.text,
    required this.mine,
    required this.time,
    this.pending = false,
    this.failed = false,
    this.onRetry,
  });

  final String text;
  final bool mine;
  final String time;
  final bool pending;
  final bool failed;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = mine ? scheme.primary : scheme.surface;
    final fg = mine ? scheme.onPrimary : scheme.onSurface;
    final bubble = Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * .74,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: pending || failed ? bg.withValues(alpha: .6) : bg,
        border: mine ? null : Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(mine ? 18 : 6),
          bottomRight: Radius.circular(mine ? 6 : 18),
        ),
      ),
      child: Text(text, style: TextStyle(color: fg, height: 1.35)),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Column(
        crossAxisAlignment: mine
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: mine
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            children: [
              if (failed)
                IconButton(
                  tooltip: 'Аз нав фиристодан',
                  icon: Icon(Icons.refresh_rounded, color: scheme.error),
                  onPressed: onRetry,
                ),
              Flexible(child: bubble),
            ],
          ),
          if (time.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 3, 6, 2),
              child: Text(
                time,
                style: TextStyle(
                  fontSize: 11,
                  color: failed ? scheme.error : scheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CallChip extends StatelessWidget {
  const _CallChip({required this.message, required this.mine});
  final ChatMessage message;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final other = message.senderName.trim().isNotEmpty
        ? message.senderName.trim()
        : message.senderRole == 'parent'
        ? 'Волидайн'
        : 'Фарзанд';
    final text = mine
        ? 'Шумо хоҳиши занг фиристодед'
        : '$other хоҳиш дорад, ки занг занед';
    final time = _hhmm(message.createdAt);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: .10),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.phone_in_talk_rounded,
                size: 16,
                color: scheme.primary,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  time.isEmpty ? text : '$text · $time',
                  style: TextStyle(
                    color: scheme.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 12.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner(this.text, this.onRetry);
  final String text;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: scheme.error.withValues(alpha: .10),
      padding: const EdgeInsets.fromLTRB(16, 4, 6, 4),
      child: Row(
        children: [
          Icon(Icons.cloud_off_rounded, size: 18, color: scheme.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: scheme.error, fontSize: 13),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Аз нав')),
        ],
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.canSend,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool canSend;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        decoration: BoxDecoration(
          color: scheme.surface,
          border: Border(top: BorderSide(color: scheme.outlineVariant)),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                maxLength: 4000,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Паём нависед…',
                  counterText: '',
                ),
                onSubmitted: (_) {
                  if (canSend) onSend();
                },
              ),
            ),
            const SizedBox(width: 6),
            IconButton.filled(
              tooltip: 'Фиристодан',
              onPressed: canSend ? onSend : null,
              icon: const Icon(Icons.send_rounded),
            ),
          ],
        ),
      ),
    );
  }
}
