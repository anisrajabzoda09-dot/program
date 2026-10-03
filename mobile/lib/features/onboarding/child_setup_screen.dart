// One-time child profile form (name, gender, age) shown on the child phone
// before pairing.

import 'package:flutter/material.dart';

import '../../core/child_profile.dart';
import '../../core/session.dart';
import '../../ui/nigoh_design.dart';
import '../../ui/widgets.dart';
import '../../l10n/l10n.dart';

/// Child enters name, gender and age once on this phone. Calls [onDone]
/// with the saved profile so the root gate can move on.
class ChildSetupScreen extends StatefulWidget {
  const ChildSetupScreen({super.key, required this.onDone});
  final ValueChanged<ChildProfile> onDone;

  @override
  State<ChildSetupScreen> createState() => _ChildSetupScreenState();
}

/// Holds the form fields and saves the profile.
class _ChildSetupScreenState extends State<ChildSetupScreen> {
  final form = GlobalKey<FormState>();
  late final name = TextEditingController();
  String gender = 'boy';
  int age = 11;
  bool saving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (name.text.isEmpty) {
      final display = SessionScope.read(context).displayName;
      name.text = display.split(' ').first;
    }
  }

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  /// Validates the form, saves the profile locally and hands it to [onDone].
  Future<void> save() async {
    if (!(form.currentState?.validate() ?? false)) return;
    setState(() => saving = true);
    final profile = ChildProfile(
      name: name.text.trim(),
      gender: gender,
      age: age,
    );
    try {
      await profile.save();
      widget.onDone(profile);
    } catch (e) {
      if (mounted) {
        showMessage(
          context,
          tr('Маълумот нигоҳ дошта нашуд: {error}', {'error': e}),
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  /// Wrong role: signs out so the role can be chosen again.
  Future<void> back() async {
    // Wrong role chosen: sign out keeps it simple and clears the choice.
    await SessionScope.read(context).signOut();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('Дар бораи худ')),
        actions: [
          IconButton(
            tooltip: tr('Баромадан'),
            onPressed: saving ? null : back,
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Form(
          key: form,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
            children: [
              Text(
                tr('Волидайн инро дар телефони худ мебинанд.'),
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 15),
              ),
              const SizedBox(height: 6),
              ScreenHint(
                tr(
                  'Танҳо ном, ҷинс ва синну сол — дигар чизе пурсида намешавад.',
                ),
              ),
              SectionTitle(tr('Маълумоти шумо')),
              FadeIn(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          key: const Key('child.name'),
                          controller: name,
                          textCapitalization: TextCapitalization.words,
                          decoration: InputDecoration(
                            labelText: tr('Ном'),
                            prefixIcon: Icon(Icons.person_outline_rounded),
                          ),
                          validator: (v) => (v ?? '').trim().isEmpty
                              ? tr('Номро нависед.')
                              : null,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          tr('Ҷинс'),
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 10),
                        SegmentedButton<String>(
                          showSelectedIcon: false,
                          segments: [
                            ButtonSegment(
                              value: 'boy',
                              icon: Icon(Icons.boy_rounded),
                              label: Text(tr('Писар')),
                            ),
                            ButtonSegment(
                              value: 'girl',
                              icon: Icon(Icons.girl_rounded),
                              label: Text(tr('Духтар')),
                            ),
                          ],
                          selected: {gender},
                          onSelectionChanged: (v) =>
                              setState(() => gender = v.first),
                        ),
                        const SizedBox(height: 22),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                tr('Синну сол'),
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 180),
                              child: Pill(
                                tr('{age} сола', {'age': age}),
                                key: ValueKey(age),
                                color: NigohDesign.blue,
                                big: true,
                              ),
                            ),
                          ],
                        ),
                        Slider(
                          value: age.toDouble(),
                          min: 4,
                          max: 18,
                          divisions: 14,
                          label: tr('{age} сола', {'age': age}),
                          onChanged: (v) => setState(() => age = v.round()),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                key: const Key('child.save'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onPressed: saving ? null : save,
                icon: saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.4),
                      )
                    : const Icon(Icons.arrow_forward_rounded),
                label: Text(tr('Нигоҳ доштан ва идома')),
              ),
              const SizedBox(height: 10),
              Center(
                child: ScreenHint(tr('Қадами навбатӣ: иҷозатҳои Android.')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
