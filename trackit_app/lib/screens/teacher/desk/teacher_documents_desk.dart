import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/instructor_class.dart';
import '../../../models/ojt_requirement_doc.dart';
import '../../../models/ojt_requirement_phase.dart';
import '../../../models/teacher_requirement_phase.dart';
import '../../../models/teacher_requirement_student_summary.dart';
import '../../../models/teacher_weekly_report_row.dart';
import '../../../models/weekly_submission.dart';
import '../../../services/api_client.dart';
import '../../../services/teacher_classes_service.dart';
import '../../../services/teacher_requirements_service.dart';
import '../../../services/teacher_weekly_reports_service.dart';
import '../../../utils/attachment_launcher.dart';
import '../../../widgets/common/desk_ui.dart';

/// Desktop Documents pages (instructor mockups): Requirements and Weekly
/// Submission. Both have the section tabs and a student list on the
/// left, and the selected student's details on the right.

// ---------------------------------------------------------------- shared

Future<void> _openFile(BuildContext context, String? url) async {
  if (url == null) return;
  final opened = await openAttachment(ApiClient.resolveUrl(url));
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not open that file.')),
    );
  }
}

void _showError(BuildContext context, Object error, String fallback) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(error is ApiException ? error.message : fallback),
      backgroundColor: const Color(0xFFC62828),
    ),
  );
}

/// Asks for the note the student sees when something is sent back.
Future<String?> _askRemarks(BuildContext context, {required String title, required String hint}) {
  return showDialog<String>(
    context: context,
    builder: (context) => _RemarksDialog(title: title, hint: hint),
  );
}

class _RemarksDialog extends StatefulWidget {
  final String title;
  final String hint;

  const _RemarksDialog({required this.title, required this.hint});

  @override
  State<_RemarksDialog> createState() => _RemarksDialogState();
}

class _RemarksDialogState extends State<_RemarksDialog> {
  final _controller = TextEditingController();
  bool _showError = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 380,
        child: TextField(
          controller: _controller,
          autofocus: true,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: 'Remarks for the student',
            hintText: widget.hint,
            errorText: _showError ? 'Add remarks so the student knows what to fix' : null,
            border: const OutlineInputBorder(),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFFC62828)),
          onPressed: () {
            final text = _controller.text.trim();
            if (text.isEmpty) {
              setState(() => _showError = true);
              return;
            }
            Navigator.of(context).pop(text);
          },
          child: const Text('Send back'),
        ),
      ],
    );
  }
}

/// Section tabs + "Student List (n)" card. [itemBuilder] draws each row.
class _StudentListPanel<T> extends StatelessWidget {
  final List<InstructorClass> classes;
  final int? selectedClass;
  final ValueChanged<int?> onSelectClass;
  final List<T> students;
  final Widget Function(T student) itemBuilder;
  final bool loading;

  const _StudentListPanel({
    required this.classes,
    required this.selectedClass,
    required this.onSelectClass,
    required this.students,
    required this.itemBuilder,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (classes.length > 1) ...[
          DeskSegmentedTabs(
            labels: [for (final c in classes) '${c.program} - ${c.section}'],
            selectedIndex: selectedClass ?? -1,
            onChanged: onSelectClass,
          ),
          const SizedBox(height: 14),
        ],
        Expanded(
          child: DeskCard(
            title: 'Student List (${students.length})',
            trailing: classes.length > 1 && selectedClass != null
                ? DeskPill(label: 'View All', onTap: () => onSelectClass(null))
                : null,
            child: Expanded(
              child: loading
                  ? const Center(child: CircularProgressIndicator(color: DeskColors.maroon))
                  : students.isEmpty
                      ? const Center(
                          child: Text(
                            'No students in this section yet.',
                            style: TextStyle(fontSize: 12.5, color: DeskColors.muted),
                          ),
                        )
                      : ListView.separated(
                          itemCount: students.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 10),
                          itemBuilder: (context, i) => itemBuilder(students[i]),
                        ),
            ),
          ),
        ),
      ],
    );
  }
}

/// One student row: avatar, name, Student ID, progress bar + caption.
class _StudentRow extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  final String? studentNumber;
  final double progress;
  final String caption;
  final bool selected;
  final VoidCallback onTap;

  const _StudentRow({
    required this.name,
    required this.avatarUrl,
    required this.studentNumber,
    required this.progress,
    required this.caption,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return DeskTile(
      selected: selected,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          DeskAvatar(
            name: name,
            imageUrl: avatarUrl == null ? null : ApiClient.resolveUrl(avatarUrl!),
            radius: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1F1F1F)),
                ),
                Text(
                  'Student ID: ${studentNumber ?? '--'}',
                  style: const TextStyle(fontSize: 11, color: DeskColors.muted),
                ),
                const SizedBox(height: 4),
                SizedBox(width: 90, child: DeskProgressBar(value: progress, height: 5)),
                const SizedBox(height: 2),
                Text(caption, style: const TextStyle(fontSize: 9.5, color: Color(0xFF555555))),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: Color(0xFF6B6B6B)),
        ],
      ),
    );
  }
}

/// Fixed-height two-column body so the panels fill the screen like the
/// mockups instead of growing with their content.
class _TwoPanels extends StatelessWidget {
  final Widget left;
  final Widget right;

  const _TwoPanels({required this.left, required this.right});

  @override
  Widget build(BuildContext context) {
    final height = math.max(560.0, MediaQuery.sizeOf(context).height - 150);
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: 10, child: left),
          const SizedBox(width: 18),
          Expanded(flex: 13, child: right),
        ],
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  final String text;

  const _Placeholder(this.text);

  @override
  Widget build(BuildContext context) {
    return DeskCard(
      child: SizedBox(
        height: 200,
        child: Center(
          child: Text(text, style: const TextStyle(fontSize: 13, color: DeskColors.muted)),
        ),
      ),
    );
  }
}

class _OutlineAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _OutlineAction({required this.label, required this.icon, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 30,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 15),
        label: Text(label, style: const TextStyle(fontSize: 12)),
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          disabledForegroundColor: color.withValues(alpha: 0.35),
          side: BorderSide(color: onTap == null ? color.withValues(alpha: 0.3) : color),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          shape: const StadiumBorder(),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------- Requirements

class TeacherRequirementsDesk extends StatefulWidget {
  final TeacherRequirementsService service;
  final TeacherClassesService classesService;

  const TeacherRequirementsDesk({super.key, required this.service, required this.classesService});

  @override
  State<TeacherRequirementsDesk> createState() => _TeacherRequirementsDeskState();
}

class _TeacherRequirementsDeskState extends State<TeacherRequirementsDesk> {
  List<InstructorClass> _classes = [];
  List<TeacherRequirementStudentSummary> _students = [];
  int? _selectedClass = 0;
  int? _studentId;
  TeacherStudentRequirements? _detail;
  bool _loading = true;
  bool _loadingDetail = false;
  int _tab = 0;
  final Set<String> _expanded = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        widget.classesService.getClasses(),
        widget.service.getStudents(),
      ]);
      if (!mounted) return;
      setState(() {
        _classes = results[0] as List<InstructorClass>;
        _students = results[1] as List<TeacherRequirementStudentSummary>;
        _loading = false;
        if (_classes.isEmpty) _selectedClass = null;
      });
      final visible = _visible;
      if (_studentId == null && visible.isNotEmpty) _select(visible.first.id);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showError(context, e, 'Could not load students.');
    }
  }

  List<TeacherRequirementStudentSummary> get _visible {
    if (_selectedClass == null || _classes.isEmpty) return _students;
    final c = _classes[_selectedClass!.clamp(0, _classes.length - 1)];
    return _students
        .where((s) => s.classId == null ? (s.course == c.program && s.section == c.section) : s.classId == c.id)
        .toList();
  }

  Future<void> _select(int studentId) async {
    setState(() {
      _studentId = studentId;
      _loadingDetail = true;
    });
    try {
      final detail = await widget.service.getStudentRequirements(studentId);
      if (!mounted || _studentId != studentId) return;
      setState(() {
        _detail = detail;
        _loadingDetail = false;
        _expanded
          ..clear()
          ..addAll(detail.phases.where((p) => p.status == PhaseStatus.inProgress).map((p) => p.id).take(1));
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingDetail = false);
      _showError(context, e, 'Could not load this student\'s requirements.');
    }
  }

  Future<void> _review(String submissionId, {required bool approve, required bool custom}) async {
    String? remarks;
    if (!approve) {
      remarks = await _askRemarks(
        context,
        title: 'Ask for a re-upload',
        hint: 'e.g. The signature is missing on page 2.',
      );
      if (remarks == null) return;
    }
    try {
      if (custom) {
        await widget.service.reviewCustomSubmission(submissionId: submissionId, approve: approve, remarks: remarks);
      } else {
        await widget.service.reviewSubmission(submissionId: submissionId, approve: approve, remarks: remarks);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(approve ? 'Requirement approved.' : 'Sent back for re-upload.')),
      );
      await Future.wait([_select(_studentId!), _reloadList()]);
    } catch (e) {
      if (mounted) _showError(context, e, 'Could not save your review.');
    }
  }

  Future<void> _reloadList() async {
    final students = await widget.service.getStudents();
    if (mounted) setState(() => _students = students);
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    return DeskPage(
      title: 'Requirements',
      subtitle: 'Official & Additional student requirements',
      children: [
        _TwoPanels(
          left: _StudentListPanel<TeacherRequirementStudentSummary>(
            classes: _classes,
            selectedClass: _selectedClass,
            onSelectClass: (i) => setState(() => _selectedClass = i),
            students: visible,
            loading: _loading,
            itemBuilder: (s) => _StudentRow(
              name: s.name,
              avatarUrl: s.avatarUrl,
              studentNumber: s.studentNumber,
              progress: s.progress > 1 ? s.progress / 100 : s.progress,
              caption: '${((s.progress > 1 ? s.progress / 100 : s.progress) * 100).round()}%',
              selected: s.id == _studentId,
              onTap: () => _select(s.id),
            ),
          ),
          right: _studentId == null
              ? const _Placeholder('Select a student to see their requirements.')
              : _buildDetail(),
        ),
      ],
    );
  }

  Widget _buildDetail() {
    final detail = _detail;
    return DeskCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
      child: Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DeskSegmentedTabs(
              labels: const ['Official Requirements', 'Additional Requirements'],
              selectedIndex: _tab,
              onChanged: (i) => setState(() => _tab = i),
              height: 50,
              radius: 10,
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _loadingDetail || detail == null
                  ? const Center(child: CircularProgressIndicator(color: DeskColors.maroon))
                  : ListView(
                      padding: const EdgeInsets.only(bottom: 14),
                      children: _tab == 0 ? _officialContent(detail) : _additionalContent(detail),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _officialContent(TeacherStudentRequirements detail) {
    final phases = detail.phases;
    final docs = [for (final p in phases) ...p.documents];
    final completed = docs.where((d) => d.status == RequirementDocStatus.approved).length;
    final needsReview = docs.where((d) => d.status == RequirementDocStatus.submitted).length;
    final pending = docs.length - completed - needsReview;
    final currentIndex = phases.indexWhere((p) => p.status != PhaseStatus.completed);
    final stage = currentIndex == -1 ? phases.length : currentIndex + 1;
    return [
      _ProgressSummary(
        completed: completed,
        needsReview: needsReview,
        pending: pending,
        heading: 'Stage $stage of ${phases.length}',
      ),
      const SizedBox(height: 16),
      const Text(
        'Requirements Checklist',
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1F1F1F)),
      ),
      const SizedBox(height: 10),
      for (final phase in phases) ...[
        _PhaseTile(
          phase: phase,
          expanded: _expanded.contains(phase.id),
          onToggle: () => setState(() {
            if (!_expanded.remove(phase.id)) _expanded.add(phase.id);
          }),
          children: [
            if (phase.isFinalDetails)
              Text(phase.finalDetailsNote, style: const TextStyle(fontSize: 12, color: DeskColors.muted)),
            for (final d in phase.documents)
              _DocCard(
                name: d.name,
                description: d.description,
                status: d.status,
                fileName: d.uploadedFileName,
                remarks: d.remarks,
                onView: d.uploadedFileUrl == null ? null : () => _openFile(context, d.uploadedFileUrl),
                onApprove: d.submissionId != null && d.status == RequirementDocStatus.submitted
                    ? () => _review(d.submissionId!, approve: true, custom: false)
                    : null,
                onReupload: d.submissionId != null &&
                        (d.status == RequirementDocStatus.submitted || d.status == RequirementDocStatus.approved)
                    ? () => _review(d.submissionId!, approve: false, custom: false)
                    : null,
              ),
          ],
        ),
        const SizedBox(height: 10),
      ],
    ];
  }

  List<Widget> _additionalContent(TeacherStudentRequirements detail) {
    final items = detail.customRequirements;
    if (items.isEmpty) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: Center(
            child: Text(
              'No additional requirements for this student.',
              style: TextStyle(fontSize: 13, color: DeskColors.muted),
            ),
          ),
        ),
      ];
    }
    final completed = items.where((d) => d.status == RequirementDocStatus.approved).length;
    final needsReview = items.where((d) => d.status == RequirementDocStatus.submitted).length;
    return [
      _ProgressSummary(
        completed: completed,
        needsReview: needsReview,
        pending: items.length - completed - needsReview,
        heading: 'Additional Requirements',
      ),
      const SizedBox(height: 16),
      for (final d in items) ...[
        _DocCard(
          name: d.name,
          description: d.description,
          status: d.status,
          fileName: d.uploadedFileName,
          remarks: d.remarks,
          onView: d.uploadedFileUrl == null ? null : () => _openFile(context, d.uploadedFileUrl),
          onApprove: d.canReview ? () => _review(d.submissionId!, approve: true, custom: true) : null,
          onReupload: d.submissionId != null &&
                  (d.status == RequirementDocStatus.submitted || d.status == RequirementDocStatus.approved)
              ? () => _review(d.submissionId!, approve: false, custom: true)
              : null,
        ),
        const SizedBox(height: 10),
      ],
    ];
  }
}

class _ProgressSummary extends StatelessWidget {
  final int completed;
  final int needsReview;
  final int pending;
  final String heading;

  const _ProgressSummary({
    required this.completed,
    required this.needsReview,
    required this.pending,
    required this.heading,
  });

  @override
  Widget build(BuildContext context) {
    final total = completed + needsReview + pending;
    final ratio = total == 0 ? 0.0 : completed / total;
    Widget legend(Color color, String text) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 5),
            Text(text, style: const TextStyle(fontSize: 11.5, color: Color(0xFF6B6B6B))),
          ],
        );
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      decoration: BoxDecoration(
        color: DeskColors.tile,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: DeskColors.tileBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Progress Summary', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Row(
            children: [
              _Donut(value: ratio),
              const SizedBox(width: 22),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(heading, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(
                      '$completed of $total requirements completed',
                      style: const TextStyle(fontSize: 12, color: DeskColors.muted),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 16,
                      runSpacing: 6,
                      children: [
                        legend(const Color(0xFF1E9E45), '$completed Completed'),
                        legend(const Color(0xFFE8A317), '$needsReview Needs Review'),
                        legend(const Color(0xFFC8C8C8), '$pending Pending'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Donut extends StatelessWidget {
  final double value;

  const _Donut({required this.value});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 96,
      height: 96,
      child: CustomPaint(
        painter: _DonutPainter(value),
        child: Center(
          child: Text(
            '${(value * 100).round()}%',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: DeskColors.maroon),
          ),
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final double value;

  _DonutPainter(this.value);

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 13.0;
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(stroke / 2);
    canvas.drawArc(arcRect, 0, math.pi * 2, false,
        Paint()
          ..color = const Color(0xFFF0D3D5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke);
    canvas.drawArc(arcRect, -math.pi / 2, math.pi * 2 * value.clamp(0.0, 1.0), false,
        Paint()
          ..color = DeskColors.maroon
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke);
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) => old.value != value;
}

class _PhaseTile extends StatelessWidget {
  final TeacherRequirementPhase phase;
  final bool expanded;
  final VoidCallback onToggle;
  final List<Widget> children;

  const _PhaseTile({required this.phase, required this.expanded, required this.onToggle, required this.children});

  @override
  Widget build(BuildContext context) {
    final (label, tone) = switch (phase.status) {
      PhaseStatus.completed => ('Completed', DeskChipTone.green),
      PhaseStatus.inProgress => ('In Progress', DeskChipTone.yellow),
      PhaseStatus.locked => ('Pending', DeskChipTone.grey),
    };
    return Container(
      decoration: BoxDecoration(
        color: DeskColors.tile,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: DeskColors.tileBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(color: DeskColors.maroon, shape: BoxShape.circle),
                    child: Text(
                      '${phase.order}',
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(phase.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                        Text(
                          phase.description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11.5, color: DeskColors.muted),
                        ),
                      ],
                    ),
                  ),
                  DeskStatusChip(label: label, tone: tone),
                  const SizedBox(width: 4),
                  Icon(expanded ? Icons.expand_less : Icons.expand_more, color: const Color(0xFF6B6B6B)),
                ],
              ),
            ),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 14),
              child: children.isEmpty
                  ? const Text('No documents in this phase.', style: TextStyle(fontSize: 12, color: DeskColors.muted))
                  : Column(
                      children: [
                        for (final c in children) Padding(padding: const EdgeInsets.only(bottom: 10), child: c),
                      ],
                    ),
            ),
        ],
      ),
    );
  }
}

class _DocCard extends StatelessWidget {
  final String name;
  final String description;
  final RequirementDocStatus status;
  final String? fileName;
  final String? remarks;
  final VoidCallback? onView;
  final VoidCallback? onApprove;
  final VoidCallback? onReupload;

  const _DocCard({
    required this.name,
    required this.description,
    required this.status,
    required this.fileName,
    required this.remarks,
    required this.onView,
    required this.onApprove,
    required this.onReupload,
  });

  @override
  Widget build(BuildContext context) {
    final (label, tone) = switch (status) {
      RequirementDocStatus.approved => ('Approved', DeskChipTone.green),
      RequirementDocStatus.submitted => ('Submitted', DeskChipTone.red),
      RequirementDocStatus.rejected => ('Re-upload requested', DeskChipTone.yellow),
      _ => ('Not submitted', DeskChipTone.grey),
    };
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDDDDDD)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(name, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
              ),
              DeskStatusChip(label: label, tone: tone),
            ],
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(description, style: const TextStyle(fontSize: 11.5, color: DeskColors.muted)),
          ],
          if (fileName != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.attach_file, size: 14, color: DeskColors.muted),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    fileName!,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF555555)),
                  ),
                ),
              ],
            ),
          ],
          if (remarks != null && remarks!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('Your remarks: $remarks', style: const TextStyle(fontSize: 11.5, color: Color(0xFFB3261E))),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              _OutlineAction(label: 'View', icon: Icons.visibility_outlined, color: const Color(0xFF2E7BEE), onTap: onView),
              _OutlineAction(label: 'Approve', icon: Icons.check_circle_outline, color: const Color(0xFF1E9E45), onTap: onApprove),
              _OutlineAction(label: 'Re-upload', icon: Icons.replay, color: const Color(0xFFC62828), onTap: onReupload),
            ],
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------- Weekly Submission

class TeacherWeeklyDesk extends StatefulWidget {
  final TeacherWeeklyReportsService service;
  final TeacherClassesService classesService;

  const TeacherWeeklyDesk({super.key, required this.service, required this.classesService});

  @override
  State<TeacherWeeklyDesk> createState() => _TeacherWeeklyDeskState();
}

class _TeacherWeeklyDeskState extends State<TeacherWeeklyDesk> {
  List<InstructorClass> _classes = [];
  List<TeacherWeeklyStudent> _students = [];
  int? _selectedClass = 0;
  int? _studentId;
  TeacherStudentWeeks? _detail;
  int? _weekNumber;
  bool _loading = true;
  bool _loadingDetail = false;
  bool _saving = false;
  int _fileTab = 0; // 0 = AR, 1 = DTR

  static final _dateFormat = DateFormat('MMM. d, yyyy');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        widget.classesService.getClasses(),
        widget.service.getStudents(),
      ]);
      if (!mounted) return;
      setState(() {
        _classes = results[0] as List<InstructorClass>;
        _students = results[1] as List<TeacherWeeklyStudent>;
        _loading = false;
        if (_classes.isEmpty) _selectedClass = null;
      });
      final visible = _visible;
      if (_studentId == null && visible.isNotEmpty) _select(visible.first.id);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showError(context, e, 'Could not load students.');
    }
  }

  List<TeacherWeeklyStudent> get _visible {
    if (_selectedClass == null || _classes.isEmpty) return _students;
    final c = _classes[_selectedClass!.clamp(0, _classes.length - 1)];
    return _students
        .where((s) => s.classId == null ? (s.course == c.program && s.section == c.section) : s.classId == c.id)
        .toList();
  }

  /// Weeks the OJT is expected to take at about 40 hours a week.
  static int _expectedWeeks(WeeklySummary s) =>
      math.max(1, (s.requiredHours / 40).ceil());

  Future<void> _select(int studentId, {int? keepWeek}) async {
    setState(() {
      _studentId = studentId;
      _loadingDetail = true;
    });
    try {
      final detail = await widget.service.getStudentWeeks(studentId);
      if (!mounted || _studentId != studentId) return;
      _applyDetail(detail, keepWeek: keepWeek);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingDetail = false);
      _showError(context, e, 'Could not load this student\'s weeks.');
    }
  }

  void _applyDetail(TeacherStudentWeeks detail, {int? keepWeek}) {
    final weeks = detail.weeks;
    int? week = keepWeek;
    if (week == null || !weeks.any((w) => w.weekNumber == week)) {
      final pending = weeks.where((w) => w.status == WeeklySubmissionStatus.submitted);
      week = pending.isNotEmpty ? pending.first.weekNumber : (weeks.isNotEmpty ? weeks.first.weekNumber : null);
    }
    setState(() {
      _detail = detail;
      _weekNumber = week;
      _loadingDetail = false;
    });
  }

  Future<void> _review(WeeklySubmission week, bool approve) async {
    String? remarks;
    if (!approve) {
      remarks = await _askRemarks(
        context,
        title: 'Return Week ${week.weekNumber}',
        hint: 'e.g. The DTR is missing your supervisor\'s signature.',
      );
      if (remarks == null) return;
    }
    setState(() => _saving = true);
    try {
      final updated = await widget.service.reviewWeek(
        studentId: _studentId!,
        weekNumber: week.weekNumber,
        approve: approve,
        remarks: remarks,
      );
      if (!mounted) return;
      _applyDetail(updated, keepWeek: week.weekNumber);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(approve
              ? 'Week ${week.weekNumber} approved: ${_hours(week.claimedHours)} credited.'
              : 'Week ${week.weekNumber} returned to the student.'),
        ),
      );
      final students = await widget.service.getStudents();
      if (mounted) setState(() => _students = students);
    } catch (e) {
      if (mounted) _showError(context, e, 'Could not save your review.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  static String _hours(double? h) {
    if (h == null) return '0 hrs';
    final text = h == h.roundToDouble() ? h.toInt().toString() : h.toStringAsFixed(2);
    return '$text hrs';
  }

  @override
  Widget build(BuildContext context) {
    return DeskPage(
      title: 'Weekly Submission',
      subtitle: 'AR & DTR Submission per section',
      children: [
        _TwoPanels(
          left: _StudentListPanel<TeacherWeeklyStudent>(
            classes: _classes,
            selectedClass: _selectedClass,
            onSelectClass: (i) => setState(() => _selectedClass = i),
            students: _visible,
            loading: _loading,
            itemBuilder: (s) {
              final expected = _expectedWeeks(s.summary);
              return _StudentRow(
                name: s.name,
                avatarUrl: s.avatarUrl,
                studentNumber: s.studentNumber,
                progress: s.summary.approvedWeeks / expected,
                caption: '${s.summary.approvedWeeks}/$expected weeks'
                    '${s.summary.pendingReviewWeeks > 0 ? '  •  ${s.summary.pendingReviewWeeks} to review' : ''}',
                selected: s.id == _studentId,
                onTap: () => _select(s.id),
              );
            },
          ),
          right: _studentId == null
              ? const _Placeholder('Select a student to see their weekly submissions.')
              : (_loadingDetail || _detail == null)
                  ? const DeskCard(
                      child: SizedBox(
                        height: 200,
                        child: Center(child: CircularProgressIndicator(color: DeskColors.maroon)),
                      ),
                    )
                  : _buildDetail(_detail!),
        ),
      ],
    );
  }

  Widget _buildDetail(TeacherStudentWeeks detail) {
    final weeks = detail.weeks;
    final summary = detail.student.summary;
    final selected = weeks.where((w) => w.weekNumber == _weekNumber).firstOrNull;
    final percent = summary.requiredHours <= 0 ? 0.0 : summary.completedHours / summary.requiredHours;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 5,
          child: DeskCard(
            title: 'Weekly AR/DTR Submission',
            trailing: DeskPill(label: '${weeks.where((w) => w.status != WeeklySubmissionStatus.missing).length} Reports'),
            padding: const EdgeInsets.fromLTRB(18, 16, 12, 12),
            child: Expanded(
              child: weeks.isEmpty
                  ? const Center(
                      child: Text(
                        'No OJT weeks yet. Weeks appear once the student sets their OJT start date.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12.5, color: DeskColors.muted),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.only(right: 6),
                      itemCount: weeks.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, i) => _WeekRow(
                        week: weeks[i],
                        range: '${_dateFormat.format(weeks[i].weekStartDate)} - ${_dateFormat.format(weeks[i].weekEndDate)}',
                        selected: weeks[i].weekNumber == _weekNumber,
                        onTap: () => setState(() => _weekNumber = weeks[i].weekNumber),
                      ),
                    ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Expanded(
          flex: 6,
          child: DeskCard(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
            child: Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(child: DeskProgressBar(value: percent, height: 16)),
                      const SizedBox(width: 12),
                      Text(
                        '${(percent * 100).toStringAsFixed(2)}%',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFFB7791F)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_hours(summary.completedHours)} credited of ${_hours(summary.requiredHours)}'
                    '${summary.pendingHours > 0 ? '  •  ${_hours(summary.pendingHours)} awaiting approval' : ''}',
                    style: const TextStyle(fontSize: 11, color: DeskColors.muted),
                  ),
                  const SizedBox(height: 10),
                  DeskSegmentedTabs(
                    labels: const ['Accomplishment\nReport (AR)', 'Daily Time Record\n(DTR)'],
                    selectedIndex: _fileTab,
                    onChanged: (i) => setState(() => _fileTab = i),
                    height: 50,
                    radius: 10,
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: selected == null
                        ? const Center(child: Text('Select a week.', style: TextStyle(color: DeskColors.muted)))
                        : _WeekFiles(
                            week: selected,
                            showAr: _fileTab == 0,
                            claimed: _hours(selected.claimedHours),
                          ),
                  ),
                  if (selected != null) ...[
                    const SizedBox(height: 10),
                    _WeekActions(
                      week: selected,
                      saving: _saving,
                      claimed: _hours(selected.claimedHours),
                      onApprove: () => _review(selected, true),
                      onReturn: () => _review(selected, false),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _WeekRow extends StatelessWidget {
  final WeeklySubmission week;
  final String range;
  final bool selected;
  final VoidCallback onTap;

  const _WeekRow({required this.week, required this.range, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final (label, tone) = switch (week.status) {
      WeeklySubmissionStatus.approved => ('Approved', DeskChipTone.green),
      WeeklySubmissionStatus.submitted => ('For Review', DeskChipTone.yellow),
      WeeklySubmissionStatus.rejected => ('Returned', DeskChipTone.red),
      WeeklySubmissionStatus.missing => ('Not submitted', DeskChipTone.grey),
    };
    return DeskTile(
      selected: selected,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFDEDED),
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: const Color(0xFFF0C9CC)),
            ),
            child: Text(
              'Week ${week.weekNumber}',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: DeskColors.maroon),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(child: Text(range, style: const TextStyle(fontSize: 13, color: Color(0xFF2B2B2B)))),
          DeskStatusChip(label: label, tone: tone),
          const SizedBox(width: 6),
          const Icon(Icons.chevron_right, color: Color(0xFF333333)),
        ],
      ),
    );
  }
}

class _WeekFiles extends StatelessWidget {
  final WeeklySubmission week;
  final bool showAr;
  final String claimed;

  const _WeekFiles({required this.week, required this.showAr, required this.claimed});

  @override
  Widget build(BuildContext context) {
    final files = showAr ? week.arFiles : week.dtrFiles;
    final title = showAr ? 'Accomplishment Report' : 'Daily Time Record';
    return ListView(
      children: [
        Text(
          'Week ${week.weekNumber} Submission',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: DeskColors.heading),
        ),
        Text(
          week.status == WeeklySubmissionStatus.missing
              ? 'The student has not submitted this week yet.'
              : 'Hours claimed from the DTR: $claimed',
          style: const TextStyle(fontSize: 11.5, color: Color(0xFF555555)),
        ),
        if (week.remarks != null && week.remarks!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text('Your remarks: ${week.remarks}', style: const TextStyle(fontSize: 11.5, color: Color(0xFFB3261E))),
        ],
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFCCCCCC)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: DeskColors.heading)),
              const SizedBox(height: 6),
              if (files.isEmpty)
                const Text('No files.', style: TextStyle(fontSize: 12, color: DeskColors.muted))
              else
                for (final f in files)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Material(
                      color: const Color(0xFFDCE6F2),
                      borderRadius: BorderRadius.circular(4),
                      child: InkWell(
                        onTap: () => _openFile(context, f.url),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          child: Row(
                            children: [
                              Icon(
                                f.fileName.toLowerCase().endsWith('.pdf')
                                    ? Icons.picture_as_pdf_outlined
                                    : Icons.image_outlined,
                                size: 22,
                                color: const Color(0xFF555555),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  f.fileName,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                                ),
                              ),
                              const Icon(Icons.open_in_new, size: 16, color: Color(0xFF555555)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WeekActions extends StatelessWidget {
  final WeeklySubmission week;
  final bool saving;
  final String claimed;
  final VoidCallback onApprove;
  final VoidCallback onReturn;

  const _WeekActions({
    required this.week,
    required this.saving,
    required this.claimed,
    required this.onApprove,
    required this.onReturn,
  });

  Widget _bar(String text, {Color color = const Color(0xFF9C6B70)}) => Container(
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(14)),
        child: Text(
          text,
          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700, fontStyle: FontStyle.italic),
        ),
      );

  @override
  Widget build(BuildContext context) {
    switch (week.status) {
      case WeeklySubmissionStatus.approved:
        return _bar('Approved');
      case WeeklySubmissionStatus.rejected:
        return _bar('Returned — waiting for the student to resubmit', color: const Color(0xFFB0A3A4));
      case WeeklySubmissionStatus.missing:
        return _bar('Not submitted yet', color: const Color(0xFFB0A3A4));
      case WeeklySubmissionStatus.submitted:
        return Row(
          children: [
            Expanded(
              flex: 2,
              child: SizedBox(
                height: 48,
                child: OutlinedButton(
                  onPressed: saving ? null : onReturn,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFC62828),
                    side: const BorderSide(color: Color(0xFFC62828)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Return with remarks', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 3,
              child: SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: saving ? null : onApprove,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: DeskColors.maroon,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: saving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text('Approve ($claimed)', style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ),
          ],
        );
    }
  }
}
