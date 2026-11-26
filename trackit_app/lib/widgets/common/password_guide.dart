import 'package:flutter/material.dart';
import '../../utils/password_rules.dart';

/// Live password checklist shown under a "new password" field: each rule
/// turns green as soon as the typed password meets it (System Revision 5).
class PasswordGuide extends StatelessWidget {
  final TextEditingController controller;

  const PasswordGuide({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final p = value.text;
        final met = passwordRules.where((r) => r.test(p)).length;
        final strength = switch (met) {
          5 => ('Strong password', const Color(0xFF1E8E3E)),
          >= 3 => ('Almost there', const Color(0xFFE8843A)),
          _ => ('Weak password', const Color(0xFFC62828)),
        };
        return Container(
          margin: const EdgeInsets.only(top: 8, bottom: 4),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            color: const Color(0xFFFBF7F7),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFEADBDD)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Your password must have:',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF333333)),
                    ),
                  ),
                  if (p.isNotEmpty)
                    Text(
                      strength.$1,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: strength.$2),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              if (p.isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: met / passwordRules.length,
                    minHeight: 4,
                    backgroundColor: const Color(0xFFEDE3E4),
                    valueColor: AlwaysStoppedAnimation(strength.$2),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              for (final rule in passwordRules)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Icon(
                        rule.test(p) ? Icons.check_circle : Icons.radio_button_unchecked,
                        size: 16,
                        color: rule.test(p) ? const Color(0xFF1E8E3E) : const Color(0xFFA0A0A0),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          rule.label,
                          style: TextStyle(
                            fontSize: 12,
                            color: rule.test(p) ? const Color(0xFF1E8E3E) : const Color(0xFF555555),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 4),
              const Text(
                'Tip: avoid your name, birthday or Student ID, and don\'t reuse a password from another site.',
                style: TextStyle(fontSize: 10.5, color: Color(0xFF7A7A7A)),
              ),
            ],
          ),
        );
      },
    );
  }
}
