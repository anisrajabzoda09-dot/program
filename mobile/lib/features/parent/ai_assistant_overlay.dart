// Файл: кулӯлаи ҳаракаткунанда ва чати NIGOH AI барои волидайн.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/models.dart';
import '../../l10n/l10n.dart';
import '../../ui/nigoh_design.dart';
import '../../ui/widgets.dart';
import 'family_controller.dart';

final parentAiController = ValueNotifier<FamilyController?>(null);
bool aiAssistantPortalMounted = false;

class AiAssistantPortal extends StatefulWidget {
  const AiAssistantPortal({
    super.key,
    required this.navigatorKey,
    required this.child,
  });

  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;

  @override
  State<AiAssistantPortal> createState() => _AiAssistantPortalState();
}

class _AiAssistantPortalState extends State<AiAssistantPortal> {
  @override
  void initState() {
    super.initState();
    aiAssistantPortalMounted = true;
  }

  @override
  void dispose() {
    aiAssistantPortalMounted = false;
    parentAiController.value = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<FamilyController?>(
        valueListenable: parentAiController,
        child: widget.child,
        builder: (context, controller, child) {
          if (controller == null) return child!;
          return ListenableBuilder(
            listenable: controller,
            builder: (context, _) => AiAssistantOverlay(
              controller: controller,
              navigatorKey: widget.navigatorKey,
              child: child!,
            ),
          );
        },
      );
}

class AiAssistantOverlay extends StatefulWidget {
  const AiAssistantOverlay({
    super.key,
    required this.controller,
    required this.navigatorKey,
    required this.child,
  });

  final FamilyController controller;
  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;

  @override
  State<AiAssistantOverlay> createState() => _AiAssistantOverlayState();
}

class _AiAssistantOverlayState extends State<AiAssistantOverlay> {
  static const _xKey = 'nigoh.ai.bubble.x';
  static const _yKey = 'nigoh.ai.bubble.y';
  static const _size = 58.0;

  Offset? _position;
  double? _savedX;
  double? _savedY;
  bool _chatOpen = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadPosition());
  }

  Future<void> _loadPosition() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _savedX = preferences.getDouble(_xKey);
        _savedY = preferences.getDouble(_yKey);
      });
    } catch (_) {}
  }

  Future<void> _savePosition(Offset position, Size area) async {
    final x = area.width <= _size ? 0.0 : position.dx / (area.width - _size);
    final y = area.height <= _size ? 0.0 : position.dy / (area.height - _size);
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setDouble(_xKey, x.clamp(0.0, 1.0).toDouble());
      await preferences.setDouble(_yKey, y.clamp(0.0, 1.0).toDouble());
    } catch (_) {}
  }

  Offset _clamp(Offset value, Size area, EdgeInsets padding, bool compact) {
    const side = 10.0;
    final minimumX = padding.left + side;
    final maximumX = (area.width - padding.right - _size - side)
        .clamp(minimumX, double.infinity)
        .toDouble();
    final minimumY = padding.top + side;
    final navigationSpace = compact ? 88.0 : 12.0;
    final maximumY =
        (area.height - padding.bottom - navigationSpace - _size - side)
            .clamp(minimumY, double.infinity)
            .toDouble();
    return Offset(
      value.dx.clamp(minimumX, maximumX).toDouble(),
      value.dy.clamp(minimumY, maximumY).toDouble(),
    );
  }

  Future<void> _openChat() async {
    final selected = widget.controller.selected;
    final navigatorContext = widget.navigatorKey.currentContext;
    if (selected == null || navigatorContext == null || _chatOpen) return;
    setState(() => _chatOpen = true);
    await showModalBottomSheet<void>(
      context: navigatorContext,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: AiAssistantChat(
            controller: widget.controller,
            initialChildId: selected.id,
          ),
        ),
      ),
    );
    if (mounted) setState(() => _chatOpen = false);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.controller.selected == null) return widget.child;
    final media = MediaQuery.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final area = media.size;
        final compact = area.width < 900;
        final saved = _savedX != null && _savedY != null
            ? Offset(
                _savedX! * (area.width - _size),
                _savedY! * (area.height - _size),
              )
            : null;
        final fallback = Offset(
          area.width - media.padding.right - _size - 14,
          area.height - media.padding.bottom - _size - (compact ? 104 : 24),
        );
        final position = _clamp(
          _position ?? saved ?? fallback,
          area,
          media.padding,
          compact,
        );
        return Stack(
          children: [
            Positioned.fill(child: widget.child),
            if (!_chatOpen)
              Positioned(
                left: position.dx,
                top: position.dy,
                child: Semantics(
                  button: true,
                  label: tr('NIGOH AI'),
                  hint: tr('Кашида бурда мешавад. Барои кушодан зер кунед.'),
                  child: GestureDetector(
                    key: const ValueKey('nigoh-ai-bubble'),
                    behavior: HitTestBehavior.opaque,
                    onPanUpdate: (details) {
                      setState(() {
                        _position = _clamp(
                          position + details.delta,
                          area,
                          media.padding,
                          compact,
                        );
                      });
                    },
                    onPanEnd: (_) {
                      final current = _position ?? position;
                      unawaited(_savePosition(current, area));
                    },
                    child: Material(
                      color: Colors.transparent,
                      child: Ink(
                        width: _size,
                        height: _size,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: NigohDesign.violet.withValues(alpha: .35),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: .16),
                              blurRadius: 18,
                              offset: const Offset(0, 7),
                            ),
                          ],
                        ),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: _openChat,
                          child: const Stack(
                            alignment: Alignment.center,
                            children: [
                              Icon(
                                Icons.auto_awesome_rounded,
                                color: NigohDesign.violet,
                                size: 27,
                              ),
                              Positioned(right: 8, bottom: 7, child: _AiDot()),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _AiDot extends StatelessWidget {
  const _AiDot();

  @override
  Widget build(BuildContext context) => Container(
    width: 9,
    height: 9,
    decoration: BoxDecoration(
      color: NigohDesign.mint,
      shape: BoxShape.circle,
      border: Border.all(
        color: Theme.of(context).colorScheme.surface,
        width: 2,
      ),
    ),
  );
}

class AiAssistantChat extends StatefulWidget {
  const AiAssistantChat({
    super.key,
    required this.controller,
    required this.initialChildId,
  });

  final FamilyController controller;
  final int initialChildId;

  @override
  State<AiAssistantChat> createState() => _AiAssistantChatState();
}

class _AiAssistantChatState extends State<AiAssistantChat> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  late int _childId;
  bool _loading = false;
  late List<_AssistantMessage> _messages;

  FamilyChild get _child =>
      widget.controller.childById(_childId) ?? widget.controller.selected!;

  @override
  void initState() {
    super.initState();
    _childId = widget.initialChildId;
    _messages = [_greeting()];
  }

  _AssistantMessage _greeting() => _AssistantMessage(
    text: tr(
      'Ман ёвари NIGOH ҳастам. Савол диҳед ё бигӯед кадом барномаро дар телефони {name} бандем ё кушоем.',
      {'name': _child.name},
    ),
  );

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  bool _isRuleRequest(String text) {
    final value = text.toLowerCase();
    const words = [
      'банд',
      'маҳкам',
      'кушо',
      'гузор',
      ' мон',
      'маҳдуд кун',
      'block',
      'unblock',
      'set limit',
      'limit to',
      'заблок',
      'разблок',
      'ограничь',
    ];
    return words.any(value.contains);
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send([String? suggestion]) async {
    final text = (suggestion ?? _input.text).trim();
    if (_loading || text.length < 3) return;
    _input.clear();
    setState(() {
      _messages.add(_AssistantMessage(text: text, fromParent: true));
      _loading = true;
    });
    _scrollToEnd();
    try {
      if (_isRuleRequest(text)) {
        final response = await widget.controller.api.previewAiRules(
          _childId,
          text,
        );
        final raw = response['proposal'];
        if (raw is! Map) throw const FormatException('proposal');
        final proposal = Map<String, dynamic>.from(raw);
        final actions = (proposal['actions'] as List? ?? const [])
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
        final summary = proposal['summary']?.toString().trim() ?? '';
        setState(() {
          _messages.add(
            _AssistantMessage(
              text: summary.isEmpty ? tr('Фармон тайёр аст.') : summary,
              actions: actions,
            ),
          );
        });
      } else {
        final response = await widget.controller.api.aiHelp(_childId, text);
        final answer = response['answer']?.toString().trim() ?? '';
        setState(() {
          _messages.add(
            _AssistantMessage(
              text: answer.isEmpty ? tr('Ҷавоб гирифта нашуд.') : answer,
            ),
          );
        });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _messages.add(_AssistantMessage(text: error.toString(), error: true));
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
        _scrollToEnd();
      }
    }
  }

  ChildApp? _findApp(String packageName) {
    final current = widget.controller.childById(_childId) ?? _child;
    for (final app in current.apps) {
      if (app.packageName == packageName) return app;
    }
    return null;
  }

  Future<void> _apply(int messageIndex) async {
    final message = _messages[messageIndex];
    if (message.applied || message.actions.isEmpty || _loading) return;
    setState(() => _loading = true);
    try {
      for (final action in message.actions) {
        final packageName = action['package_name']?.toString() ?? '';
        var app = _findApp(packageName);
        if (app == null) continue;
        if (action['is_blocked'] is bool) {
          await widget.controller.setBlocked(
            widget.controller.childById(_childId) ?? _child,
            app,
            action['is_blocked'] as bool,
          );
          app = _findApp(packageName) ?? app;
        }
        if (action['daily_limit_minutes'] is num) {
          await widget.controller.setLimit(
            widget.controller.childById(_childId) ?? _child,
            app,
            (action['daily_limit_minutes'] as num).toInt(),
          );
          app = _findApp(packageName) ?? app;
        }
        if (action['schedule'] is Map) {
          await widget.controller.setSchedule(
            widget.controller.childById(_childId) ?? _child,
            app,
            AppSchedule.fromJson(action['schedule']),
          );
        }
      }
      if (!mounted) return;
      setState(() {
        _messages[messageIndex] = message.copyWith(applied: true);
        _messages.add(_AssistantMessage(text: tr('Тағйирот татбиқ шуд.')));
      });
      showMessage(context, tr('Қоидаҳои тасдиқшуда татбиқ шуданд.'));
    } catch (error) {
      if (mounted) showMessage(context, error, error: true);
    } finally {
      if (mounted) {
        setState(() => _loading = false);
        _scrollToEnd();
      }
    }
  }

  void _selectChild(int? childId) {
    if (childId == null || childId == _childId) return;
    widget.controller.select(childId);
    setState(() {
      _childId = childId;
      _messages = [_greeting()];
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final height = MediaQuery.sizeOf(context).height * .86;
    return Material(
      color: scheme.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: height.clamp(440.0, 760.0).toDouble(),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: scheme.outlineVariant,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 10, 10),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: NigohDesign.violet.withValues(alpha: .10),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      color: NigohDesign.violet,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr('NIGOH AI'),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          tr('Савол диҳед ё барномаҳоро идора кунед'),
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: tr('Пӯшидан'),
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            if (widget.controller.children.length > 1)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
                child: DropdownButtonFormField<int>(
                  key: const ValueKey('ai-child-selector'),
                  initialValue: _childId,
                  decoration: InputDecoration(
                    labelText: tr('Фарзанд'),
                    prefixIcon: const Icon(Icons.child_care_rounded),
                    isDense: true,
                  ),
                  items: [
                    for (final child in widget.controller.children)
                      DropdownMenuItem(
                        value: child.id,
                        child: Text(child.name),
                      ),
                  ],
                  onChanged: _loading ? null : _selectChild,
                ),
              ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                key: const ValueKey('ai-chat-list'),
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      ActionChip(
                        label: Text(tr('TikTok-ро банд кун')),
                        onPressed: _loading
                            ? null
                            : () => _send('TikTok-ро банд кун'),
                      ),
                      ActionChip(
                        label: Text(tr('YouTube-ро 1 соат мон')),
                        onPressed: _loading
                            ? null
                            : () => _send('YouTube-ро 1 соат мон'),
                      ),
                      ActionChip(
                        label: Text(tr('Лимит чӣ тавр кор мекунад?')),
                        onPressed: _loading
                            ? null
                            : () => _send('Лимит чӣ тавр кор мекунад?'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  for (var index = 0; index < _messages.length; index++)
                    _MessageBubble(
                      message: _messages[index],
                      apps: _child.apps,
                      onApply: () => _apply(index),
                    ),
                  if (_loading)
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.fromLTRB(
                14,
                10,
                10,
                10 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              decoration: BoxDecoration(
                color: scheme.surface,
                border: Border(top: BorderSide(color: scheme.outlineVariant)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      key: const ValueKey('ai-chat-input'),
                      controller: _input,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: _loading ? null : (_) => _send(),
                      decoration: InputDecoration(
                        hintText: tr('Ба NIGOH AI нависед...'),
                        counterText: '',
                      ),
                      maxLength: 1000,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    key: const ValueKey('ai-chat-send'),
                    tooltip: tr('Фиристодан'),
                    onPressed: _loading ? null : _send,
                    icon: const Icon(Icons.arrow_upward_rounded),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.apps,
    required this.onApply,
  });

  final _AssistantMessage message;
  final List<ChildApp> apps;
  final VoidCallback onApply;

  ChildApp? _app(String packageName) {
    for (final app in apps) {
      if (app.packageName == packageName) return app;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background = message.fromParent
        ? scheme.primary
        : message.error
        ? scheme.errorContainer
        : scheme.surfaceContainerHighest;
    final foreground = message.fromParent
        ? scheme.onPrimary
        : message.error
        ? scheme.onErrorContainer
        : scheme.onSurface;
    return Align(
      alignment: message.fromParent
          ? Alignment.centerRight
          : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(message.fromParent ? 18 : 5),
            bottomRight: Radius.circular(message.fromParent ? 5 : 18),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message.text, style: TextStyle(color: foreground)),
            if (message.actions.isNotEmpty) ...[
              const SizedBox(height: 10),
              for (final action in message.actions)
                _CompactAction(
                  action: action,
                  app: _app('${action['package_name']}'),
                ),
              const SizedBox(height: 8),
              Text(
                tr('Тағйирот танҳо пас аз тасдиқи шумо иҷро мешавад.'),
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const ValueKey('ai-chat-apply'),
                  onPressed: message.applied ? null : onApply,
                  icon: Icon(
                    message.applied
                        ? Icons.check_rounded
                        : Icons.shield_rounded,
                  ),
                  label: Text(
                    message.applied
                        ? tr('Татбиқ шуд')
                        : tr('Тасдиқ ва татбиқ кардан'),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CompactAction extends StatelessWidget {
  const _CompactAction({required this.action, required this.app});

  final Map<String, dynamic> action;
  final ChildApp? app;

  @override
  Widget build(BuildContext context) {
    final details = <String>[
      if (action['is_blocked'] is bool)
        action['is_blocked'] == true ? tr('Бастан') : tr('Кушодан'),
      if (action['daily_limit_minutes'] is num)
        tr('{count} дақ дар рӯз', {
          'count': (action['daily_limit_minutes'] as num).toInt(),
        }),
      if (action['schedule'] is Map)
        '${action['schedule']['start']}–${action['schedule']['end']}',
    ];
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          NigohAppIcon(
            icon: app?.iconBase64 ?? '',
            seed: action['package_name']?.toString() ?? '',
            size: 32,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  app?.name ?? action['package_name']?.toString() ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  details.join(' · '),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
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

class _AssistantMessage {
  const _AssistantMessage({
    required this.text,
    this.fromParent = false,
    this.actions = const [],
    this.applied = false,
    this.error = false,
  });

  final String text;
  final bool fromParent;
  final List<Map<String, dynamic>> actions;
  final bool applied;
  final bool error;

  _AssistantMessage copyWith({bool? applied}) => _AssistantMessage(
    text: text,
    fromParent: fromParent,
    actions: actions,
    applied: applied ?? this.applied,
    error: error,
  );
}
