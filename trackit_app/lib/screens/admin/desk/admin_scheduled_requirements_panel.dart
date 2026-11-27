import 'package:flutter/material.dart';
import '../../../models/admin_class.dart';
import '../../../services/admin_classes_service.dart';
import '../../../services/admin_scheduled_requirements_service.dart';
import '../../../services/api_client.dart';
import '../../../utils/attachment_launcher.dart';
import '../../../utils/pick_files.dart';
import '../../../utils/ph_time.dart';
import '../../../utils/requirement_file_types.dart';
import '../../../widgets/admin/academic_year_picker.dart';
import '../../../widgets/common/desk_ui.dart';

/// Admin Documents > Scheduled Requirements: requirements the OJT office
/// posts with a due date and time for every OJT student of the academic
/// year, e.g. the Supervisor Evaluation Form for "1st Semester" and again
/// for "Final". Students are notified when one is posted and the day
/// before it's due; their instructors review the uploads.
class AdminScheduledRequirementsPanel extends StatefulWidget {
  final ApiClient client;
  const AdminScheduledRequirementsPanel({super.key, required this.client});

  @override
  State<AdminScheduledRequirementsPanel> createState() => _AdminScheduledRequirementsPanelState();
}

class _AdminScheduledRequirementsPanelState extends State<AdminScheduledRequirementsPanel> {
  late final AdminScheduledRequirementsService _service = AdminScheduledRequirementsService(widget.client);
  late final AdminClassesService _classes = HttpAdminClassesService(widget.client);
  List<ScheduledRequirement> _items = [];
  // The academic year shown; new posts go to it (default: the active one).
  String _year = '';
  List<AdminAcademicYear> _years = [];
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _classes.getAcademicYears().then((y) {
      if (mounted) setState(() => _years = y);
    }).catchError((_) {});
    _load();
  }

  Future<void> _load() async {
    try {
      final (year, items) = await _service.getAll(academicYear: _year.isEmpty ? null : _year);
      if (!mounted) return;
      setState(() {
        _year = year;
        _items = items;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e is ApiException ? e.message : 'Could not load scheduled requirements.';
        });
      }
    }
  }

  void _snack(String text, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), backgroundColor: error ? const Color(0xFFC62828) : null),
    );
  }

  Future<void> _run(Future<void> Function() action, String done) async {
    setState(() => _busy = true);
    try {
      await action();
      await _load();
      if (mounted) _snack(done);
    } catch (e) {
      if (mounted) _snack(e is ApiException ? e.message : 'Something went wrong.', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openForm([ScheduledRequirement? existing]) async {
    final form = await showDialog<_ScheduleForm>(
      context: context,
      builder: (_) => _ScheduleDialog(existing: existing, academicYear: _year),
    );
    if (form == null) return;
    final file = form.file;
    if (existing == null) {
      await _run(
        () => _service.create(
          academicYear: _year.isEmpty ? null : _year,
          title: form.title,
          period: form.period,
          description: form.description,
          dueAt: form.dueAt,
          templateBytes: file?.bytes,
          templateName: file?.name,
          templateContentType: requirementFileContentType(file?.extension),
        ),
        'Posted. Students in $_year were notified.',
      );
    } else {
      await _run(
        () => _service.update(
          existing.id,
          title: form.title,
          period: form.period,
          description: form.description,
          dueAt: form.dueAt,
          templateBytes: file?.bytes,
          templateName: file?.name,
          templateContentType: requirementFileContentType(file?.extension),
        ),
        'Changes saved.',
      );
    }
  }

  Future<void> _delete(ScheduledRequirement r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete "${r.title}"?'),
        content: Text(
          r.submitted > 0
              ? 'It will be removed for every student, together with the ${r.submitted} upload(s) already submitted. This can\'t be undone.'
              : 'It will be removed for every student. This can\'t be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFC62828)),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) await _run(() => _service.delete(r.id), 'Requirement deleted.');
  }

  Future<void> _openSubmissions(ScheduledRequirement r) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _SubmissionsDialog(service: _service, requirement: r),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DeskCard(
      title: 'Scheduled Requirements',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_years.isNotEmpty && _year.isNotEmpty) ...[
            AcademicYearPicker(
              years: _years,
              selected: _year,
              onSelected: (y) {
                setState(() {
                  _year = y;
                  _loading = true;
                });
                _load();
              },
            ),
            const SizedBox(width: 10),
          ],
          ElevatedButton.icon(
            onPressed: _busy || _loading ? null : () => _openForm(),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Post Requirement'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7A1424),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Transform.translate(
            offset: const Offset(0, -8),
            child: Text(
              'Requirements with a due date and time for every OJT student${_year.isEmpty ? '' : ' in $_year'}, '
              'e.g. the Supervisor Evaluation Form each period. Students are notified when one is posted and '
              'the day before it\'s due; their instructors review the uploads.',
              style: const TextStyle(fontSize: 11.5, color: DeskColors.muted, height: 1.4),
            ),
          ),
          const SizedBox(height: 6),
          if (_loading)
            const SizedBox(height: 200, child: Center(child: CircularProgressIndicator(color: DeskColors.maroon)))
          else if (_error != null)
            Text(_error!, style: const TextStyle(color: Color(0xFFC62828)))
          else if (_items.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
              decoration: BoxDecoration(
                color: const Color(0xFFFBF7F7),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFEDE3E3)),
              ),
              child: const Column(
                children: [
                  Icon(Icons.event_note_outlined, size: 34, color: DeskColors.maroon),
                  SizedBox(height: 10),
                  Text('Nothing scheduled yet', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  SizedBox(height: 4),
                  Text(
                    'Post the first one, e.g. "Supervisor Evaluation Form" for "1st Semester".',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: DeskColors.muted),
                  ),
                ],
              ),
            )
          else
            for (final r in _items) ...[
              _RequirementRow(
                requirement: r,
                busy: _busy,
                onSubmissions: () => _openSubmissions(r),
                onEdit: () => _openForm(r),
                onDelete: () => _delete(r),
              ),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}

class _RequirementRow extends StatelessWidget {
  final ScheduledRequirement requirement;
  final bool busy;
  final VoidCallback onSubmissions;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _RequirementRow({
    required this.requirement,
    required this.busy,
    required this.onSubmissions,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final r = requirement;
    final (stateLabel, tone) = r.isClosed
        ? ('Closed', DeskChipTone.grey)
        : r.isDueSoon
            ? ('Due soon', DeskChipTone.yellow)
            : ('Open', DeskChipTone.green);
    final progress = r.totalStudents == 0 ? 0.0 : r.submitted / r.totalStudents;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE6DEDE)),
      ),
      child: Row(
        children: [
          const DeskIconBox(icon: Icons.assignment_outlined, size: 38),
          const SizedBox(width: 12),
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    DeskStatusChip(label: r.period, tone: DeskChipTone.red),
                    DeskStatusChip(label: stateLabel, tone: tone),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.schedule, size: 13, color: DeskColors.muted),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        r.dueAt == null ? 'No due date' : 'Due ${formatPh(r.dueAt!, 'MMM d, yyyy · h:mm a')}',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF333333)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Icon(Icons.description_outlined, size: 13, color: DeskColors.muted),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        r.templateName ?? 'No template',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: r.templateName == null ? const Color(0xFFB85A1A) : const Color(0xFF333333),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${r.submitted} of ${r.totalStudents} submitted',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 7,
                    backgroundColor: const Color(0xFFEDE6E6),
                    valueColor: const AlwaysStoppedAnimation(Color(0xFF7A1424)),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${r.approved} approved${r.late > 0 ? ' · ${r.late} late' : ''}',
                  style: TextStyle(fontSize: 10.5, color: r.late > 0 ? const Color(0xFFC62828) : DeskColors.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: onSubmissions,
            style: TextButton.styleFrom(foregroundColor: DeskColors.maroon),
            child: const Text('View Students', style: TextStyle(fontSize: 12)),
          ),
          PopupMenuButton<String>(
            tooltip: 'More',
            enabled: !busy,
            onSelected: (v) => v == 'edit' ? onEdit() : onDelete(),
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
    );
  }
}

class _ScheduleForm {
  final String title;
  final String period;
  final String description;
  final DateTime dueAt;
  final PickedFile? file;
  const _ScheduleForm({required this.title, required this.period, required this.description, required this.dueAt, this.file});
}

class _ScheduleDialog extends StatefulWidget {
  final ScheduledRequirement? existing;
  final String academicYear;
  const _ScheduleDialog({this.existing, required this.academicYear});

  @override
  State<_ScheduleDialog> createState() => _ScheduleDialogState();
}

class _ScheduleDialogState extends State<_ScheduleDialog> {
  static const _periods = ['1st Semester', '2nd Semester', 'Midterm', 'Final'];

  late final _title = TextEditingController(text: widget.existing?.title ?? '');
  late final _period = TextEditingController(text: widget.existing?.period ?? '');
  late final _description = TextEditingController(text: widget.existing?.description ?? '');
  late DateTime? _date = widget.existing?.dueAt;
  late TimeOfDay _time = widget.existing?.dueAt != null
      ? TimeOfDay.fromDateTime(widget.existing!.dueAt!)
      : const TimeOfDay(hour: 17, minute: 0);
  PickedFile? _file;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _period.dispose();
    _description.dispose();
    super.dispose();
  }

  DateTime? get _dueAt =>
      _date == null ? null : DateTime(_date!.year, _date!.month, _date!.day, _time.hour, _time.minute);

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now.add(const Duration(days: 7)),
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }

  void _submit() {
    final title = _title.text.trim();
    final period = _period.text.trim();
    final due = _dueAt;
    if (title.isEmpty || period.isEmpty) {
      setState(() => _error = 'Enter the requirement name and its period.');
      return;
    }
    if (due == null) {
      setState(() => _error = 'Choose the due date.');
      return;
    }
    if (widget.existing == null && !due.isAfter(DateTime.now())) {
      setState(() => _error = 'The due date and time must be in the future.');
      return;
    }
    Navigator.pop(
      context,
      _ScheduleForm(title: title, period: period, description: _description.text.trim(), dueAt: due, file: _file),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;
    const label = TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF333333));
    InputDecoration deco(String hint) => InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(fontSize: 12.5, color: DeskColors.muted),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFDDDDDD)),
          ),
        );
    final existingFile = widget.existing?.templateName;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      editing ? 'Edit Scheduled Requirement' : 'Post Requirement',
                      style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    style: IconButton.styleFrom(backgroundColor: const Color(0xFFF8E9EA)),
                    icon: const Icon(Icons.close, size: 16, color: DeskColors.maroon),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text('Requirement Name', style: label),
              const SizedBox(height: 6),
              TextField(controller: _title, style: const TextStyle(fontSize: 13), decoration: deco('e.g. Supervisor Evaluation Form')),
              const SizedBox(height: 12),
              const Text('Period', style: label),
              const SizedBox(height: 6),
              TextField(controller: _period, style: const TextStyle(fontSize: 13), decoration: deco('e.g. 1st Semester')),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                children: [
                  for (final p in _periods)
                    ActionChip(
                      label: Text(p, style: const TextStyle(fontSize: 11.5)),
                      onPressed: () => setState(() => _period.text = p),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              const Text('Due Date and Time', style: label),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickDate,
                      icon: const Icon(Icons.event, size: 16),
                      label: Text(_date == null ? 'Choose date' : formatPh(_date!, 'MMM d, yyyy')),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF333333),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickTime,
                      icon: const Icon(Icons.access_time, size: 16),
                      label: Text(_time.format(context)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF333333),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text.rich(
                TextSpan(
                  text: 'Instructions ',
                  style: label,
                  children: [TextSpan(text: '(optional)', style: TextStyle(fontWeight: FontWeight.w400, color: DeskColors.muted))],
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _description,
                minLines: 2,
                maxLines: 4,
                style: const TextStyle(fontSize: 13),
                decoration: deco('e.g. Have your supervisor fill in and sign the form, then upload a scan.'),
              ),
              const SizedBox(height: 12),
              const Text.rich(
                TextSpan(
                  text: 'Form / Template ',
                  style: label,
                  children: [TextSpan(text: '(optional)', style: TextStyle(fontWeight: FontWeight.w400, color: DeskColors.muted))],
                ),
              ),
              const SizedBox(height: 6),
              OutlinedButton.icon(
                onPressed: () async {
                  final picked = await pickFilesWithData(type: FileType.custom, allowedExtensions: requirementFileExtensions);
                  final f = picked?.files.single;
                  if (f != null && f.bytes != null) setState(() => _file = f);
                },
                icon: const Icon(Icons.upload_file, size: 16),
                label: Text(
                  _file?.name ?? existingFile ?? 'Choose a file (PDF, DOC, DOCX, XLS, XLSX · max 10 MB)',
                  overflow: TextOverflow.ellipsis,
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: DeskColors.maroon,
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                  alignment: Alignment.centerLeft,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFFFBF4F4), borderRadius: BorderRadius.circular(8)),
                child: Text(
                  editing
                      ? 'Changing the due date notifies the students and re-sends the day-before reminder.'
                      : 'All OJT students in ${widget.academicYear.isEmpty ? 'the active academic year' : widget.academicYear} '
                          'are notified now, and again the day before it\'s due. Late uploads are accepted but marked late.',
                  style: const TextStyle(fontSize: 11, height: 1.4, color: Color(0xFF555555)),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: const TextStyle(color: Color(0xFFC62828), fontSize: 12)),
              ],
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: DeskColors.maroon,
                      side: const BorderSide(color: DeskColors.maroon),
                      minimumSize: const Size(100, 42),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7A1424),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(150, 42),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text(editing ? 'Save Changes' : 'Post & Notify'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubmissionsDialog extends StatefulWidget {
  final AdminScheduledRequirementsService service;
  final ScheduledRequirement requirement;
  const _SubmissionsDialog({required this.service, required this.requirement});

  @override
  State<_SubmissionsDialog> createState() => _SubmissionsDialogState();
}

class _SubmissionsDialogState extends State<_SubmissionsDialog> {
  List<ScheduledSubmission>? _rows;
  String? _error;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    widget.service.getSubmissions(widget.requirement.id).then(
      (rows) => mounted ? setState(() => _rows = rows) : null,
      onError: (e) => mounted ? setState(() => _error = e is ApiException ? e.message : 'Could not load.') : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.requirement;
    final rows = (_rows ?? const <ScheduledSubmission>[]).where((s) {
      if (_filter == 'missing') return s.status == 'missing' || s.status == 'rejected';
      if (_filter == 'submitted') return s.status == 'submitted' || s.status == 'approved';
      if (_filter == 'late') return s.isLate;
      return true;
    }).toList();
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: SizedBox(
        width: 640,
        height: 520,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                        Text(
                          '${r.period}${r.dueAt == null ? '' : ' · Due ${formatPh(r.dueAt!, 'MMM d, yyyy · h:mm a')}'}',
                          style: const TextStyle(fontSize: 12, color: DeskColors.muted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                children: [
                  for (final (value, text) in const [
                    ('all', 'All'),
                    ('missing', 'Not submitted'),
                    ('submitted', 'Submitted'),
                    ('late', 'Late'),
                  ])
                    ChoiceChip(
                      label: Text(text, style: const TextStyle(fontSize: 11.5)),
                      selected: _filter == value,
                      onSelected: (_) => setState(() => _filter = value),
                      selectedColor: const Color(0xFFF8E9EA),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: _error != null
                    ? Center(child: Text(_error!))
                    : _rows == null
                        ? const Center(child: CircularProgressIndicator(color: DeskColors.maroon))
                        : rows.isEmpty
                            ? const Center(child: Text('No students here.', style: TextStyle(color: DeskColors.muted)))
                            : ListView.separated(
                                itemCount: rows.length,
                                separatorBuilder: (_, _) => const Divider(height: 1, color: Color(0xFFEDEDED)),
                                itemBuilder: (context, i) {
                                  final s = rows[i];
                                  final (label, tone) = switch (s.status) {
                                    'approved' => ('Approved', DeskChipTone.green),
                                    'submitted' => ('Submitted', DeskChipTone.blue),
                                    'rejected' => ('Re-upload', DeskChipTone.red),
                                    _ => ('Not submitted', DeskChipTone.grey),
                                  };
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    child: Row(
                                      children: [
                                        DeskAvatar(name: s.name, radius: 15),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(s.name, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                                              Text(
                                                [
                                                  s.section,
                                                  if (s.submittedAt != null) formatPh(s.submittedAt!, 'MMM d, h:mm a'),
                                                ].join(' · '),
                                                style: const TextStyle(fontSize: 10.5, color: DeskColors.muted),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (s.isLate) ...[
                                          const DeskStatusChip(label: 'Late', tone: DeskChipTone.red),
                                          const SizedBox(width: 6),
                                        ],
                                        DeskStatusChip(label: label, tone: tone),
                                        if (s.fileUrl != null)
                                          IconButton(
                                            tooltip: 'Open file',
                                            onPressed: () => openAttachment(ApiClient.resolveUrl(s.fileUrl!)),
                                            icon: const Icon(Icons.visibility_outlined, size: 18, color: Color(0xFF6B9BD1)),
                                          )
                                        else
                                          const SizedBox(width: 48),
                                      ],
                                    ),
                                  );
                                },
                              ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
