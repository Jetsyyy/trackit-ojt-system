import 'package:flutter/material.dart';
import '../student/student_ui.dart';

/// Inner-page header: TrackIT logo, "< Return", and the page name.
class BackNavHeader extends StatelessWidget {
  final String subtitle;
  final VoidCallback? onBack;

  const BackNavHeader({super.key, required this.subtitle, this.onBack});

  @override
  Widget build(BuildContext context) =>
      StudentHeader(title: 'Return', subtitle: subtitle, showBack: true, onBack: onBack);
}
