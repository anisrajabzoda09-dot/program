import 'package:flutter/material.dart';

import '../../core/models.dart';
import '../../ui/widgets.dart';
import 'family_controller.dart';
import 'parent_sheets.dart';

/// Short weekday labels, Monday (1) … Sunday (7).
const studyWeekdayLabels = ['Дш', 'Сш', 'Чш', 'Пш', 'Ҷм', 'Шб', 'Яш'];

/// Explanation shown in the sheet.
const studyExplanation =
    'Бозиҳо, шабакаҳо ва видео дар соатҳои дарс баста мешаванд. Занг, SMS, '
    'барномаҳои таълимӣ ва «Ҳамеша иҷозат» кушода мемонанд.';

/// «Тамаркузи дарс: 08:00–13:00» (or «хомӯш»).
String studyLabel(StudyMode study) => study.enabled
    ? 'Тамаркузи дарс: ${study.start}–${study.end}'
    : 'Тамаркузи дарс: хомӯш';

/// «Тамаркузи дарс»: switch, start/end and weekdays. Saves through the
/// controller and closes with `true`; errors are shown and the sheet stays.
class StudySheet extends StatefulWidget {
  const StudySheet({super.key, required this.controller, required this.child});

  final FamilyController controller;
  final FamilyChild child;

  @override
  State<StudySheet> createState() => _StudySheetState();
}

class _StudySheetState extends State<StudySheet> {
  late bool enabled;
  late TimeOfDay start;
  late TimeOfDay end;
  late Set<int> weekdays;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    final s = widget.child.study;
    enabled = s.enabled;
    start = parseHhmm(s.start, const TimeOfDay(hour: 8, minute: 0));
    end = parseHhmm(s.end, const TimeOfDay(hour: 13, minute: 0));
    weekdays = {...s.weekdays};
  }

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
            const Text(
              'Тамаркузи дарс',
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
              title: const Text('Тамаркузи дарс фаъол'),
              value: enabled,
              onChanged: (v) => setState(() => enabled = v),
            ),
            Row(
              children: [
                Expanded(
                  child: TimeTile(
                    key: const ValueKey('study-start'),
                    label: 'Оғоз',
                    value: formatHhmm(start),
                    enabled: enabled,
                    onTap: () => _pick(true),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TimeTile(
                    key: const ValueKey('study-end'),
                    label: 'Анҷом',
                    value: formatHhmm(end),
                    enabled: enabled,
                    onTap: () => _pick(false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (var day = 1; day <= 7; day++)
                  FilterChip(
                    key: ValueKey('study-day-$day'),
                    label: Text(studyWeekdayLabels[day - 1]),
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
                      ? 'Оғоз ва анҷом бояд гуногун бошанд.'
                      : 'Ақаллан як рӯзро интихоб кунед.',
                  style: TextStyle(color: scheme.error, fontSize: 12),
                ),
              ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const ValueKey('study-save'),
                onPressed: saving || invalid ? null : _save,
                child: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Нигоҳ доштан'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
