// Файл: chat-и волид ва фарзанд.

import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/models.dart';
import '../../core/session.dart';
import '../../ui/avatar.dart';
import '../../ui/widgets.dart';
import '../call/call_screen.dart';
import '../../l10n/l10n.dart';

/// Қимати chatCallText-ро барои chat-и волид ва фарзанд нигоҳ медорад.
const chatCallText = 'Занг зад — лутфан ба телефон занг занед';

/// Қимати chatQuickReplies-ро барои chat-и волид ва фарзанд нигоҳ медорад.
List<String> get chatQuickReplies => [
  tr('Ман расидам'),
  tr('Ман дар роҳам'),
  tr('Маро гиред'),
  tr('Ҳама хуб аст'),
];

/// Экрани ChatScreen-ро барои chat-и волид ва фарзанд месозад.
class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.childId,
    required this.title,
    this.avatarPath,
  });
  final int childId;
  final String title;

  /// Қимати avatarPath-ро барои chat-и волид ва фарзанд нигоҳ медорад.
  final String? avatarPath;

  static const pollInterval = Duration(seconds: 4);

  /// Ҳолати ChatScreen-ро барои чат байни волид ва фарзанд месозад.
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

/// Pending додаҳо ва рафтори чати волид ва фарзанд-ро ифода мекунад.
class _Pending {
  _Pending(this.content, this.type);
  final String content;
  final String type;
  bool failed = false;
}

/// Ҳолат ва рафтори ChatScreenState-ро барои навсозии интерфейс идора мекунад.
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
  bool _markedOnce = false;

  /// Қимати ҳисобшудаи api-ро аз ҳолати ҷорӣ бармегардонад.
  NigohApi get _api => SessionScope.read(context).api;
  /// Қимати ҳисобшудаи myRole-ро аз ҳолати ҷорӣ бармегардонад.
  String get _myRole => SessionScope.read(context).role ?? '';

  /// myLast мантиқи зарурии chat-и волид ва фарзандро иҷро мекунад.
  ChatMessage? _myLast(String myRole) {
    ChatMessage? last;
    for (final m in _messages.values) {
      if (m.senderRole == myRole && (last == null || m.id > last.id)) last = m;
    }
    return last;
  }

  /// fetchAfter додаҳоро мехонад ва ҳолати экранро нав мекунад.
  int _fetchAfter(String myRole) {
    final mine = _myLast(myRole);
    if (mine == null || mine.isRead) return _lastId;
    return mine.id - 1 < _lastId ? mine.id - 1 : _lastId;
  }

  /// Матни воридшавандаро мешунавад, паёмҳоро бор мекунад ва polling-и чатро оғоз менамояд.
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

  /// onInput рӯйдодро коркард карда, ҳолати вобастаро нав мекунад.
  void _onInput() {
    if (mounted) setState(() {});
  }

  /// Пас аз иваз шудани параметрҳои widget ҳолати дохилиро ҳамоҳанг месозад.
  @override
  void didUpdateWidget(covariant ChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.childId != widget.childId) {
      _messages.clear();
      _pending.clear();
      _lastId = 0;
      _markedOnce = false;
      _loaded = false;
      _loadError = null;
      _load();
    }
  }

  /// Ба тағйири lifecycle-и ChatScreen ҷавоб медиҳад.
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

  /// startPolling раванди лозимро оғоз ва захираҳои вобастаро фаъол мекунад.
  void _startPolling() {
    _timer?.cancel();
    _timer = Timer.periodic(ChatScreen.pollInterval, (_) => _load());
  }

  /// Controller ва listener-ҳои ChatScreen-ро озод мекунад.
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// load додаҳои чати волид ва фарзанд-ро мехонад ва ҳолати ChatScreen-ро нав мекунад.
  Future<void> _load() async {
    if (_loading || !mounted) return;
    _loading = true;
    final childId = widget.childId;
    final myRole = _myRole;
    try {
      final raw = await _api.chat(childId, afterId: _fetchAfter(myRole));
      if (!mounted || childId != widget.childId) return;
      final fresh = _merge(raw.map(ChatMessage.fromJson));
      setState(() {
        _loaded = true;
        _loadError = null;
      });
      if (fresh.isNotEmpty) _scrollToBottom();
      if (!_markedOnce || fresh.any((m) => m.senderRole != myRole)) {
        _markedOnce = true;
        unawaited(_markRead(childId));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadError = e is ApiException ? e.message : '$e');
    } finally {
      _loading = false;
    }
  }

  /// markRead дархостро ба API мефиристад ва натиҷаро коркард мекунад.
  Future<void> _markRead(int childId) async {
    try {
      await _api.markChatRead(childId);
    } catch (e) {
      debugPrint('markChatRead: $e');
    }
  }

  /// merge мантиқи зарурии chat-и волид ва фарзандро иҷро мекунад.
  List<ChatMessage> _merge(Iterable<ChatMessage> items) {
    final added = <ChatMessage>[];
    for (final m in items) {
      if (!_messages.containsKey(m.id)) added.add(m);
      _messages[m.id] = m;
      if (m.id > _lastId) _lastId = m.id;
    }
    return added;
  }

  /// scrollToBottom мантиқи зарурии chat-и волид ва фарзандро иҷро мекунад.
  void _scrollToBottom({bool force = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      // Қадами дохилии chat-и волид ва фарзанд.
      if (!force && _scroll.offset > 260) return;
      final reduced = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
      if (reduced) {
        _scroll.jumpTo(0);
        return;
      }
      _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    });
  }

  /// send дархостро ба API мефиристад ва натиҷаро коркард мекунад.
  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    _input.clear();
    await _sendText(text);
  }

  /// sendText дархостро ба API мефиристад ва натиҷаро коркард мекунад.
  Future<void> _sendText(String text) async {
    if (_sending) return;
    final pending = _Pending(text, 'text');
    setState(() => _pending.add(pending));
    _scrollToBottom(force: true);
    await _deliver(pending);
  }

  /// retry мантиқи зарурии chat-и волид ва фарзандро иҷро мекунад.
  Future<void> _retry(_Pending pending) async {
    if (_sending) return;
    setState(() => pending.failed = false);
    await _deliver(pending);
  }

  /// deliver мантиқи зарурии chat-и волид ва фарзандро иҷро мекунад.
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
      _scrollToBottom(force: true);
    } catch (e) {
      if (!mounted) return;
      setState(() => pending.failed = true);
      showMessage(context, e, error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  /// call мантиқи зарурии chat-и волид ва фарзандро иҷро мекунад.
  Future<void> _call() => CallScreen.openOutgoing(
    context,
    childId: widget.childId,
    peerName: widget.title,
    peerAvatarUrl: _api.fileUrl(widget.avatarPath),
  );

  /// Экрани чатро бо таърихи паёмҳо, ҷавобҳои зуд ва сатри навиштан месозад.
  @override
  Widget build(BuildContext context) {
    final myRole = SessionScope.of(context).role ?? '';
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            AvatarView(
              name: widget.title,
              url: _api.fileUrl(widget.avatarPath),
              size: 36,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: tr('Занг'),
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
          if (myRole == 'child')
            _QuickReplies(enabled: !_sending, onTap: (text) => _sendText(text)),
          _InputBar(
            controller: _input,
            canSend: _input.text.trim().isNotEmpty && !_sending,
            onSend: _send,
          ),
        ],
      ),
    );
  }

  /// body мантиқи зарурии chat-и волид ва фарзандро иҷро мекунад.
  Widget _body(String myRole) {
    if (!_loaded) {
      if (_loadError != null) {
        return StateMessage(
          key: const ValueKey('error'),
          icon: Icons.cloud_off_rounded,
          title: tr('Паёмҳо бор нашуданд'),
          text: _loadError,
          actionLabel: tr('Аз нав кӯшиш'),
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
      return StateMessage(
        key: const ValueKey('empty'),
        icon: Icons.chat_bubble_outline_rounded,
        title: tr('Ҳоло паём нест'),
        text: tr('Аввалин паёмро нависед.'),
      );
    }
    // Қадами дохилии chat-и волид ва фарзанд.
    final myLast = _myLast(myRole);
    final rows = <Widget>[];
    DateTime? lastDay;
    for (final m in items) {
      final local = m.createdAt?.toLocal();
      if (local != null) {
        final day = DateTime(local.year, local.month, local.day);
        if (lastDay == null || day != lastDay) {
          rows.add(_DaySeparator(day, key: ValueKey('day-$day')));
          lastDay = day;
        }
      }
      final mine = m.senderRole == myRole;
      final time = _hhmm(m.createdAt);
      final read = mine && m.isRead && identical(m, myLast);
      rows.add(
        _Entry(
          // Қадами дохилии chat-и волид ва фарзанд.
          key: ValueKey('msg-${m.id}'),
          mine: mine,
          child: switch (m.type) {
            'call' => _CallChip(message: m, mine: mine),
            'urgent' => _UrgentBubble(
              message: m,
              mine: mine,
              time: time,
              read: read,
            ),
            _ => _Bubble(text: m.content, mine: mine, time: time, read: read),
          },
        ),
      );
    }
    for (final p in _pending) {
      rows.add(
        _Entry(
          key: ObjectKey(p),
          mine: true,
          child: _Bubble(
            text: p.content,
            mine: true,
            time: p.failed ? tr('Фиристода нашуд') : tr('Фиристода мешавад…'),
            pending: !p.failed,
            failed: p.failed,
            onRetry: () => _retry(p),
          ),
        ),
      );
    }
    final reversed = rows.reversed.toList();
    // Animation бо назардошти танзими кам кардани ҳаракат иҷро мешавад.
    final rowIndex = <Key, int>{
      for (final (i, row) in reversed.indexed)
        if (row.key != null) row.key!: i,
    };
    return ListView.builder(
      key: const ValueKey('list'),
      controller: _scroll,
      reverse: true,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      itemCount: reversed.length,
      findChildIndexCallback: (key) => rowIndex[key],
      itemBuilder: (_, i) => reversed[i],
    );
  }
}

/// Entry додаҳо ва рафтори чати волид ва фарзанд-ро ифода мекунад.
class _Entry extends StatefulWidget {
  const _Entry({super.key, required this.child, required this.mine});
  final Widget child;
  final bool mine;

  /// Ҳолати Entry-ро барои чат байни волид ва фарзанд месозад.
  @override
  State<_Entry> createState() => _EntryState();
}

/// Ҳолат ва рафтори EntryState-ро барои навсозии интерфейс идора мекунад.
class _EntryState extends State<_Entry> with SingleTickerProviderStateMixin {
  late final AnimationController _in = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );

  /// Animation-и пайдо шудани паёми нави чатро оғоз мекунад.
  @override
  void initState() {
    super.initState();
    _in.forward();
  }

  /// Controller ва listener-ҳои Entry-ро озод мекунад.
  @override
  void dispose() {
    _in.dispose();
    super.dispose();
  }

  /// Widget-и Entry-ро барои чат байни волид ва фарзанд месозад.
  @override
  Widget build(BuildContext context) {
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      return widget.child;
    }
    final curved = CurvedAnimation(parent: _in, curve: Curves.easeOutCubic);
    return AnimatedBuilder(
      animation: curved,
      builder: (context, child) => Opacity(
        opacity: curved.value.clamp(0, 1),
        child: Transform.translate(
          offset: Offset(
            (widget.mine ? 18 : -18) * (1 - curved.value),
            10 * (1 - curved.value),
          ),
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}

/// two мантиқи зарурии chat-и волид ва фарзандро иҷро мекунад.
String _two(int v) => v.toString().padLeft(2, '0');

/// hhmm мантиқи зарурии chat-и волид ва фарзандро иҷро мекунад.
String _hhmm(DateTime? time) {
  if (time == null) return '';
  final t = time.toLocal();
  return '${_two(t.hour)}:${_two(t.minute)}';
}

/// DaySeparator додаҳо ва рафтори чати волид ва фарзанд-ро ифода мекунад.
class _DaySeparator extends StatelessWidget {
  const _DaySeparator(this.day, {super.key});
  final DateTime day;

  /// Widget-и DaySeparator-ро барои чат байни волид ва фарзанд месозад.
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(day).inDays;
    final label = diff == 0
        ? tr('Имрӯз')
        : diff == 1
        ? tr('Дирӯз')
        : '${_two(day.day)}.${_two(day.month)}.${day.year}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

/// Bubble додаҳо ва рафтори чати волид ва фарзанд-ро ифода мекунад.
class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.text,
    required this.mine,
    required this.time,
    this.read = false,
    this.pending = false,
    this.failed = false,
    this.onRetry,
  });

  final String text;
  final bool mine;
  final String time;

  /// Қимати read-ро барои chat-и волид ва фарзанд нигоҳ медорад.
  final bool read;
  final bool pending;
  final bool failed;
  final VoidCallback? onRetry;

  /// Widget-и Bubble-ро барои чат байни волид ва фарзанд месозад.
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = mine ? scheme.primary : scheme.surfaceContainerHighest;
    final fg = mine ? scheme.onPrimary : scheme.onSurface;
    final bubble = Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * .76,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: pending || failed ? bg.withValues(alpha: .6) : bg,
        border: mine ? null : Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(20),
          topRight: const Radius.circular(20),
          bottomLeft: Radius.circular(mine ? 20 : 6),
          bottomRight: Radius.circular(mine ? 6 : 20),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(color: fg, height: 1.38, fontSize: 15.5),
      ),
    );
    final label = read && time.isNotEmpty
        ? tr('{time} · Хонда шуд', {'time': time})
        : time;
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
                  tooltip: tr('Аз нав фиристодан'),
                  icon: Icon(Icons.refresh_rounded, color: scheme.error),
                  onPressed: onRetry,
                ),
              Flexible(child: bubble),
            ],
          ),
          if (label.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (read) ...[
                    Icon(
                      Icons.done_all_rounded,
                      size: 13,
                      color: scheme.primary,
                    ),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: failed
                          ? scheme.error
                          : read
                          ? scheme.primary
                          : scheme.onSurfaceVariant,
                      fontWeight: read ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// UrgentBubble додаҳо ва рафтори чати волид ва фарзанд-ро ифода мекунад.
class _UrgentBubble extends StatelessWidget {
  const _UrgentBubble({
    required this.message,
    required this.mine,
    required this.time,
    this.read = false,
  });

  final ChatMessage message;
  final bool mine;
  final String time;
  final bool read;

  /// Widget-и UrgentBubble-ро барои чат байни волид ва фарзанд месозад.
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final red = scheme.error;
    final who = mine
        ? tr('Шумо SOS фиристодед')
        : tr('{name} SOS фиристод', {
            'name': message.senderName.trim().isEmpty
                ? tr('Фарзанд')
                : message.senderName.trim(),
          });
    final label = read && time.isNotEmpty
        ? tr('{time} · Хонда шуд', {'time': time})
        : time;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: mine
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Container(
            key: const ValueKey('urgent-bubble'),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * .84,
            ),
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              color: red.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: red.withValues(alpha: .55), width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.warning_amber_rounded, color: red, size: 20),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        who,
                        style: TextStyle(
                          color: red,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                SelectableText(
                  message.content,
                  style: TextStyle(color: scheme.onSurface, height: 1.4),
                ),
              ],
            ),
          ),
          if (label.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 2),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// QuickReplies додаҳо ва рафтори чати волид ва фарзанд-ро ифода мекунад.
class _QuickReplies extends StatelessWidget {
  const _QuickReplies({required this.enabled, required this.onTap});
  final bool enabled;
  final ValueChanged<String> onTap;

  /// Қимати _icons-ро барои chat-и волид ва фарзанд нигоҳ медорад.
  static const _icons = [
    Icons.check_circle_rounded,
    Icons.directions_walk_rounded,
    Icons.directions_car_rounded,
    Icons.thumb_up_rounded,
  ];

  /// Widget-и QuickReplies-ро барои чат байни волид ва фарзанд месозад.
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 54,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
        itemCount: chatQuickReplies.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final text = chatQuickReplies[i];
          return ActionChip(
            avatar: i < _icons.length
                ? Icon(_icons[i], size: 18, color: scheme.primary)
                : null,
            label: Text(text),
            side: BorderSide(color: scheme.outlineVariant),
            onPressed: enabled ? () => onTap(text) : null,
          );
        },
      ),
    );
  }
}

/// CallChip додаҳо ва рафтори чати волид ва фарзанд-ро ифода мекунад.
class _CallChip extends StatelessWidget {
  const _CallChip({required this.message, required this.mine});
  final ChatMessage message;
  final bool mine;

  /// Widget-и CallChip-ро барои чат байни волид ва фарзанд месозад.
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final other = message.senderName.trim().isNotEmpty
        ? message.senderName.trim()
        : message.senderRole == 'parent'
        ? tr('Волидайн')
        : tr('Фарзанд');
    final text = mine
        ? tr('Шумо хоҳиши занг фиристодед')
        : tr('{name} хоҳиш дорад, ки занг занед', {'name': other});
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

/// Widget-и ErrorBanner-ро барои chat-и волид ва фарзанд месозад.
class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner(this.text, this.onRetry);
  final String text;
  final VoidCallback onRetry;

  /// Widget-и ErrorBanner-ро барои чат байни волид ва фарзанд месозад.
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
          TextButton(onPressed: onRetry, child: Text(tr('Аз нав'))),
        ],
      ),
    );
  }
}

/// InputBar додаҳо ва рафтори чати волид ва фарзанд-ро ифода мекунад.
class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.canSend,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool canSend;
  final VoidCallback onSend;

  /// Widget-и InputBar-ро барои чат байни волид ва фарзанд месозад.
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
                decoration: InputDecoration(
                  hintText: tr('Паём нависед…'),
                  counterText: '',
                ),
                onSubmitted: (_) {
                  if (canSend) onSend();
                },
              ),
            ),
            const SizedBox(width: 6),
            AnimatedScale(
              duration:
                  (MediaQuery.maybeOf(context)?.disableAnimations ?? false)
                  ? Duration.zero
                  : const Duration(milliseconds: 180),
              scale: canSend ? 1 : .88,
              curve: Curves.easeOutBack,
              child: IconButton.filled(
                tooltip: tr('Фиристодан'),
                onPressed: canSend ? onSend : null,
                icon: const Icon(Icons.send_rounded),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
