// Файл: ёвари NIGOH AI барои сохтани preview ва тасдиқи қоидаҳои барномаҳо.

import 'package:flutter/material.dart';

import '../../core/models.dart';
import '../../l10n/l10n.dart';
import '../../ui/nigoh_design.dart';
import '../../ui/widgets.dart';
import 'family_controller.dart';

class AiRulesSheet extends StatefulWidget {
  const AiRulesSheet({
    super.key,
    required this.controller,
    required this.child,
  });

  final FamilyController controller;
  final FamilyChild child;

  @override
  State<AiRulesSheet> createState() => _AiRulesSheetState();
}

class _AiRulesSheetState extends State<AiRulesSheet> {
  final input = TextEditingController();
  Map<String, dynamic>? proposal;
  bool loading = false;
  bool applying = false;
  bool categoryLoading = false;
  List<Map<String, dynamic>> categoryPreview = const [];

  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    final text = input.text.trim();
    if (text.length < 5) {
      showMessage(context, tr('Хоҳишро каме равшантар нависед.'), error: true);
      return;
    }
    setState(() {
      loading = true;
      proposal = null;
    });
    try {
      final response = await widget.controller.api.previewAiRules(
        widget.child.id,
        text,
      );
      if (!mounted) return;
      final raw = response['proposal'];
      if (raw is! Map) throw const FormatException('proposal');
      setState(() => proposal = Map<String, dynamic>.from(raw));
    } catch (error) {
      if (mounted) showMessage(context, error, error: true);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  List<Map<String, dynamic>> get _actions =>
      (proposal?['actions'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();

  ChildApp? _app(String package) {
    final child = widget.controller.childById(widget.child.id) ?? widget.child;
    for (final app in child.apps) {
      if (app.packageName == package) return app;
    }
    return null;
  }

  Future<void> _apply() async {
    if (_actions.isEmpty) return;
    setState(() => applying = true);
    try {
      for (final action in _actions) {
        final package = action['package_name']?.toString() ?? '';
        var app = _app(package);
        if (app == null) continue;
        if (action['is_blocked'] is bool) {
          await widget.controller.setBlocked(
            widget.controller.childById(widget.child.id) ?? widget.child,
            app,
            action['is_blocked'] as bool,
          );
          app = _app(package) ?? app;
        }
        if (action['daily_limit_minutes'] is num) {
          await widget.controller.setLimit(
            widget.controller.childById(widget.child.id) ?? widget.child,
            app,
            (action['daily_limit_minutes'] as num).toInt(),
          );
          app = _app(package) ?? app;
        }
        if (action['schedule'] is Map) {
          await widget.controller.setSchedule(
            widget.controller.childById(widget.child.id) ?? widget.child,
            app,
            AppSchedule.fromJson(action['schedule']),
          );
        }
      }
      if (!mounted) return;
      showMessage(context, tr('Қоидаҳои тасдиқшуда татбиқ шуданд.'));
      Navigator.pop(context, true);
    } catch (error) {
      if (mounted) showMessage(context, error, error: true);
    } finally {
      if (mounted) setState(() => applying = false);
    }
  }

  Future<void> _previewCategories() async {
    setState(() {
      categoryLoading = true;
      categoryPreview = const [];
    });
    try {
      final response = await widget.controller.api.previewAiCategories(
        widget.child.id,
      );
      if (!mounted) return;
      setState(() {
        categoryPreview = (response['categories'] as List? ?? const [])
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      });
    } catch (error) {
      if (mounted) showMessage(context, error, error: true);
    } finally {
      if (mounted) setState(() => categoryLoading = false);
    }
  }

  Future<void> _applyCategories() async {
    setState(() => categoryLoading = true);
    try {
      await widget.controller.api.applyAiCategories(
        widget.child.id,
        categoryPreview,
      );
      await widget.controller.refresh(silent: true);
      if (!mounted) return;
      setState(() => categoryPreview = const []);
      showMessage(context, tr('Категорияҳои тасдиқшуда нигоҳ дошта шуданд.'));
    } catch (error) {
      if (mounted) showMessage(context, error, error: true);
    } finally {
      if (mounted) setState(() => categoryLoading = false);
    }
  }

  void _openHelp() {
    showDialog<void>(
      context: context,
      builder: (_) => _AiHelpDialog(
        controller: widget.controller,
        childId: widget.child.id,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.auto_awesome_rounded,
                    color: NigohDesign.violet,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      tr('NIGOH AI · қоидаҳои бехатар'),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                tr(
                  'Бо забони оддӣ нависед. AI танҳо пешниҳод мекунад; тағйирот пас аз тасдиқи шумо иҷро мешавад.',
                ),
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const ValueKey('ai-categories'),
                      onPressed: categoryLoading ? null : _previewCategories,
                      icon: categoryLoading
                          ? const SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.category_outlined),
                      label: Text(tr('Гурӯҳбандии барномаҳо')),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.outlined(
                    key: const ValueKey('ai-help'),
                    tooltip: tr('Савол ба NIGOH AI'),
                    onPressed: _openHelp,
                    icon: const Icon(Icons.help_outline_rounded),
                  ),
                ],
              ),
              if (categoryPreview.isNotEmpty) ...[
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          tr(
                            '{count} категория пешниҳод шуд. Пеш аз нигоҳдорӣ шумо тасдиқ мекунед.',
                            {'count': categoryPreview.length},
                          ),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton(
                          key: const ValueKey('ai-apply-categories'),
                          onPressed: categoryLoading ? null : _applyCategories,
                          child: Text(tr('Тасдиқ ва нигоҳ доштан')),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              TextField(
                key: const ValueKey('ai-rule-input'),
                controller: input,
                minLines: 3,
                maxLines: 6,
                maxLength: 1000,
                decoration: InputDecoration(
                  hintText: tr(
                    'Мисол: рӯзҳои дарсӣ бозиҳо 1 соат, баъди 21:00 баста шаванд',
                  ),
                ),
              ),
              FilledButton.icon(
                key: const ValueKey('ai-generate-rules'),
                onPressed: loading || applying ? null : _generate,
                icon: loading
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome_rounded),
                label: Text(tr('Пешниҳод сохтан')),
              ),
              if (proposal != null) ...[
                const SizedBox(height: 16),
                Text(
                  proposal!['summary']?.toString() ?? '',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                for (final action in _actions)
                  _AiActionTile(
                    action: action,
                    app: _app(action['package_name']?.toString() ?? ''),
                  ),
                const SizedBox(height: 10),
                FilledButton.icon(
                  key: const ValueKey('ai-apply-rules'),
                  onPressed: applying || _actions.isEmpty ? null : _apply,
                  icon: applying
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_rounded),
                  label: Text(
                    tr('Тасдиқ ва татбиқ ({count})', {
                      'count': _actions.length,
                    }),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AiHelpDialog extends StatefulWidget {
  const _AiHelpDialog({required this.controller, required this.childId});

  final FamilyController controller;
  final int childId;

  @override
  State<_AiHelpDialog> createState() => _AiHelpDialogState();
}

class _AiHelpDialogState extends State<_AiHelpDialog> {
  final input = TextEditingController();
  String? answer;
  bool loading = false;

  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  Future<void> _ask() async {
    if (input.text.trim().length < 3) return;
    setState(() => loading = true);
    try {
      final response = await widget.controller.api.aiHelp(
        widget.childId,
        input.text.trim(),
      );
      if (mounted) setState(() => answer = response['answer']?.toString());
    } catch (error) {
      if (mounted) showMessage(context, error, error: true);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(tr('Савол ба NIGOH AI')),
    content: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 440),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: const ValueKey('ai-help-input'),
              controller: input,
              minLines: 2,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: tr('Мисол: чӣ тавр лимити яксоата гузорам?'),
              ),
            ),
            if (answer != null) ...[const SizedBox(height: 12), Text(answer!)],
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(tr('Пӯшидан')),
      ),
      FilledButton(
        key: const ValueKey('ai-help-send'),
        onPressed: loading ? null : _ask,
        child: loading
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(tr('Пурсидан')),
      ),
    ],
  );
}

class _AiActionTile extends StatelessWidget {
  const _AiActionTile({required this.action, required this.app});

  final Map<String, dynamic> action;
  final ChildApp? app;

  @override
  Widget build(BuildContext context) {
    final changes = <String>[
      if (action['is_blocked'] is bool)
        action['is_blocked'] == true ? tr('баста') : tr('кушода'),
      if (action['daily_limit_minutes'] is num)
        tr('{count} дақ дар рӯз', {
          'count': (action['daily_limit_minutes'] as num).toInt(),
        }),
      if (action['schedule'] is Map)
        '${action['schedule']['start']}–${action['schedule']['end']}',
    ];
    return Card(
      child: ListTile(
        leading: NigohAppIcon(
          icon: app?.iconBase64 ?? '',
          seed: action['package_name']?.toString() ?? '',
          size: 38,
        ),
        title: Text(app?.name ?? action['package_name']?.toString() ?? ''),
        subtitle: Text(
          [
            changes.join(' · '),
            if ((action['reason']?.toString() ?? '').isNotEmpty)
              action['reason'].toString(),
          ].where((text) => text.isNotEmpty).join('\n'),
        ),
      ),
    );
  }
}
