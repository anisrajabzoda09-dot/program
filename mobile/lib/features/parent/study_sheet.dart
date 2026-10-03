// Файл: танзими реҷаи дарс.

import 'package:flutter/material.dart';

import '../../core/models.dart';
import '../../ui/nigoh_design.dart';
import '../../ui/widgets.dart';
import 'family_controller.dart';
import 'parent_sheets.dart';
import '../../l10n/l10n.dart';

/// Қимати studyWeekdayLabels-ро барои танзими реҷаи дарс нигоҳ медорад.
const studyWeekdayLabels = ['Дш', 'Сш', 'Чш', 'Пш', 'Ҷм', 'Шб', 'Яш'];

/// Қимати studyExplanation-ро барои танзими реҷаи дарс нигоҳ медорад.
String get studyExplanation => tr(
  'Бозиҳо, шабакаҳо ва видео дар соатҳои дарс баста мешаванд. Занг, SMS, барномаҳои таълимӣ ва «Ҳамеша иҷозат» кушода мемонанд.',
);

/// studyLabel мантиқи зарурии танзими реҷаи дарсро иҷро мекунад.
String studyLabel(StudyMode study) => study.enabled
    ? tr('Тамаркузи дарс: {start}–{end}', {
        'start': study.start,
        'end': study.end,
      })
    : tr('Тамаркузи дарс: хомӯш');

/// Равзанаи StudySheet-ро барои танзими реҷаи дарс нишон медиҳад.
class StudySheet extends StatefulWidget {
  const StudySheet({super.key, required this.controller, required this.child});

  final FamilyController controller;
  final FamilyChild child;

  /// Ҳолати StudySheet-ро барои танзими реҷаи дарс месозад.
  @override
  State<StudySheet> createState() => _StudySheetState();
}

/// Ҳолат ва рафтори StudySheetState-ро барои навсозии интерфейс идора мекунад.
class _StudySheetState extends State<StudySheet> {
  late bool enabled;
  late TimeOfDay start;
  late TimeOfDay end;
  late Set<int> weekdays;
  bool saving = false;

  /// Реҷаи дарси фарзандро ба вақт, ҳолати фаъол ва рӯзҳои интихобшуда мегузаронад.
  @override
  void initState() {
    super.initState();
    final s = widget.child.study;
    enabled = s.enabled;
    start = parseHhmm(s.start, const TimeOfDay(hour: 8, minute: 0));
    end = parseHhmm(s.end, const TimeOfDay(hour: 13, minute: 0));
    weekdays = {...s.weekdays};
  }

  /// pick мантиқи зарурии танзими реҷаи дарсро иҷро мекунад.
  Future<void> _pick(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? start : end,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() => isStart ? start = picked : end = picked);
  }

  /// save тағйироти реҷаи дарс-ро барои истифодаи баъдӣ нигоҳ медорад.
  Future<void> _save() async {
    final study = StudyMode(
      enabled: enabled,
      start: formatHhmm(start),
      end: formatHhmm(end),
      weekdays: weekdays.toList()..sort(),
    );
    setState(() => saving = true);
    try {
      await widget.controller.setStudyMode(widget.child, study);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => saving = false);
      showMessage(context, e, error: true);
    }
  }

  /// Танзими вақти оғоз, анҷом ва рӯзҳои реҷаи дарсро нишон медиҳад.
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final same = formatHhmm(start) == formatHhmm(end);
    final invalid = enabled && (same || weekdays.isEmpty);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr('Тамаркузи дарс'),
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              studyExplanation,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              key: const ValueKey('study-switch'),
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(
                Icons.school_rounded,
                color: NigohDesign.mint,
              ),
              title: Text(tr('Тамаркузи дарс фаъол')),
              subtitle: Text(
                enabled
                    ? tr('Дар рӯзҳо ва соатҳои зер кор мекунад')
                    : tr('Ҳоло тамаркузи дарс кор намекунад'),
              ),
              value: enabled,
              onChanged: (v) => setState(() => enabled = v),
            ),
            SectionTitle(tr('Соатҳои дарс')),
            Row(
              children: [
                Expanded(
                  child: TimeTile(
                    key: const ValueKey('study-start'),
                    label: tr('Аз соати'),
                    value: formatHhmm(start),
                    enabled: enabled,
                    onTap: () => _pick(true),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TimeTile(
                    key: const ValueKey('study-end'),
                    label: tr('То соати'),
                    value: formatHhmm(end),
                    enabled: enabled,
                    onTap: () => _pick(false),
                  ),
                ),
              ],
            ),
            SectionTitle(tr('Рӯзҳои ҳафта')),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (var day = 1; day <= 7; day++)
                  FilterChip(
                    key: ValueKey('study-day-$day'),
                    label: Text(tr(studyWeekdayLabels[day - 1])),
                    selected: weekdays.contains(day),
                    onSelected: enabled
                        ? (v) => setState(
                            () => v ? weekdays.add(day) : weekdays.remove(day),
                          )
                        : null,
                  ),
              ],
            ),
            if (enabled && (same || weekdays.isEmpty))
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  same
                      ? tr('Оғоз ва анҷом бояд гуногун бошанд.')
                      : tr('Ақаллан як рӯзро интихоб кунед.'),
                  style: TextStyle(color: scheme.error, fontSize: 12),
                ),
              ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const ValueKey('study-save'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                ),
                onPressed: saving || invalid ? null : _save,
                icon: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_rounded),
                label: Text(tr('Нигоҳ доштан')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
