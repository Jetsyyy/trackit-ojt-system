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

  /// The student's single "contact person" field holds a name and usually
  /// a phone number ("Juan Dela Cruz 09171234567"): name, then number on
  /// the next line, as in the mockup.
  String get _emergencyContact {
    final raw = (student.contactPerson ?? '').trim();
    if (raw.isEmpty) return '—';
    final match = RegExp(r'^(.*?)[\s,;:/-]*((?:\+63|0)[\d\s-]{9,13}\d)$').firstMatch(raw);
    if (match == null) return raw;
    final name = match.group(1)!.trim();
    return name.isEmpty ? match.group(2)!.trim() : '$name\n${match.group(2)!.trim()}';
  }

  @override
  Widget build(BuildContext context) {
    final company = student.company;
    final p = student.progress;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
      children: [
        // Photo, name and Student ID.
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFDDD6D7)),
          ),
          child: Row(
            children: [
              DeskAvatar(
                name: student.name,
                imageUrl: student.avatarUrl != null ? ApiClient.resolveUrl(student.avatarUrl!) : null,
                radius: 28,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(student.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.black)),
                    const SizedBox(height: 2),
                    Text(
                      'Student ID: ${_orDash(student.studentNumber)}',
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Colors.black),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // The four information cards sit on one rounded panel.
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFBF8F8),
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [BoxShadow(color: Color(0x1A000000), blurRadius: 8, offset: Offset(0, 2))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _InfoCard(
                icon: Icons.badge_outlined,
                title: 'Student Information',
                rows: [
                  ('Full Name', student.name),
                  ('Program', _orDash(student.course)),
                  ('Section', _orDash(student.section)),
                  ('Email', student.email),
                  ('Address', _orDash(student.address)),
                ],
              ),
              const SizedBox(height: 12),
              _InfoCard(
                icon: Icons.family_restroom_outlined,
                title: 'Contact Person (Family / Guardian)',
                rows: [('Emergency Contact', _emergencyContact)],
              ),
              const SizedBox(height: 12),
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
              const SizedBox(height: 12),
              _InfoCard(
                icon: Icons.assignment_turned_in_outlined,
                title: 'OJT Progress',
                rows: [
                  ('Hours', '${_hrs(p.completedHours)} / ${_hrs(p.requiredHours)} hrs'),
                  ('Weeks', _weekLabel),
                ],
              ),
            ],
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

  const _InfoCard({required this.icon, required this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFDDD6D7)),
        boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 4, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: StudentColors.maroon),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final (label, value) in rows)
            Padding(
              padding: const EdgeInsets.fromLTRB(26, 5, 0, 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 118,
                    child: Text(label, style: const TextStyle(fontSize: 12.5, color: StudentColors.muted)),
                  ),
                  Expanded(
                    child: Text(value, style: const TextStyle(fontSize: 12.5, color: Colors.black87, height: 1.3)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
