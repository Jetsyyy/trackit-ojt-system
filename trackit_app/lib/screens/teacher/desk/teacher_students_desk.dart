import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../models/instructor_class.dart';
import '../../../models/student_registration_request.dart';
import '../../../models/teacher_student_summary.dart';
import '../../../services/api_client.dart';
import '../../../widgets/common/desk_ui.dart';
import '../../../widgets/student/student_ui.dart';

/// Desktop Students page (instructor mockup): section tabs, Pending
/// Account Approvals, Class Information, search / filter / Generate, and
/// the student information table. Data and actions come from
/// TeacherStudentsScreen so both layouts stay in sync.
class TeacherStudentsDesk extends StatefulWidget {
  final List<InstructorClass> classes;
  final List<TeacherStudentSummary> students;
  final List<StudentRegistrationRequest> requests;
  final bool exporting;
  final ValueChanged<int> onOpenStudent;
  final Future<void> Function(StudentRegistrationRequest request, bool approve) onDecide;
  final ValueChanged<String> onGenerate;
  final VoidCallback onOpenFilter;
  final bool filtersActive;
  final bool Function(TeacherStudentSummary student) matchesFilters;
  final Future<void> Function() onRefresh;

  /// Phone layout (instructor mobile mockup).
  final bool compact;

  const TeacherStudentsDesk({
    super.key,
    required this.classes,
    required this.students,
    required this.requests,
    required this.exporting,
    required this.onOpenStudent,
    required this.onDecide,
    required this.onGenerate,
    required this.onOpenFilter,
    required this.filtersActive,
    required this.matchesFilters,
    required this.onRefresh,
    this.compact = false,
  });

  @override
  State<TeacherStudentsDesk> createState() => _TeacherStudentsDeskState();
}

class _TeacherStudentsDeskState extends State<TeacherStudentsDesk> {
  int _selected = 0;
  String _query = '';
  bool _classInfoOpen = false;
  bool _showAll = false;

  InstructorClass? get _class =>
      widget.classes.isEmpty ? null : widget.classes[_selected.clamp(0, widget.classes.length - 1)];

  List<TeacherStudentSummary> get _rows {
    final c = _class;
    final q = _query.trim().toLowerCase();
    return widget.students.where((s) {
      if (c != null && s.classId != null && s.classId != c.id) return false;
      if (q.isNotEmpty &&
          !s.name.toLowerCase().contains(q) &&
          !(s.studentNumber ?? '').toLowerCase().contains(q)) {
        return false;
      }
      return widget.matchesFilters(s);
    }).toList();
  }

  List<StudentRegistrationRequest> get _sectionRequests {
    final c = _class;
    if (c == null) return widget.requests;
    return widget.requests.where((r) => r.classId == null || r.classId == c.id).toList();
  }

  Widget _searchField(double height) => SizedBox(
        height: height,
        child: TextField(
          onChanged: (v) => setState(() => _query = v),
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            hintText: 'Search by name, student ID...',
            hintStyle: const TextStyle(fontSize: 13, color: DeskColors.muted),
            prefixIcon: const Icon(Icons.search, size: 20, color: DeskColors.muted),
            filled: true,
            fillColor: Colors.white,
            contentPadding: EdgeInsets.zero,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFD6D6D6)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: DeskColors.maroon),
            ),
          ),
        ),
      );

  Widget _compact(BuildContext context) {
    final c = _class;
    final rows = _rows;
    const preview = 5;
    final visible = _showAll ? rows : rows.take(preview).toList();
    return StudentBackdrop(
      child: Column(
        children: [
          const StudentHeader(title: 'Students', subtitle: 'Class Management'),
          Expanded(
            child: RefreshIndicator(
              color: DeskColors.maroon,
              onRefresh: widget.onRefresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  if (c == null)
                    const StudentCard(
                      child: Text(
                        'No section assigned yet. The Admin assigns your sections; their '
                        'class codes will appear here once they do.',
                        style: TextStyle(fontSize: 13, color: DeskColors.muted),
                      ),
                    )
                  else ...[
                    if (widget.classes.length > 1) ...[
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DeskSegmentedTabs(
                          labels: [for (final k in widget.classes) '${k.program} - ${k.section}'],
                          selectedIndex: _selected,
                          onChanged: (i) => setState(() {
                            _selected = i;
                            _showAll = false;
                          }),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    _ClassInformation(
                      instructorClass: c,
                      compact: true,
                      expanded: _classInfoOpen,
                      onToggle: () => setState(() => _classInfoOpen = !_classInfoOpen),
                    ),
                    const SizedBox(height: 12),
                    _PendingApprovals(requests: _sectionRequests, onDecide: widget.onDecide, compact: true),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(child: _searchField(42)),
                        const SizedBox(width: 8),
                        SizedBox(
                          height: 42,
                          child: OutlinedButton.icon(
                            onPressed: widget.onOpenFilter,
                            icon: Icon(
                              widget.filtersActive ? Icons.filter_alt : Icons.filter_list,
                              size: 18,
                              color: const Color(0xFF555555),
                            ),
                            label: const Text('Filter', style: TextStyle(color: Color(0xFF333333))),
                            style: OutlinedButton.styleFrom(
                              backgroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              side: const BorderSide(color: Color(0xFFD6D6D6)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    StudentCard(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Student List (${rows.length})',
                                  style: studentSerif(size: 18, color: StudentColors.heading),
                                ),
                              ),
                              _GenerateButton(exporting: widget.exporting, onSelected: widget.onGenerate, compact: true),
                              if (rows.length > preview) ...[
                                const SizedBox(width: 6),
                                InkWell(
                                  borderRadius: BorderRadius.circular(20),
                                  onTap: () => setState(() => _showAll = !_showAll),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: DeskColors.maroon,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      _showAll ? 'Show Less' : 'View All',
                                      style: const TextStyle(fontSize: 11.5, color: Colors.white, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 6),
                          if (rows.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 18),
                              child: Text(
                                'No students match. Share your class activation code so students can join.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 12.5, color: DeskColors.muted),
                              ),
                            )
                          else
                            for (var i = 0; i < visible.length; i++) ...[
                              if (i > 0) const Divider(height: 1, color: Color(0xFFE6E0DF)),
                              _StudentRow(student: visible[i], onOpen: widget.onOpenStudent),
                            ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.compact) return _compact(context);
    final c = _class;
    return DeskPage(
      title: 'Students',
      onRefresh: widget.onRefresh,
      children: [
        if (c == null)
          const DeskCard(
            child: Text(
              'No section assigned yet. The Admin assigns your sections; their '
              'class codes will appear here once they do.',
              style: TextStyle(fontSize: 13, color: DeskColors.muted),
            ),
          )
        else ...[
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (widget.classes.length > 1) ...[
                        DeskSegmentedTabs(
                          labels: [for (final k in widget.classes) '${k.program} - ${k.section}'],
                          selectedIndex: _selected,
                          onChanged: (i) => setState(() => _selected = i),
                        ),
                        const SizedBox(height: 12),
                      ],
                      Expanded(child: _PendingApprovals(requests: _sectionRequests, onDecide: widget.onDecide)),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(flex: 7, child: _ClassInformation(instructorClass: c)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: TextField(
                    onChanged: (v) => setState(() => _query = v),
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Search by name, student ID...',
                      hintStyle: const TextStyle(fontSize: 13, color: DeskColors.muted),
                      prefixIcon: const Icon(Icons.search, size: 20, color: DeskColors.muted),
                      filled: true,
                      fillColor: DeskColors.tile,
                      contentPadding: EdgeInsets.zero,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: DeskColors.tileBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: DeskColors.maroon),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 40,
                child: OutlinedButton.icon(
                  onPressed: widget.onOpenFilter,
                  icon: Icon(
                    widget.filtersActive ? Icons.filter_alt : Icons.filter_list,
                    size: 18,
                    color: const Color(0xFF555555),
                  ),
                  label: const Text('Filter', style: TextStyle(color: Color(0xFF333333))),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFFD6D6D6)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _GenerateButton(exporting: widget.exporting, onSelected: widget.onGenerate),
            ],
          ),
          const SizedBox(height: 16),
          _StudentTable(rows: _rows, onOpen: widget.onOpenStudent),
        ],
      ],
    );
  }
}

class _PendingApprovals extends StatelessWidget {
  final List<StudentRegistrationRequest> requests;
  final Future<void> Function(StudentRegistrationRequest, bool) onDecide;
  final bool compact;

  const _PendingApprovals({required this.requests, required this.onDecide, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(compact ? 14 : 10),
        border: Border.all(color: DeskColors.maroon.withValues(alpha: 0.6)),
        boxShadow: compact
            ? const [BoxShadow(color: Color(0x22000000), blurRadius: 6, offset: Offset(0, 3))]
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: const Color(0xFFF5D6D8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Pending Account Approvals',
                    style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: DeskColors.heading),
                  ),
                ),
                Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: DeskColors.heading, width: 1.4),
                  ),
                  child: Text(
                    '${requests.length}',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: DeskColors.heading),
                  ),
                ),
              ],
            ),
          ),
          if (requests.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 18),
              child: Text(
                'No students waiting for approval.',
                style: TextStyle(fontSize: 12.5, color: DeskColors.muted),
              ),
            )
          else
            for (var i = 0; i < requests.length; i++) ...[
              if (i > 0) const Divider(height: 1, color: DeskColors.tileBorder),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    DeskAvatar(name: requests[i].name, radius: 16),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            requests[i].name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                          Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: 'Student ID: ${requests[i].studentNumber ?? '--'}  •  ',
                                  style: const TextStyle(color: DeskColors.muted),
                                ),
                                TextSpan(
                                  text: timeAgo(requests[i].requestedAt),
                                  style: const TextStyle(color: Color(0xFFE0661A)),
                                ),
                              ],
                            ),
                            style: const TextStyle(fontSize: 10.5),
                          ),
                        ],
                      ),
                    ),
                    _SmallButton(
                      label: 'Remove',
                      color: const Color(0xFFC62828),
                      onTap: () => onDecide(requests[i], false),
                    ),
                    const SizedBox(width: 6),
                    _SmallButton(
                      label: compact ? 'Accept' : 'Approve',
                      color: const Color(0xFF1E9E45),
                      onTap: () => onDecide(requests[i], true),
                    ),
                  ],
                ),
              ),
            ],
        ],
      ),
    );
  }
}

class _SmallButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _SmallButton({required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(label, style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
}

class _ClassInformation extends StatelessWidget {
  final InstructorClass instructorClass;
  final bool compact;
  final bool expanded;
  final VoidCallback? onToggle;

  const _ClassInformation({
    required this.instructorClass,
    this.compact = false,
    this.expanded = true,
    this.onToggle,
  });

  void _copy(BuildContext context, String text, String message) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _labelled(IconData icon, String label, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: DeskColors.muted),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 11, color: DeskColors.muted)),
          ],
        ),
        const SizedBox(height: 4),
        child,
      ],
    );
  }

  Widget _valueBox(String value) {
    return Container(
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: DeskColors.tile,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: DeskColors.tileBorder),
      ),
      child: Text(
        value,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: DeskColors.heading),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = instructorClass;
    final invite = 'Join our TRACKIT class (${c.program} - ${c.section}, ${c.academicYear}): '
        'open TRACKIT, tap Register, and enter activation code ${c.activationCode}.';
    final title = InkWell(
      onTap: compact ? onToggle : null,
      child: Row(
        children: [
          const Icon(Icons.school, size: 20, color: DeskColors.maroon),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'CLASS INFORMATION',
              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: DeskColors.heading),
            ),
          ),
          if (compact)
            Icon(
              expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              color: DeskColors.heading,
            ),
        ],
      ),
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(compact ? 14 : 10),
        border: Border.all(color: const Color(0xFFD6D6D6)),
        boxShadow: compact
            ? const [BoxShadow(color: Color(0x22000000), blurRadius: 6, offset: Offset(0, 3))]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          title,
          if (!compact || expanded) ...[
          const SizedBox(height: 10),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: compact ? 0 : 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _labelled(Icons.school_outlined, 'Program & Section', _valueBox('${c.program} - ${c.section}')),
                    ),
                    SizedBox(width: compact ? 12 : 60),
                    Expanded(
                      child: _labelled(Icons.calendar_month_outlined, 'Academic Year', _valueBox(c.academicYear)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _labelled(
                  Icons.key_outlined,
                  'Class Activation Code',
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 36,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          alignment: Alignment.centerLeft,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFBE4E5),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: DeskColors.maroon.withValues(alpha: 0.5)),
                          ),
                          child: SelectableText(
                            c.activationCode,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF2B2B2B)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        height: 36,
                        child: OutlinedButton.icon(
                          onPressed: () => _copy(context, c.activationCode, 'Activation code copied.'),
                          icon: const Icon(Icons.copy, size: 16),
                          label: const Text('Copy'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: DeskColors.maroon,
                            side: const BorderSide(color: DeskColors.maroon),
                            shape: const StadiumBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 34,
                  child: OutlinedButton.icon(
                    onPressed: () => _copy(context, invite, 'Invitation message copied.'),
                    icon: const Icon(Icons.link, size: 16),
                    label: const Text('Copy Invitation Link'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: DeskColors.heading,
                      side: const BorderSide(color: DeskColors.maroon),
                      shape: const StadiumBorder(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          ],
        ],
      ),
    );
  }
}

class _GenerateButton extends StatelessWidget {
  final bool exporting;
  final ValueChanged<String> onSelected;
  final bool compact;

  const _GenerateButton({required this.exporting, required this.onSelected, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Generate your students\' records',
      enabled: !exporting,
      onSelected: onSelected,
      position: PopupMenuPosition.under,
      itemBuilder: (context) => const [
        PopupMenuItem(value: 'pdf', child: Text('PDF')),
        PopupMenuItem(value: 'xlsx', child: Text('Excel (.xlsx)')),
      ],
      child: compact
          ? Padding(
              padding: const EdgeInsets.all(4),
              child: exporting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: DeskColors.maroon),
                    )
                  : const Icon(Icons.download_outlined, size: 22, color: DeskColors.maroon),
            )
          : Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(color: DeskColors.maroon, borderRadius: BorderRadius.circular(8)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            exporting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.picture_as_pdf_outlined, size: 18, color: Colors.white),
            const SizedBox(width: 8),
            const Text('Generate', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _StudentTable extends StatelessWidget {
  final List<TeacherStudentSummary> rows;
  final ValueChanged<int> onOpen;

  const _StudentTable({required this.rows, required this.onOpen});

  static const _columns = [
    ('Name', 22),
    ('Program, Year\n& Section', 12),
    ('Email', 20),
    ('Contact Person', 16),
    ('Company', 16),
    ('Address', 18),
  ];

  static const _cell = TextStyle(fontSize: 11.5, color: Color(0xFF2B2B2B));

  Widget _cellText(String? text, {bool center = false}) => Text(
        (text == null || text.trim().isEmpty) ? '--' : text,
        textAlign: center ? TextAlign.center : TextAlign.start,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: _cell,
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD6D6D6)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: DeskColors.maroon,
            padding: const EdgeInsets.symmetric(vertical: 9),
            alignment: Alignment.center,
            child: const Text(
              'Information',
              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ),
          Container(
            color: const Color(0xFFE3E3E3),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                for (final col in _columns)
                  Expanded(
                    flex: col.$2,
                    child: Text(
                      col.$1,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF2B2B2B)),
                    ),
                  ),
              ],
            ),
          ),
          if (rows.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No students match. Share your class activation code so students can join.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: DeskColors.muted),
              ),
            )
          else
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) const Divider(height: 1, color: Color(0xFFDDDDDD)),
              InkWell(
                onTap: () => onOpen(rows[i].id),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 22,
                        child: Row(
                          children: [
                            DeskAvatar(
                              name: rows[i].name,
                              imageUrl: rows[i].avatarUrl == null ? null : ApiClient.resolveUrl(rows[i].avatarUrl!),
                              radius: 14,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    rows[i].name,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                                  ),
                                  Text(
                                    'Student ID: ${rows[i].studentNumber ?? '--'}',
                                    style: const TextStyle(fontSize: 9.5, color: DeskColors.muted),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 12,
                        child: _cellText(
                          rows[i].sectionLabel,
                          center: true,
                        ),
                      ),
                      Expanded(flex: 20, child: _cellText(rows[i].email, center: true)),
                      Expanded(flex: 16, child: _cellText(rows[i].contactPerson, center: true)),
                      Expanded(
                        flex: 16,
                        child: _cellText(
                          rows[i].companyName == null
                              ? null
                              : [rows[i].companyName, rows[i].companyAddress]
                                  .whereType<String>()
                                  .where((t) => t.trim().isNotEmpty)
                                  .join(', '),
                        ),
                      ),
                      Expanded(flex: 18, child: _cellText(rows[i].address)),
                    ],
                  ),
                ),
              ),
            ],
        ],
      ),
    );
  }
}

/// One row of the phone Student List: avatar, name, ID, hours bar.
class _StudentRow extends StatelessWidget {
  final TeacherStudentSummary student;
  final ValueChanged<int> onOpen;

  const _StudentRow({required this.student, required this.onOpen});

  String _h(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final s = student;
    final ratio = s.requiredHours <= 0 ? 0.0 : (s.completedHours / s.requiredHours).clamp(0.0, 1.0);
    return InkWell(
      onTap: () => onOpen(s.id),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            DeskAvatar(
              name: s.name,
              imageUrl: s.avatarUrl == null ? null : ApiClient.resolveUrl(s.avatarUrl!),
              radius: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Color(0xFF1F1F1F)),
                  ),
                  Text(
                    'Student ID: ${s.studentNumber ?? '--'}',
                    style: const TextStyle(fontSize: 11, color: DeskColors.muted),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(child: DeskProgressBar(value: ratio)),
                      const SizedBox(width: 8),
                      Text(
                        '${_h(s.completedHours)}/${_h(s.requiredHours)} hrs',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF444444)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right, color: DeskColors.muted),
          ],
        ),
      ),
    );
  }
}
