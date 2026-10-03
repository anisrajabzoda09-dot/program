import 'package:flutter/material.dart';

import '../../core/platform.dart';
import '../../core/session.dart';
import '../../ui/nigoh_design.dart';
import '../../ui/widgets.dart';
import '../../l10n/l10n.dart';
import '../../ui/language_picker.dart';

/// "Who uses this phone?" — parent or child.
class RoleScreen extends StatefulWidget {
  const RoleScreen({super.key});

  @override
  State<RoleScreen> createState() => _RoleScreenState();
}

class _RoleScreenState extends State<RoleScreen> {
  String? saving;

  Future<void> choose(String role) async {
    if (saving != null) return;
    setState(() => saving = role);
    try {
      await SessionScope.read(context).chooseRole(role);
    } catch (e) {
      if (mounted) showMessage(context, e, error: true);
    } finally {
      if (mounted) setState(() => saving = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    // Desktop app: parent only; the child side runs on the Android phone.
    final desktop = isDesktop;
    return Scaffold(
      appBar: AppBar(
        actions: [
          const LanguageButton(),
          TextButton.icon(
            onPressed: saving != null ? null : session.signOut,
            icon: const Icon(Icons.logout_rounded, size: 20),
            label: Text(tr('Баромадан')),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    session.displayName.isEmpty
                        ? tr('Хуш омадед')
                        : tr('Салом, {name}', {'name': session.displayName}),
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    desktop
                        ? tr('NIGOH Family дар компютер барои волидайн аст.')
                        : tr('Ин телефонро кӣ истифода мебарад?'),
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 14),
                  ScreenHint(
                    desktop
                        ? tr(
                            'Баъди интихоб телефони фарзандро пайваст мекунед.',
                          )
                        : tr(
                            'Як бор интихоб мекунед. Баъд NIGOH иҷозатҳои лозимиро қадам ба қадам мепурсад.',
                          ),
                    icon: Icons.info_outline_rounded,
                  ),
                  const SizedBox(height: 20),
                  FadeIn(
                    index: 1,
                    child: _RoleCard(
                      key: const Key('role.parent'),
                      icon: Icons.family_restroom_rounded,
                      color: NigohDesign.blue,
                      title: tr('Волидайн'),
                      text: tr(
                        'Барномаҳо, ҷойгиршавӣ ва чати фарзандро бинед.',
                      ),
                      action: tr('Телефони ман'),
                      busy: saving == 'parent',
                      onTap: () => choose('parent'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (desktop)
                    FadeIn(
                      index: 2,
                      child: _ChildOnPhoneNote(
                        key: const Key('role.child-on-phone'),
                      ),
                    )
                  else
                    FadeIn(
                      index: 2,
                      child: _RoleCard(
                        key: const Key('role.child'),
                        icon: Icons.child_care_rounded,
                        color: NigohDesign.mint,
                        title: tr('Фарзанд'),
                        text: tr('Ин телефонро ба волидайн пайваст кунед.'),
                        action: tr('Телефони фарзанд'),
                        busy: saving == 'child',
                        onTap: () => choose('child'),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChildOnPhoneNote extends StatelessWidget {
  const _ChildOnPhoneNote({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NigohDesign.mint.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: NigohDesign.mint.withValues(alpha: .35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.phone_android_rounded, color: NigohDesign.mint),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              tr(
                'Қисми фарзанд дар телефони Android кор мекунад: NIGOH Family-ро дар телефони фарзанд насб кунед ва «Фарзанд»-ро интихоб кунед.',
              ),
              style: TextStyle(color: scheme.onSurfaceVariant, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.text,
    required this.action,
    required this.busy,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String text;

  /// Plain label of what tapping the card means.
  final String action;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TapScale(
      onTap: busy ? null : onTap,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: busy ? null : onTap,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: color, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        text,
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Pill(action, color: color, icon: Icons.check_rounded),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: busy
                      ? const SizedBox(
                          key: ValueKey('busy'),
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          Icons.chevron_right_rounded,
                          key: const ValueKey('arrow'),
                          color: scheme.onSurfaceVariant,
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
