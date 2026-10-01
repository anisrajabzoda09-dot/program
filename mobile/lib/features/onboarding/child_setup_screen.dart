import 'package:flutter/material.dart';

import '../../core/child_profile.dart';
import '../../core/session.dart';
import '../../ui/nigoh_design.dart';
import '../../ui/widgets.dart';

/// Child enters name, gender and age once on this phone. Calls [onDone]
/// with the saved profile so the root gate can move on.
class ChildSetupScreen extends StatefulWidget {
  const ChildSetupScreen({super.key, required this.onDone});
  final ValueChanged<ChildProfile> onDone;

  @override
  State<ChildSetupScreen> createState() => _ChildSetupScreenState();
}

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
        showMessage(context, 'Маълумот нигоҳ дошта нашуд: $e', error: true);
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> back() async {
    // Wrong role chosen: sign out keeps it simple and clears the choice.
    await SessionScope.read(context).signOut();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Дар бораи худ'),
        actions: [
          IconButton(
            tooltip: 'Баромадан',
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
                'Волидайн инро дар телефони худ мебинанд.',
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 15),
              ),
              const SizedBox(height: 20),
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
                          decoration: const InputDecoration(
                            labelText: 'Ном',
                            prefixIcon: Icon(Icons.person_outline_rounded),
                          ),
                          validator: (v) => (v ?? '').trim().isEmpty
                              ? 'Номро нависед.'
                              : null,
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Ҷинс',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 10),
                        SegmentedButton<String>(
                          showSelectedIcon: false,
                          segments: const [
                            ButtonSegment(
                              value: 'boy',
                              icon: Icon(Icons.boy_rounded),
                              label: Text('Писар'),
                            ),
                            ButtonSegment(
                              value: 'girl',
                              icon: Icon(Icons.girl_rounded),
                              label: Text('Духтар'),
                            ),
                          ],
                          selected: {gender},
                          onSelectionChanged: (v) =>
                              setState(() => gender = v.first),
                        ),
                        const SizedBox(height: 22),
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Синну сол',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                            Pill('$age сола', color: NigohDesign.blue),
                          ],
                        ),
                        Slider(
                          value: age.toDouble(),
                          min: 4,
                          max: 18,
                          divisions: 14,
                          label: '$age',
                          onChanged: (v) => setState(() => age = v.round()),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                key: const Key('child.save'),
                onPressed: saving ? null : save,
                child: saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.4),
                      )
                    : const Text('Идома'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
