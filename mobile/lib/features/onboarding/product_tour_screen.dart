import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../l10n/l10n.dart';
import '../../ui/nigoh_design.dart';
import '../../ui/widgets.dart';

class ProductTourScreen extends StatefulWidget {
  const ProductTourScreen({
    super.key,
    required this.identity,
    required this.onDone,
    this.replay = false,
  });

  final String identity;
  final Future<void> Function() onDone;
  final bool replay;

  static String _storageKey(String identity) =>
      'nigoh.product_tour.v1.${identity.trim().toLowerCase()}';

  static Future<bool> isDone(String identity) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_storageKey(identity)) ?? false;
  }

  static Future<void> markDone(String identity) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_storageKey(identity), true);
  }

  static Future<void> open(BuildContext context, {required String identity}) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (routeContext) => ProductTourScreen(
          identity: identity,
          replay: true,
          onDone: () async => Navigator.of(routeContext).pop(),
        ),
      ),
    );
  }

  @override
  State<ProductTourScreen> createState() => _ProductTourScreenState();
}

class _ProductTourScreenState extends State<ProductTourScreen>
    with SingleTickerProviderStateMixin {
  final PageController _pages = PageController();
  late final AnimationController _motion;
  int _page = 0;
  bool _finishing = false;

  static const _lessons = <_TourLesson>[
    _TourLesson(
      icon: Icons.family_restroom_rounded,
      title: 'Оилаатон — дар як нигоҳ',
      text: 'Телефони волидайнро бо телефони фарзанд пайваст кунед. Ҳолати муҳим бе кофтуков намоён мешавад.',
      points: [
        'Як аккаунт барои тамоми оила',
        'Батарея, онлайн будан ва огоҳиҳо',
      ],
    ),
    _TourLesson(
      icon: Icons.timer_outlined,
      title: 'Вақти барнома аниқ ҳисоб мешавад',
      text: 'Барои бозӣ ё шабакаи иҷтимоӣ масалан 1 соат гузоред. Танҳо вақти истифода ҳисоб мешавад.',
      points: [
        'Вақти пасзамина ҳисоб намешавад',
        'Бастан ва кушодан аз масофа',
      ],
    ),
    _TourLesson(
      icon: Icons.location_on_outlined,
      title: 'Минтақаи амн ва огоҳии фаврӣ',
      text: 'Дар атрофи хона ё мактаб масалан 100 метр минтақа созед. Ҳангоми расидан ё баромадан паём мегиред.',
      points: [
        'Харитаи зинда ва таърихи макон',
        'Қоидаи барномаҳо дар ҳамон минтақа',
      ],
    ),
    _TourLesson(
      icon: Icons.sos_rounded,
      title: 'Дар лаҳзаи муҳим канори ҳам',
      text: 'SOS, занг ва чат мустақиман ба оила мерасанд. Огоҳии SOS ҳатто дар экрани қулфшуда намоён мешавад.',
      points: ['Паём, занг ва SOS дар як ҷо', 'Макони фарзанд бо огоҳии фаврӣ'],
    ),
    _TourLesson(
      icon: Icons.auto_awesome_rounded,
      title: 'NIGOH AI — ёрдамчии шумо',
      text: 'Кулӯлаи AI-ро ба ҳар ҷои экран баред. Бипурсед, таҳлил гиред ё қоидаи барномаро бо тасдиқ тағйир диҳед.',
      points: [
        'Саволу ҷавоб дар бораи ҳолати оила',
        'Ҳеҷ фармон бе тасдиқ иҷро намешавад',
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _motion = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reducedMotion(context)) {
      _motion.stop();
      _motion.value = .5;
    } else if (!_motion.isAnimating) {
      _motion.repeat();
    }
  }

  @override
  void dispose() {
    _pages.dispose();
    _motion.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    if (_finishing) return;
    setState(() => _finishing = true);
    try {
      await ProductTourScreen.markDone(widget.identity);
      await widget.onDone();
    } finally {
      if (mounted) setState(() => _finishing = false);
    }
  }

  void _next() {
    if (_page == _lessons.length - 1) {
      _finish();
      return;
    }
    _pages.nextPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final compact = MediaQuery.sizeOf(context).height < 720;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: widget.replay,
        title: Text(tr('Шиносоӣ бо NIGOH')),
        actions: [
          if (!widget.replay && _page < _lessons.length - 1)
            TextButton(
              key: const ValueKey('tour-skip'),
              onPressed: _finishing ? null : _finish,
              child: Text(tr('Гузаштан')),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        key: const ValueKey('tour-progress'),
                        minHeight: 5,
                        value: (_page + 1) / _lessons.length,
                        backgroundColor: scheme.surfaceContainerHighest,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${_page + 1}/${_lessons.length}',
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                key: const ValueKey('product-tour-pages'),
                controller: _pages,
                itemCount: _lessons.length,
                onPageChanged: (value) => setState(() => _page = value),
                itemBuilder: (context, index) => _LessonPage(
                  lesson: _lessons[index],
                  index: index,
                  animation: _motion,
                  compact: compact,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Row(
                children: [
                  if (_page > 0)
                    IconButton.filledTonal(
                      key: const ValueKey('tour-back'),
                      tooltip: tr('Қафо'),
                      onPressed: () => _pages.previousPage(
                        duration: const Duration(milliseconds: 280),
                        curve: Curves.easeOutCubic,
                      ),
                      icon: const Icon(Icons.arrow_back_rounded),
                    )
                  else
                    const SizedBox(width: 48),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      key: const ValueKey('tour-next'),
                      onPressed: _finishing ? null : _next,
                      icon: _finishing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              _page == _lessons.length - 1
                                  ? Icons.check_rounded
                                  : Icons.arrow_forward_rounded,
                            ),
                      label: Text(
                        tr(
                          _page == _lessons.length - 1
                              ? 'Оғоз мекунем'
                              : 'Баъдӣ',
                        ),
                      ),
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

class _TourLesson {
  const _TourLesson({
    required this.icon,
    required this.title,
    required this.text,
    required this.points,
  });

  final IconData icon;
  final String title;
  final String text;
  final List<String> points;
}

class _LessonPage extends StatelessWidget {
  const _LessonPage({
    required this.lesson,
    required this.index,
    required this.animation,
    required this.compact,
  });

  final _TourLesson lesson;
  final int index;
  final Animation<double> animation;
  final bool compact;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TourVisual(
            index: index,
            animation: animation,
            height: compact ? 210 : 270,
          ),
          SizedBox(height: compact ? 16 : 24),
          Row(
            children: [
              Icon(lesson.icon, size: 22),
              const SizedBox(width: 9),
              Text(
                tr('Дарси зинда'),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            tr(lesson.title),
            style: const TextStyle(
              fontSize: 25,
              height: 1.12,
              letterSpacing: -.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            tr(lesson.text),
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 15,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          for (final point in lesson.points)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(Icons.check_circle_rounded, size: 18),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(tr(point), style: const TextStyle(height: 1.3)),
                  ),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}

class _TourVisual extends StatelessWidget {
  const _TourVisual({
    required this.index,
    required this.animation,
    required this.height,
  });

  final int index;
  final Animation<double> animation;
  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: .7)),
      ),
      clipBehavior: Clip.antiAlias,
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, _) {
          final pulse = (math.sin(animation.value * math.pi * 2) + 1) / 2;
          return switch (index) {
            0 => _FamilyVisual(pulse: pulse),
            1 => _AppsVisual(pulse: pulse),
            2 => _MapVisual(pulse: pulse),
            3 => _SafetyVisual(pulse: pulse),
            _ => _AiVisual(pulse: pulse),
          };
        },
      ),
    );
  }
}

class _FamilyVisual extends StatelessWidget {
  const _FamilyVisual({required this.pulse});
  final double pulse;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 128 + pulse * 12,
          height: 128 + pulse * 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: scheme.primary.withValues(alpha: .07),
          ),
        ),
        const _Phone(icon: Icons.family_restroom_rounded, label: 'NIGOH'),
        Positioned(
          left: 24,
          top: 34 + pulse * 8,
          child: const _Bubble(icon: Icons.person_rounded, label: 'Волид'),
        ),
        Positioned(
          right: 22,
          bottom: 28 + pulse * 8,
          child: const _Bubble(
            icon: Icons.child_care_rounded,
            label: 'Фарзанд',
          ),
        ),
      ],
    );
  }
}

class _AppsVisual extends StatelessWidget {
  const _AppsVisual({required this.pulse});
  final double pulse;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _AppRow(
            icon: Icons.sports_esports_rounded,
            title: 'Бозӣ',
            value: '${(38 + pulse * 22).round()} / 60 дақ',
            progress: .63 + pulse * .25,
          ),
          const SizedBox(height: 6),
          const _AppRow(
            icon: Icons.play_circle_outline_rounded,
            title: 'Video',
            value: 'Кушода',
            progress: .34,
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(99),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_clock_rounded, size: 18),
                SizedBox(width: 7),
                Text(
                  '60 дақиқа • автоматӣ',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MapVisual extends StatelessWidget {
  const _MapVisual({required this.pulse});
  final double pulse;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final size = 118 + pulse * 20;
    return Stack(
      alignment: Alignment.center,
      children: [
        Transform.rotate(
          angle: -.15,
          child: Icon(
            Icons.route_rounded,
            size: 210,
            color: scheme.outlineVariant,
          ),
        ),
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: scheme.primary.withValues(alpha: .09),
            border: Border.all(
              color: scheme.primary.withValues(alpha: .4),
              width: 2,
            ),
          ),
        ),
        const _Bubble(icon: Icons.school_rounded, label: '100 м'),
        Positioned(
          right: 22,
          top: 22 + pulse * 5,
          child: const _Notice(
            icon: Icons.notifications_active_rounded,
            text: 'Ба мактаб расид',
          ),
        ),
      ],
    );
  }
}

class _SafetyVisual extends StatelessWidget {
  const _SafetyVisual({required this.pulse});
  final double pulse;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 96 + pulse * 16,
          height: 96 + pulse * 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: scheme.error.withValues(alpha: .1),
          ),
        ),
        Container(
          width: 74,
          height: 74,
          decoration: BoxDecoration(
            color: scheme.error,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            'SOS',
            style: TextStyle(
              color: scheme.onError,
              fontWeight: FontWeight.w900,
              fontSize: 20,
            ),
          ),
        ),
        Positioned(
          left: 24,
          top: 34,
          child: _Bubble(icon: Icons.call_rounded, label: tr('Занг')),
        ),
        Positioned(
          right: 22,
          bottom: 32,
          child: _Bubble(icon: Icons.chat_bubble_rounded, label: tr('Чат')),
        ),
      ],
    );
  }
}

class _AiVisual extends StatelessWidget {
  const _AiVisual({required this.pulse});
  final double pulse;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Positioned(
        left: 24,
        right: 70,
        top: 36,
        child: _Notice(
          icon: Icons.person_outline_rounded,
          text: tr('Бозиро 1 соат кун'),
        ),
      ),
      Positioned(
        left: 64,
        right: 24,
        top: 102,
        child: _Notice(
          icon: Icons.auto_awesome_rounded,
          text: tr('Қоида омода аст • тасдиқ?'),
        ),
      ),
      Positioned(
        right: 20 + pulse * 10,
        bottom: 18 + pulse * 6,
        child: Container(
          width: 58,
          height: 58,
          decoration: const BoxDecoration(
            color: NigohDesign.navy,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.auto_awesome_rounded, color: Colors.white),
        ),
      ),
    ],
  );
}

class _Phone extends StatelessWidget {
  const _Phone({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    width: 96,
    height: 166,
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: .08),
          blurRadius: 18,
          offset: const Offset(0, 9),
        ),
      ],
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 34),
        const SizedBox(height: 10),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 14),
        Container(
          width: 44,
          height: 5,
          decoration: BoxDecoration(
            color: NigohDesign.mint,
            borderRadius: BorderRadius.circular(99),
          ),
        ),
      ],
    ),
  );
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: .07),
          blurRadius: 12,
          offset: const Offset(0, 6),
        ),
      ],
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 19),
        const SizedBox(width: 7),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    ),
  );
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: .06),
          blurRadius: 12,
          offset: const Offset(0, 5),
        ),
      ],
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            text,
            maxLines: 2,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
}

class _AppRow extends StatelessWidget {
  const _AppRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.progress,
  });
  final IconData icon;
  final String title;
  final String value;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(icon),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Text(
                      value,
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: LinearProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    minHeight: 5,
                    backgroundColor: scheme.surfaceContainerHighest,
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
