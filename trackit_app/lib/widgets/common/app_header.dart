import 'package:flutter/material.dart';
import '../student/student_ui.dart';

/// Page header with a big serif title (TrackIT mockup). Inside the
/// student app it also shows the notification bell.
class AppHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const AppHeader({super.key, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) => StudentHeader(title: title, subtitle: subtitle);
}
