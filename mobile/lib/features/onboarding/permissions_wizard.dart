// Файл: роҳнамои пайдарпайи иҷозатҳои барнома.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../ui/nigoh_design.dart';
import '../../ui/widgets.dart';
import 'permission_steps.dart';
import '../../l10n/l10n.dart';

export 'permission_steps.dart' show WizardStepId, wizardStepsFor;

/// Додаҳо ва рафтори марбут ба роҳнамои пайдарпайи иҷозатҳои барномаро ифода мекунад.
class PermissionsWizard extends StatefulWidget {
  const PermissionsWizard({
    super.key,
    required this.childMode,
    this.onDone,
    this.actions = const WizardActions(),
    this.advanceDelay = const Duration(milliseconds: 900),
  });

  final bool childMode;

  /// Қимати onDone-ро барои роҳнамои пайдарпайи иҷозатҳои барнома нигоҳ медорад.
  final VoidCallback? onDone;
  final WizardActions actions;

  /// Қимати advanceDelay-ро барои роҳнамои пайдарпайи иҷозатҳои барнома нигоҳ медорад.
  final Duration advanceDelay;

  /// Қимати shownThisSession-ро барои роҳнамои пайдарпайи иҷозатҳои барнома нигоҳ медорад.
  static bool shownThisSession = false;

  /// doneKey мантиқи зарурии роҳнамои пайдарпайи иҷозатҳои барномаро иҷро мекунад.
  static String doneKey(String role) => 'nigoh.wizard_done.$role';

  /// isDone иҷро шудани шарти вобастаро муайян мекунад.
  static Future<bool> isDone(String role) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(doneKey(role)) ?? false;
  }

  /// markDone дархостро ба API мефиристад ва натиҷаро коркард мекунад.
  static Future<void> markDone(String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(doneKey(role), true);
  }

  /// open экран ё dialog-и лозими иҷозатҳои Android-ро мекушояд.
  static Future<void> open(BuildContext context, {required bool childMode}) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PermissionsWizard(childMode: childMode),
        ),
      );

  /// Ҳолати PermissionsWizard-ро барои қадамҳои додани иҷозатҳои Android месозад.
  @override
  State<PermissionsWizard> createState() => _PermissionsWizardState();
}

/// Ҳолат ва рафтори PermissionsWizardState-ро барои навсозии интерфейс идора мекунад.
class _PermissionsWizardState extends State<PermissionsWizard>
    with WidgetsBindingObserver {
  late final List<WizardStepId> steps = wizardStepsFor(
    childMode: widget.childMode,
  );
  final statuses = <WizardStepId, StepStatus>{};

  /// Қимати attempted-ро барои роҳнамои пайдарпайи иҷозатҳои барнома нигоҳ медорад.
  final attempted = <String>{};

  bool loaded = false;
  String? loadError;
  String? stepError;
  bool busy = false;
  bool helpOpen = false;
  bool finishing = false;
  int index = 0;
  int direction = 1;
  Timer? advanceTimer;

  /// Қимати ҳисобшудаи onSummary-ро аз ҳолати ҷорӣ бармегардонад.
  bool get onSummary => index >= steps.length;
  /// Қимати ҳисобшудаи currentId-ро аз ҳолати ҷорӣ бармегардонад.
  WizardStepId? get currentId => onSummary ? null : steps[index];
  /// Қимати ҳисобшудаи role-ро аз ҳолати ҷорӣ бармегардонад.
  String get role => widget.childMode ? 'child' : 'parent';

  /// Wizard-ро барои session қайд карда, вазъи иҷозатҳои Android-ро мехонад.
  @override
  void initState() {
    super.initState();
    PermissionsWizard.shownThisSession = true;
    WidgetsBinding.instance.addObserver(this);
    refresh(initial: true);
  }

  /// Controller ва listener-ҳои PermissionsWizard-ро озод мекунад.
  @override
  void dispose() {
    advanceTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Ба тағйири lifecycle-и PermissionsWizard ҷавоб медиҳад.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) refresh();
  }

  /// refresh додаҳои иҷозатҳои Android-ро боз мехонад ва PermissionsWizard-ро нав мекунад.
  Future<void> refresh({bool initial = false}) async {
    final watched = currentId;
    final wasGranted = watched == null ? null : statuses[watched]?.granted;
    try {
      final result = await widget.actions.readAll(steps);
      if (!mounted) return;
      setState(() {
        statuses
          ..clear()
          ..addAll(result);
        loaded = true;
        loadError = null;
        if (initial) {
          final first = steps.indexWhere((id) => result[id]?.granted != true);
          index = first < 0 ? steps.length : first;
        }
      });
      if (!initial &&
          watched != null &&
          watched == currentId &&
          wasGranted == false &&
          result[watched]?.granted == true) {
        scheduleAdvance(watched);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loaded = true;
        loadError = tr('Ҳолати иҷозатҳо санҷида нашуд: {error}', {
          'error': wizardErrorText(e),
        });
      });
    }
  }

  /// scheduleAdvance раванди лозимро оғоз ва захираҳои вобастаро фаъол мекунад.
  void scheduleAdvance(WizardStepId id) {
    advanceTimer?.cancel();
    advanceTimer = Timer(widget.advanceDelay, () {
      if (mounted && currentId == id) go(index + 1);
    });
  }

  /// go экран, dialog ё танзимоти мувофиқро мекушояд.
  void go(int target) {
    advanceTimer?.cancel();
    final next = target.clamp(0, steps.length);
    setState(() {
      direction = next >= index ? 1 : -1;
      index = next;
      helpOpen = false;
      stepError = null;
    });
    if (onSummary) refresh();
  }

  /// run мантиқи зарурии роҳнамои пайдарпайи иҷозатҳои барномаро иҷро мекунад.
  Future<void> run(Future<void> Function() action, {String? attemptKey}) async {
    if (busy) return;
    setState(() {
      busy = true;
      stepError = null;
    });
    try {
      await action();
    } catch (e) {
      final text = wizardErrorText(e);
      if (mounted) setState(() => stepError = text);
    } finally {
      if (attemptKey != null) attempted.add(attemptKey);
      if (mounted) setState(() => busy = false);
    }
    await refresh();
  }

  /// finish мантиқи зарурии роҳнамои пайдарпайи иҷозатҳои барномаро иҷро мекунад.
  Future<void> finish() async {
    if (finishing) return;
    setState(() => finishing = true);
    try {
      await PermissionsWizard.markDone(role);
    } catch (e) {
      if (mounted) {
        showMessage(
          context,
          tr('Нигоҳ доштани ҳолат нашуд: {error}', {
            'error': wizardErrorText(e),
          }),
          error: true,
        );
      }
    }
    if (!mounted) return;
    setState(() => finishing = false);
    final onDone = widget.onDone;
    if (onDone != null) {
      onDone();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  /// attemptKeyOf мантиқи зарурии роҳнамои пайдарпайи иҷозатҳои барномаро иҷро мекунад.
  String attemptKeyOf(WizardStepId id, StepStatus status) =>
      '${id.name}.${status.stage.name}';

  /// Қадами ҷории иҷозатҳои Android-ро бо шарҳ ва тугмаи амал нишон медиҳад.
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (!loaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final id = currentId;
    final status = id == null ? null : statuses[id];
    final granted = status?.granted ?? false;
    final step = id == null
        ? null
        : status?.stage == StepStage.always
        ? WizardStep.locationAlways
        : WizardStep.of(id);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      onSummary
                          ? tr('Ҷамъбаст')
                          : tr('Қадами {step} аз {total}', {
                              'step': index + 1,
                              'total': steps.length,
                            }),
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (!onSummary)
                    TextButton(
                      key: const Key('wizard-close'),
                      onPressed: finishing ? null : finish,
                      child: Text(tr('Пӯшидан')),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
              child: _ProgressDots(
                count: steps.length,
                index: index,
                color: step?.color ?? NigohDesign.mint,
                done: [for (final s in steps) statuses[s]?.granted == true],
              ),
            ),
            AnimatedSize(
              duration: reducedMotion(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: index == 0 && !onSummary
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                      child: ScreenHint(
                        tr(
                          'Иҷозатҳоро як бор медиҳед — баъд NIGOH дар пасзамина кор мекунад. Ҳар қадамро гузаронидан мумкин аст.',
                        ),
                        icon: Icons.info_outline_rounded,
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
            if (loadError != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: _ErrorBanner(text: loadError!, onRetry: refresh),
              ),
            Expanded(
              child: AnimatedSwitcher(
                duration: reducedMotion(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 320),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) {
                  final incoming = child.key == ValueKey('page-$index');
                  final dx = (incoming ? 1 : -1) * direction * 0.18;
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween(
                        begin: Offset(dx, 0),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: KeyedSubtree(
                  key: ValueKey('page-$index'),
                  child: id == null
                      ? _SummaryPage(
                          steps: steps,
                          statuses: statuses,
                          onOpen: (i) => go(i),
                        )
                      : _StepPage(
                          step: step!,
                          status: status ?? const StepStatus(granted: false),
                          busy: busy,
                          error: stepError,
                          helpOpen: helpOpen,
                          showFallback:
                              status != null &&
                              !status.granted &&
                              (status.blocked ||
                                  attempted.contains(attemptKeyOf(id, status))),
                          onGrant: () => run(
                            () => widget.actions.grant(
                              id,
                              status ?? const StepStatus(granted: false),
                            ),
                            attemptKey: attemptKeyOf(
                              id,
                              status ?? const StepStatus(granted: false),
                            ),
                          ),
                          onFallback: () =>
                              run(() => widget.actions.openFallback(id)),
                          onOpenGps: () =>
                              run(widget.actions.openLocationSettings),
                          onToggleHelp: () =>
                              setState(() => helpOpen = !helpOpen),
                          onAppInfo: () => run(widget.actions.openAppInfo),
                        ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: onSummary
                  ? SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: FilledButton(
                        key: const Key('wizard-finish'),
                        onPressed: finishing ? null : finish,
                        child: Text(tr('Ба барнома')),
                      ),
                    )
                  : Row(
                      children: [
                        if (index > 0)
                          IconButton(
                            tooltip: tr('Бозгашт'),
                            onPressed: () => go(index - 1),
                            icon: const Icon(Icons.arrow_back_rounded),
                          ),
                        TextButton(
                          key: const Key('wizard-later'),
                          style: TextButton.styleFrom(
                            foregroundColor: scheme.onSurfaceVariant,
                          ),
                          onPressed: () => go(index + 1),
                          child: Text(tr('Баъдтар')),
                        ),
                        const Spacer(),
                        AnimatedOpacity(
                          duration: const Duration(milliseconds: 200),
                          opacity: granted ? 1 : 0,
                          child: FilledButton.icon(
                            key: const Key('wizard-next'),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(120, 52),
                            ),
                            onPressed: granted ? () => go(index + 1) : null,
                            icon: const Icon(Icons.arrow_forward_rounded),
                            label: Text(tr('Идома')),
                          ),
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

/// Додаҳо ва рафтори марбут ба роҳнамои пайдарпайи иҷозатҳои барномаро ифода мекунад.
class _ProgressDots extends StatelessWidget {
  const _ProgressDots({
    required this.count,
    required this.index,
    required this.color,
    required this.done,
  });

  final int count;
  final int index;
  final Color color;
  final List<bool> done;

  /// Widget-и ProgressDots-ро барои қадамҳои додани иҷозатҳои Android месозад.
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        for (var i = 0; i < count; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            flex: i == index ? 3 : 1,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              height: 6,
              decoration: BoxDecoration(
                color: i == index
                    ? color
                    : done[i]
                    ? NigohDesign.mint.withValues(alpha: .55)
                    : scheme.outlineVariant,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Widget-и IconTile-ро барои роҳнамои пайдарпайи иҷозатҳои барнома месозад.
class _IconTile extends StatelessWidget {
  const _IconTile({
    required this.icon,
    required this.color,
    this.size = 104,
    this.badge,
  });
  final IconData icon;
  final Color color;
  final double size;
  final Widget? badge;

  /// Widget-и IconTile-ро барои қадамҳои додани иҷозатҳои Android месозад.
  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color.withValues(alpha: .13),
          borderRadius: BorderRadius.circular(size * .3),
        ),
        child: Icon(icon, color: color, size: size * .48),
      ),
      if (badge != null) Positioned(right: -6, bottom: -6, child: badge!),
    ],
  );
}

/// Экрани StepPage-ро барои роҳнамои пайдарпайи иҷозатҳои барнома месозад.
class _StepPage extends StatelessWidget {
  const _StepPage({
    required this.step,
    required this.status,
    required this.busy,
    required this.error,
    required this.helpOpen,
    required this.showFallback,
    required this.onGrant,
    required this.onFallback,
    required this.onOpenGps,
    required this.onToggleHelp,
    required this.onAppInfo,
  });

  final WizardStep step;
  final StepStatus status;
  final bool busy;
  final String? error;
  final bool helpOpen;
  final bool showFallback;
  final VoidCallback onGrant;
  final VoidCallback onFallback;
  final VoidCallback onOpenGps;
  final VoidCallback onToggleHelp;

  /// Саҳифаи маълумоти барномаро мекушояд (барои қадамҳои бо маҳдудият).
  final VoidCallback onAppInfo;

  /// Widget-и StepPage-ро барои қадамҳои додани иҷозатҳои Android месозад.
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final granted = status.granted;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
      children: [
        FadeIn(
          child: Center(
            child: _IconTile(
              icon: step.icon,
              color: step.color,
              badge: AnimatedScale(
                scale: granted ? 1 : 0,
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutBack,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    color: NigohDesign.mint,
                    size: 32,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        FadeIn(
          index: 1,
          child: Text(
            step.title,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 10),
        FadeIn(
          index: 2,
          child: Text(
            step.reason,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ),
        const SizedBox(height: 24),
        if (status.gpsOff) ...[
          _Notice(
            icon: Icons.gps_off_rounded,
            color: NigohDesign.amber,
            text: tr('GPS (ҷойгиршавӣ) дар телефон хомӯш аст.'),
            action: TextButton(
              key: const Key('wizard-gps'),
              onPressed: busy ? null : onOpenGps,
              child: Text(tr('Фаъол кардан')),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (status.missingPrerequisites && !granted) ...[
          _Notice(
            icon: Icons.info_outline_rounded,
            color: NigohDesign.blue,
            text: tr(
              'Аввал «Дастрасӣ ба истифода» ва «Намоиш болои барномаҳо» лозим '
              'аст — тугма аввал ҳамонҳоро мекушояд.',
            ),
          ),
          const SizedBox(height: 12),
        ],
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          child: granted
              ? Container(
                  key: const ValueKey('granted'),
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: NigohDesign.mint.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_rounded, color: NigohDesign.mint),
                      SizedBox(width: 8),
                      Text(
                        tr('Иҷозат дода шуд'),
                        style: TextStyle(
                          color: NigohDesign.mint,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                )
              : SizedBox(
                  key: const ValueKey('grant'),
                  height: 56,
                  width: double.infinity,
                  child: FilledButton(
                    key: const Key('wizard-grant'),
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    onPressed: busy ? null : onGrant,
                    child: busy
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.4),
                          )
                        : Text(tr('Иҷозат додан')),
                  ),
                ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: showFallback
              ? Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      key: const Key('wizard-fallback'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        foregroundColor: NigohDesign.amber,
                        backgroundColor: NigohDesign.amber.withValues(
                          alpha: .10,
                        ),
                        side: BorderSide(
                          color: NigohDesign.amber.withValues(alpha: .55),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      onPressed: busy ? null : onFallback,
                      icon: const Icon(Icons.settings_outlined),
                      label: Text(
                        tr('Иҷозат дода нашуд? Танзимоти Android-ро кушоед'),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
        if (usesRestrictedSettings(step.id) && !status.granted) ...[
          const SizedBox(height: 14),
          _RestrictedSettingsCard(onAppInfo: busy ? null : onAppInfo),
        ],
        if (error != null) ...[
          const SizedBox(height: 10),
          Text(
            error!,
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.error),
          ),
        ],
        const SizedBox(height: 20),
        FadeIn(
          index: 3,
          child: _HelpCard(
            open: helpOpen,
            items: step.help,
            onToggle: onToggleHelp,
          ),
        ),
      ],
    );
  }
}

/// Додаҳо ва рафтори марбут ба роҳнамои пайдарпайи иҷозатҳои барномаро ифода мекунад.
class _Notice extends StatelessWidget {
  const _Notice({
    required this.icon,
    required this.color,
    required this.text,
    this.action,
  });
  final IconData icon;
  final Color color;
  final String text;
  final Widget? action;

  /// Widget-и Notice-ро барои қадамҳои додани иҷозатҳои Android месозад.
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 10),
        Expanded(child: Text(text)),
        ?action,
      ],
    ),
  );
}

/// Widget-и HelpCard-ро барои роҳнамои пайдарпайи иҷозатҳои барнома месозад.
class _HelpCard extends StatelessWidget {
  const _HelpCard({
    required this.open,
    required this.items,
    required this.onToggle,
  });
  final bool open;
  final List<String> items;
  final VoidCallback onToggle;

  /// Widget-и HelpCard-ро барои қадамҳои додани иҷозатҳои Android месозад.
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            key: const Key('wizard-help'),
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.help_outline_rounded,
                      color: scheme.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr('Чӣ бояд кард?'),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          tr('Дастури қадам ба қадам'),
                          style: TextStyle(
                            fontSize: 13,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: open ? .5 : 0,
                    duration: const Duration(milliseconds: 240),
                    child: const Icon(Icons.expand_more_rounded),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: open
                ? Padding(
                    key: const Key('wizard-help-body'),
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      children: [
                        for (var i = 0; i < items.length; i++)
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 24,
                                  height: 24,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: scheme.primary.withValues(
                                      alpha: .12,
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    '${i + 1}',
                                    style: TextStyle(
                                      color: scheme.primary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    items[i],
                                    style: const TextStyle(height: 1.35),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

/// Экрани SummaryPage-ро барои роҳнамои пайдарпайи иҷозатҳои барнома месозад.
class _SummaryPage extends StatelessWidget {
  const _SummaryPage({
    required this.steps,
    required this.statuses,
    required this.onOpen,
  });
  final List<WizardStepId> steps;
  final Map<WizardStepId, StepStatus> statuses;
  final ValueChanged<int> onOpen;

  /// Widget-и SummaryPage-ро барои қадамҳои додани иҷозатҳои Android месозад.
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final missing = steps.where((id) => statuses[id]?.granted != true).length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
      children: [
        FadeIn(
          child: Center(
            child: _IconTile(
              icon: missing == 0
                  ? Icons.verified_rounded
                  : Icons.playlist_add_check_rounded,
              color: missing == 0 ? NigohDesign.mint : NigohDesign.amber,
            ),
          ),
        ),
        const SizedBox(height: 24),
        FadeIn(
          index: 1,
          child: Text(
            missing == 0 ? tr('Ҳамааш тайёр') : tr('Якчанд иҷозат мондааст'),
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 10),
        FadeIn(
          index: 2,
          child: Text(
            missing == 0
                ? tr(
                    'Ҳамаи иҷозатҳо дода шуданд. NIGOH Family пурра кор мекунад.',
                  )
                : tr(
                    '{count} иҷозат ҳоло дода нашудааст. Барои танзим ба он пахш кунед.',
                    {'count': missing},
                  ),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(height: 20),
        FadeIn(
          index: 3,
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < steps.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  _SummaryRow(
                    step: WizardStep.of(steps[i]),
                    granted: statuses[steps[i]]?.granted == true,
                    onTap: () => onOpen(i),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Widget-и SummaryRow-ро барои роҳнамои пайдарпайи иҷозатҳои барнома месозад.
class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.step,
    required this.granted,
    required this.onTap,
  });
  final WizardStep step;
  final bool granted;
  final VoidCallback onTap;

  /// Widget-и SummaryRow-ро барои қадамҳои додани иҷозатҳои Android месозад.
  @override
  Widget build(BuildContext context) => ListTile(
    key: Key('wizard-summary-${step.id.name}'),
    onTap: onTap,
    leading: _IconTile(icon: step.icon, color: step.color, size: 40),
    title: Text(
      step.summaryTitle,
      style: const TextStyle(fontWeight: FontWeight.w600),
    ),
    subtitle: granted ? null : Text(tr('Дода нашудааст — пахш кунед')),
    trailing: granted
        ? const Icon(Icons.check_circle_rounded, color: NigohDesign.mint)
        : Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: NigohDesign.amber.withValues(alpha: .18),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.priority_high_rounded,
              color: NigohDesign.amber,
              size: 18,
            ),
          ),
  );
}

/// Widget-и ErrorBanner-ро барои роҳнамои пайдарпайи иҷозатҳои барнома месозад.
class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.text, required this.onRetry});
  final String text;
  final VoidCallback onRetry;

  /// Widget-и ErrorBanner-ро барои қадамҳои додани иҷозатҳои Android месозад.
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: scheme.onErrorContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: TextStyle(color: scheme.onErrorContainer)),
          ),
          TextButton(onPressed: onRetry, child: Text(tr('Аз нав'))),
        ],
      ),
    );
  }
}

/// Корти ёрирасон барои қадамҳое, ки Android бо «Controlled by restricted setting»
/// мебандад: тугмаи «App info» ва чор қадами рақамдор, ки чӣ тавр иҷозати маҳдудшударо
/// барои NIGOH Family дар Android 13+ фаъол кардан мумкин аст.
class _RestrictedSettingsCard extends StatelessWidget {
  const _RestrictedSettingsCard({required this.onAppInfo});

  /// Пахши тугмаи «App info»; ҳангоми кор `null` (тугма хомӯш мешавад).
  final VoidCallback? onAppInfo;

  /// Кортро бо сарлавҳа, чор қадами рақамдор, эзоҳ ва тугмаи «App info» месозад.
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final steps = [
      tr('Тугмаи «App info»-ро пахш кунед — саҳифаи маълумоти NIGOH Family кушода мешавад.'),
      tr('Дар кунҷи рости боло ⋮ (се нуқта)-ро пахш кунед.'),
      tr('«Разрешить ограниченные настройки»-ро интихоб кунед ва бо рамзи телефон тасдиқ намоед.'),
      tr('Ба NIGOH баргардед ва «Иҷозат додан»-ро аз нав пахш кунед.'),
    ];
    return Container(
      key: const Key('wizard-restricted'),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NigohDesign.violet.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: NigohDesign.violet.withValues(alpha: .35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lock_open_rounded, color: NigohDesign.violet),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  tr('Агар Android иҷозатро бо маҳдудият баста бошад'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < steps.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 11,
                    backgroundColor: NigohDesign.violet,
                    child: Text(
                      '${i + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(steps[i])),
                ],
              ),
            ),
          Text(
            tr('Агар дар менюи ⋮ ин банд набошад, аввал як бор «Иҷозат додан»-ро пахш кунед, баъд ин ҷо баргардед.'),
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              key: const Key('wizard-app-info'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: onAppInfo,
              icon: const Icon(Icons.more_vert_rounded),
              label: Text(tr('Кушодани App info')),
            ),
          ),
        ],
      ),
    );
  }
}
