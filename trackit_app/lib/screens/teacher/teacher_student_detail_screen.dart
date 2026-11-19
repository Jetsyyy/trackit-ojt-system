import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/teacher_student_detail.dart';
import '../../services/api_client.dart';
import '../../services/teacher_students_service.dart';
import '../../widgets/common/back_nav_header.dart';
import '../../widgets/common/desk_ui.dart';
import '../../widgets/common/skeleton_list_tile.dart';
import '../../widgets/student/student_ui.dart';

/// Instructor > Students > Student Information (mobile mockup): a header
/// card with the student's photo, then Student Information, Contact
/// Person, Assigned Company and OJT Progress cards. Read-only.
class TeacherStudentDetailScreen extends StatefulWidget {
  final int studentId;
  final TeacherStudentsService studentsService;

  const TeacherStudentDetailScreen({
    super.key,
    required this.studentId,
    required this.studentsService,
  });

  @override
  State<TeacherStudentDetailScreen> createState() =>
      _TeacherStudentDetailScreenState();
}

class _TeacherStudentDetailScreenState
    extends State<TeacherStudentDetailScreen> {
  TeacherStudentDetail? _student;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final student = await widget.studentsService.getStudentDetail(widget.studentId);
      if (!mounted) return;
      setState(() {
        _student = student;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (_loading) {
      body = const SkeletonList();
    } else if (_student == null) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error ?? 'Student not found.', textAlign: TextAlign.center),
        ),
      );
    } else {
      body = _DetailBody(student: _student!);
    }
    return SafeArea(
      top: false,
      bottom: false,
      child: StudentBackdrop(
        child: Column(
          children: [
            const BackNavHeader(subtitle: 'Student Information'),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}

String _hrs(double hours) =>
    hours == hours.roundToDouble() ? hours.toInt().toString() : hours.toStringAsFixed(1);

String _orDash(String? value) => value == null || value.trim().isEmpty ? '—' : value.trim();

class _DetailBody extends StatelessWidget {
  final TeacherStudentDetail student;

  const _DetailBody({required this.student});

  /// "Week N" of the OJT, counted from the start date; before a start date
  /// is set, the number of approved weeks.
  String get _weekLabel {
    final start = student.ojtStartDate;
    if (start == null) {
      return student.progress.approvedWeeks > 0 ? 'Week ${student.progress.approvedWeeks}' : 'Not started';
    }
    final days = DateTime.now().difference(DateTime(start.year, start.month, start.day)).inDays;
    if (days < 0) return 'Starts ${DateFormat('MMM d').format(start)}';
    return 'Week ${days ~/ 7 + 1}';
  }

  /// The student's single "contact person" field holds a name and usually a
  /// phone number ("Juan Dela Cruz 09171234567"); show them on two lines.
  (String, String) get _guardian {
    final raw = (student.contactPerson ?? '').trim();
    if (raw.isEmpty) return ('—', '—');
    final match = RegExp(r'^(.*?)[\s,;:/-]*((?:\+63|0)[\d\s-]{9,13}\d)$').firstMatch(raw);
    if (match == null) return (raw, '—');
    final name = match.group(1)!.trim();
    return (name.isEmpty ? '—' : name, match.group(2)!.trim());
  }

  @override
  Widget build(BuildContext context) {
    final company = student.company;
    final p = student.progress;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
      children: [
        StudentCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: Row(
            children: [
              DeskAvatar(
                name: student.name,
                imageUrl: student.avatarUrl != null ? ApiClient.resolveUrl(student.avatarUrl!) : null,
                radius: 32,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(student.name, style: studentSerif(size: 20, color: StudentColors.heading)),
                    const SizedBox(height: 4),
                    Text(
                      'Student ID: ${_orDash(student.studentNumber)}',
                      style: const TextStyle(fontSize: 13, color: StudentColors.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _InfoCard(
          icon: Icons.badge_outlined,
          title: 'Student Information',
          rows: [
            ('Full Name', student.name),
            ('Program', _orDash(student.course)),
            ('Section', _orDash(student.section)),
            ('Email', student.email),
            ('Contact Number', _orDash(student.phone)),
            ('Address', _orDash(student.address)),
          ],
        ),
        const SizedBox(height: 14),
        _InfoCard(
          icon: Icons.family_restroom_outlined,
          title: 'Contact Person',
          rows: [
            ('Family / Guardian', _guardian.$1),
            ('Emergency Contact', _guardian.$2),
          ],
        ),
        const SizedBox(height: 14),
        _InfoCard(
          icon: Icons.apartment_outlined,
          title: 'Assigned Company',
          rows: company == null
              ? const [('Company', 'Not yet deployed')]
              : [
                  ('Company', _orDash(company.name)),
                  ('Address', _orDash(company.address)),
                  ('Supervisor', _orDash(company.supervisorName)),
                  ('Contact Number', _orDash(company.contactNumber)),
                ],
        ),
        const SizedBox(height: 14),
        _InfoCard(
          icon: Icons.bar_chart_rounded,
          title: 'OJT Progress',
          rows: [
            ('Hours', '${_hrs(p.completedHours)} / ${_hrs(p.requiredHours)} hrs'),
            ('Weeks', _weekLabel),
          ],
          footer: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DeskProgressBar(value: p.progressRatio),
                const SizedBox(height: 6),
                Text(
                  p.pendingHours > 0
                      ? '${(p.progressRatio * 100).round()}% complete · ${_hrs(p.pendingHours)} hrs waiting for approval'
                      : '${(p.progressRatio * 100).round()}% complete',
                  style: const TextStyle(fontSize: 12, color: StudentColors.muted),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<(String, String)> rows;
  final Widget? footer;

  const _InfoCard({required this.icon, required this.title, required this.rows, this.footer});

  @override
  Widget build(BuildContext context) {
    return StudentCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: StudentColors.maroon),
              const SizedBox(width: 8),
              Text(title, style: studentSerif(size: 17, color: StudentColors.heading)),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(height: 1, color: Color(0xFFE2DCDB)),
          ),
          for (final (label, value) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 128,
                    child: Text(label, style: const TextStyle(fontSize: 13, color: StudentColors.muted)),
                  ),
                  Expanded(
                    child: Text(
                      value,
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Colors.black87),
                    ),
                  ),
                ],
              ),
            ),
          if (footer != null) footer!,
        ],
      ),
    );
  }
}
