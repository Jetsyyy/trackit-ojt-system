import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../services/admin_accounts_service.dart';
import '../../services/api_client.dart';
import '../../utils/app_colors.dart';
import 'admin_faculty_screen.dart';

/// Instructor onboarding (System Revisions item 19):
/// - Requests: instructors who registered with a code wait here; the
///   Admin approves them and assigns their section(s), or declines.
/// - Registration Codes: single-use codes the Admin generates and hands
///   to one instructor each.
/// - Sections: the program/section/year list students register into,
///   each with its student code and assigned instructor.
class AdminInstructorAccountsScreen extends StatefulWidget {
  final ApiClient client;

  const AdminInstructorAccountsScreen({super.key, required this.client});

  @override
  State<AdminInstructorAccountsScreen> createState() => _AdminInstructorAccountsScreenState();
}

class _AdminInstructorAccountsScreenState extends State<AdminInstructorAccountsScreen> {
  late final AdminAccountsService _service = AdminAccountsService(widget.client);

  List<InstructorAccountRequest> _requests = [];
  List<InstructorRegistrationCode> _codes = [];
  List<AdminSection> _sections = [];
  List<ApprovedInstructor> _instructors = [];
  String? _activeYear;
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        _service.getRequests(),
        _service.getCodes(),
        _service.getSections(),
        _service.getApprovedInstructors(),
        _service.getActiveAcademicYear().catchError((_) => null),
      ]);
      if (!mounted) return;
      setState(() {
        _requests = results[0] as List<InstructorAccountRequest>;
        _codes = results[1] as List<InstructorRegistrationCode>;
        _sections = (results[2] as List<AdminSection>)
          ..sort((a, b) {
            final year = b.academicYear.compareTo(a.academicYear);
            return year != 0 ? year : a.label.compareTo(b.label);
          });
        _instructors = results[3] as List<ApprovedInstructor>;
        _activeYear = results[4] as String?;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  void _snack(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? AppColors.statRedIcon : AppColors.successGreenText,
      ),
    );
  }

  Future<void> _run(Future<void> Function() action, String success) async {
    try {
      await action();
      if (!mounted) return;
      _snack(success);
    } catch (e) {
      if (!mounted) return;
      _snack(e is ApiException ? e.message : 'Something went wrong. Please try again.', error: true);
    }
    await _load();
  }

  List<AdminSection> get _unassignedSections =>
      _sections.where((s) => s.instructorId == null).toList();

  // ---------- Requests ----------

  Future<void> _approve(InstructorAccountRequest request) async {
    final sectionIds = await showDialog<List<int>>(
      context: context,
      builder: (context) => _AssignSectionsDialog(
        instructorName: request.name,
        sections: _unassignedSections,
      ),
    );
    if (sectionIds == null) return;
    await _run(
      () => _service.decideRequest(instructorId: request.id, approve: true, sectionIds: sectionIds),
      '${request.name} approved and assigned ${sectionIds.length} '
          'section${sectionIds.length == 1 ? '' : 's'}.',
    );
  }

  Future<void> _decline(InstructorAccountRequest request) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => _TextPromptDialog(
        title: 'Decline ${request.name}?',
        message: 'They won\'t be able to log in.',
        label: 'Reason',
        confirmLabel: 'Decline',
        required: true,
        danger: true,
      ),
    );
    if (reason == null) return;
    await _run(
      () => _service.decideRequest(instructorId: request.id, approve: false, reason: reason),
      '${request.name}\'s registration was declined.',
    );
  }

  // ---------- Codes ----------

  Future<void> _generateCode() async {
    final note = await showDialog<String>(
      context: context,
      builder: (context) => const _TextPromptDialog(
        title: 'Generate Registration Code',
        message: 'Each code works for one instructor registration only.',
        label: 'Who is it for? (optional)',
        confirmLabel: 'Generate',
        required: false,
      ),
    );
    if (note == null) return;
    try {
      final code = await _service.createCode(note: note);
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Code Generated'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Give this code to the instructor. They register with it, '
                  'then you approve them here and assign their section.'),
              const SizedBox(height: 16),
              SelectableText(
                code.code,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  color: AppColors.primaryMaroon,
                ),
              ),
            ],
          ),
          actions: [
            TextButton.icon(
              onPressed: () => Clipboard.setData(ClipboardData(text: code.code)),
              icon: const Icon(Icons.copy, size: 16),
              label: const Text('Copy'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryMaroon,
                foregroundColor: Colors.white,
              ),
              child: const Text('Done'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _snack(e is ApiException ? e.message : 'Could not generate a code.', error: true);
    }
  }

  Future<void> _revokeCode(InstructorRegistrationCode code) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Revoke ${code.code}?'),
        content: const Text('Nobody will be able to register with it.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.statRedIcon),
            child: const Text('Revoke'),
          ),
        ],
      ),
    );
    if (ok == true) await _run(() => _service.revokeCode(code.id), 'Code revoked.');
  }

  // ---------- Sections ----------

  Future<void> _addSection() async {
    final created = await showDialog<bool>(
      context: context,
      builder: (context) => _AddSectionDialog(
        service: _service,
        // The server treats the newest year with sections as the active
        // one (utils/classHelpers.js), so default to that.
        defaultYear: _activeYear ??
            (_sections.isEmpty ? null : (_sections.map((s) => s.academicYear).toList()..sort()).last),
      ),
    );
    if (created == true) {
      _snack('Section added.');
      await _load();
    }
  }

  Future<void> _changeInstructor(AdminSection section) async {
    final choice = await showDialog<_InstructorChoice>(
      context: context,
      builder: (context) => _PickInstructorDialog(
        section: section,
        instructors: _instructors.where((i) => i.isActive).toList(),
      ),
    );
    if (choice == null) return;
    await _run(
      () => _service.assignSection(sectionId: section.id, instructorId: choice.instructorId),
      choice.instructorId == null ? '${section.label} is now unassigned.' : 'Instructor assigned.',
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Could not load: $_error', textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }

    return DefaultTabController(
      length: 4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Instructors & Sections',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 4),
          const Text(
            'Generate registration codes, approve instructor accounts and assign their sections.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: AppColors.primaryMaroon,
            indicatorColor: AppColors.primaryMaroon,
            unselectedLabelColor: AppColors.textSecondary,
            tabs: [
              Tab(text: 'Requests (${_requests.length})'),
              const Tab(text: 'Registration Codes'),
              Tab(text: 'Sections (${_sections.length})'),
              const Tab(text: 'Faculty'),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: TabBarView(
              children: [
                _buildRequests(),
                _buildCodes(),
                _buildSections(),
                // Approved instructors with their details and sections --
                // moved here from the removed Class Management page
                // (System Revisions item 16).
                AdminFacultyScreen(client: widget.client, academicYear: null),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _empty(IconData icon, String title, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: AppColors.textSecondary),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _buildRequests() {
    if (_requests.isEmpty) {
      return _empty(
        Icons.how_to_reg_outlined,
        'No pending instructor requests',
        'Instructors who register with a code you generated appear here.',
      );
    }
    final dateFormat = DateFormat('MMM d, yyyy h:mm a');
    return ListView.separated(
      itemCount: _requests.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final r = _requests[index];
        return _Card(
          child: Wrap(
            spacing: 16,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 220, maxWidth: 520),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 4),
                    Text('${r.instructorNumber}  ·  ${r.email}${r.phone != null ? '  ·  ${r.phone}' : ''}',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    Text('Requested ${dateFormat.format(r.requestedAt)}',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton(
                    onPressed: () => _decline(r),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.statRedIcon,
                      side: const BorderSide(color: AppColors.statRedIcon),
                    ),
                    child: const Text('Decline'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => _approve(r),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.successGreenText,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Approve & Assign Section'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCodes() {
    final dateFormat = DateFormat('MMM d, yyyy');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ElevatedButton.icon(
          onPressed: _generateCode,
          icon: const Icon(Icons.add),
          label: const Text('Generate Code'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryMaroon,
            foregroundColor: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _codes.isEmpty
              ? _empty(Icons.vpn_key_outlined, 'No codes yet',
                  'Generate a code for each new instructor.')
              : ListView.separated(
                  itemCount: _codes.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final c = _codes[index];
                    final (Color fg, Color bg, String label) = switch (c.status) {
                      'used' => (AppColors.successGreenText, AppColors.successGreenBg, 'Used'),
                      'revoked' => (AppColors.textSecondary, AppColors.chipGrayBg, 'Revoked'),
                      _ => (AppColors.statBlueIcon, AppColors.statBlueBg, 'Available'),
                    };
                    return _Card(
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    SelectableText(
                                      c.code,
                                      style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
                                    ),
                                    const SizedBox(width: 8),
                                    _Pill(text: label, color: fg, background: bg),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  [
                                    if ((c.note ?? '').isNotEmpty) c.note!,
                                    'Created ${dateFormat.format(c.createdAt)}',
                                    if (c.usedByName != null) 'Used by ${c.usedByName}',
                                  ].join('  ·  '),
                                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          if (c.status == 'available') ...[
                            IconButton(
                              tooltip: 'Copy code',
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: c.code));
                                _snack('Code copied.');
                              },
                              icon: const Icon(Icons.copy, size: 18),
                            ),
                            TextButton(
                              onPressed: () => _revokeCode(c),
                              style: TextButton.styleFrom(foregroundColor: AppColors.statRedIcon),
                              child: const Text('Revoke'),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildSections() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ElevatedButton.icon(
          onPressed: _addSection,
          icon: const Icon(Icons.add),
          label: const Text('Add Section'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryMaroon,
            foregroundColor: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _sections.isEmpty
              ? _empty(Icons.groups_outlined, 'No sections yet',
                  'Add a section, then assign it to an instructor.')
              : ListView.separated(
                  itemCount: _sections.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final s = _sections[index];
                    return _Card(
                      child: Wrap(
                        spacing: 16,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        alignment: WrapAlignment.spaceBetween,
                        children: [
                          ConstrainedBox(
                            constraints: const BoxConstraints(minWidth: 220, maxWidth: 520),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${s.label}  ·  ${s.academicYear}',
                                    style: const TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                Text(
                                  s.instructorName ?? 'No instructor assigned',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: s.instructorName == null
                                        ? AppColors.statOrangeIcon
                                        : AppColors.textSecondary,
                                  ),
                                ),
                                Text(
                                  'Student code: ${s.activationCode}  ·  ${s.studentCount} '
                                  'student${s.studentCount == 1 ? '' : 's'}',
                                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          OutlinedButton(
                            onPressed: () => _changeInstructor(s),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primaryMaroon,
                              side: const BorderSide(color: AppColors.primaryMaroon),
                            ),
                            child: Text(s.instructorId == null ? 'Assign Instructor' : 'Change Instructor'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;

  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.chipGrayBg),
      ),
      child: child,
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final Color color;
  final Color background;

  const _Pill({required this.text, required this.color, required this.background});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(20)),
      child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

/// Picks the unassigned sections to give a newly approved instructor;
/// returns the chosen section ids, or null if cancelled.
class _AssignSectionsDialog extends StatefulWidget {
  final String instructorName;
  final List<AdminSection> sections;

  const _AssignSectionsDialog({required this.instructorName, required this.sections});

  @override
  State<_AssignSectionsDialog> createState() => _AssignSectionsDialogState();
}

class _AssignSectionsDialogState extends State<_AssignSectionsDialog> {
  final Set<int> _selected = {};

  @override
  Widget build(BuildContext context) {
    final sections = widget.sections;
    return AlertDialog(
      title: Text('Approve ${widget.instructorName}'),
      content: SizedBox(
        width: 420,
        child: sections.isEmpty
            ? const Text(
                'There are no unassigned sections. Add a section in the Sections tab first, '
                'then approve this instructor.',
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Assign at least one section:'),
                  const SizedBox(height: 8),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        for (final s in sections)
                          CheckboxListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            activeColor: AppColors.primaryMaroon,
                            value: _selected.contains(s.id),
                            title: Text(s.label),
                            subtitle: Text(s.academicYear),
                            onChanged: (checked) => setState(() {
                              if (checked == true) {
                                _selected.add(s.id);
                              } else {
                                _selected.remove(s.id);
                              }
                            }),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _selected.isEmpty ? null : () => Navigator.of(context).pop(_selected.toList()),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.successGreenText,
            foregroundColor: Colors.white,
          ),
          child: const Text('Approve'),
        ),
      ],
    );
  }
}

class _InstructorChoice {
  final int? instructorId;

  const _InstructorChoice(this.instructorId);
}

class _PickInstructorDialog extends StatefulWidget {
  final AdminSection section;
  final List<ApprovedInstructor> instructors;

  const _PickInstructorDialog({required this.section, required this.instructors});

  @override
  State<_PickInstructorDialog> createState() => _PickInstructorDialogState();
}

class _PickInstructorDialogState extends State<_PickInstructorDialog> {
  late int? _selected = widget.section.instructorId;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Instructor for ${widget.section.label}'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<int?>(
              initialValue: _selected,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Instructor'),
              items: [
                const DropdownMenuItem<int?>(value: null, child: Text('No instructor (unassigned)')),
                for (final i in widget.instructors)
                  DropdownMenuItem<int?>(value: i.id, child: Text('${i.name} (${i.instructorNumber})')),
              ],
              onChanged: (value) => setState(() => _selected = value),
            ),
            if (widget.section.studentCount > 0) ...[
              const SizedBox(height: 12),
              Text(
                'The section\'s ${widget.section.studentCount} student'
                '${widget.section.studentCount == 1 ? '' : 's'} move to the instructor you pick.',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _selected == widget.section.instructorId
              ? null
              : () => Navigator.of(context).pop(_InstructorChoice(_selected)),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryMaroon,
            foregroundColor: Colors.white,
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _AddSectionDialog extends StatefulWidget {
  final AdminAccountsService service;
  final String? defaultYear;

  const _AddSectionDialog({required this.service, this.defaultYear});

  @override
  State<_AddSectionDialog> createState() => _AddSectionDialogState();
}

class _AddSectionDialogState extends State<_AddSectionDialog> {
  final _formKey = GlobalKey<FormState>();
  final _program = TextEditingController(text: 'BSIT');
  final _section = TextEditingController();
  late final TextEditingController _year =
      TextEditingController(text: widget.defaultYear ?? _defaultYear());
  bool _saving = false;
  String? _error;

  // Academic years start in August: Aug 2026 onward is 2026-2027.
  static String _defaultYear() {
    final now = DateTime.now();
    final start = now.month >= 8 ? now.year : now.year - 1;
    return '$start-${start + 1}';
  }

  @override
  void dispose() {
    _program.dispose();
    _section.dispose();
    _year.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.service.createSection(
        program: _program.text.trim(),
        section: _section.text.trim(),
        academicYear: _year.text.trim(),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e is ApiException ? e.message : 'Could not add the section.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Section'),
      content: SizedBox(
        width: 380,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(_error!, style: const TextStyle(color: AppColors.statRedIcon)),
                ),
              TextFormField(
                controller: _program,
                decoration: const InputDecoration(labelText: 'Program', hintText: 'e.g. BSIT'),
                validator: (v) => (v ?? '').trim().isEmpty ? 'Program is required' : null,
              ),
              TextFormField(
                controller: _section,
                decoration: const InputDecoration(labelText: 'Section', hintText: 'e.g. 4A'),
                validator: (v) => (v ?? '').trim().isEmpty ? 'Section is required' : null,
              ),
              TextFormField(
                controller: _year,
                decoration: const InputDecoration(labelText: 'Academic Year', hintText: 'YYYY-YYYY'),
                validator: (v) => RegExp(r'^\d{4}-\d{4}$').hasMatch((v ?? '').trim())
                    ? null
                    : 'Use the format YYYY-YYYY',
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.of(context).pop(), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryMaroon,
            foregroundColor: Colors.white,
          ),
          child: const Text('Add'),
        ),
      ],
    );
  }
}

/// A single text field prompt; returns the text (possibly empty when not
/// [required]) or null if cancelled.
class _TextPromptDialog extends StatefulWidget {
  final String title;
  final String message;
  final String label;
  final String confirmLabel;
  final bool required;
  final bool danger;

  const _TextPromptDialog({
    required this.title,
    required this.message,
    required this.label,
    required this.confirmLabel,
    required this.required,
    this.danger = false,
  });

  @override
  State<_TextPromptDialog> createState() => _TextPromptDialogState();
}

class _TextPromptDialogState extends State<_TextPromptDialog> {
  final _controller = TextEditingController();
  bool _showError = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (widget.required && text.isEmpty) {
      setState(() => _showError = true);
      return;
    }
    Navigator.of(context).pop(text);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.message),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              autofocus: true,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: widget.label,
                errorText: _showError ? 'This is required' : null,
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: widget.danger ? AppColors.statRedIcon : AppColors.primaryMaroon,
            foregroundColor: Colors.white,
          ),
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
