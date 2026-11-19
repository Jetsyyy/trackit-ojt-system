import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../models/admin_class.dart';
import '../../../models/admin_instructor.dart';
import '../../../services/admin_accounts_service.dart';
import '../../../services/admin_classes_service.dart';
import '../../../services/admin_instructors_service.dart';
import '../../../services/api_client.dart';
import '../../../utils/file_download.dart';
import '../../../widgets/common/desk_ui.dart';

/// Admin Faculty (TrackIT admin mockups): Account Requests, the Faculty
/// List (active / inactive), and the selected instructor's details with
/// their assigned sections and students. "Add Instructor" opens the
/// Invite Instructor dialog with a single-use registration code.
class AdminFacultyDesk extends StatefulWidget {
  final ApiClient client;

  const AdminFacultyDesk({super.key, required this.client});

  @override
  State<AdminFacultyDesk> createState() => _AdminFacultyDeskState();
}

class _AdminFacultyDeskState extends State<AdminFacultyDesk> {
  static const _pageSize = 7;

  late final AdminAccountsService _accounts = AdminAccountsService(widget.client);
  late final AdminInstructorsService _instructors = HttpAdminInstructorsService(widget.client);
  late final AdminClassesService _classes = HttpAdminClassesService(widget.client);

  List<InstructorAccountRequest> _requests = [];
  List<AdminInstructorSummary> _faculty = [];
  List<AdminSection> _sections = [];
  String? _activeYear;
  bool _loading = true;
  String _query = '';

  int? _selectedId;
  AdminInstructorDetail? _detail;
  bool _loadingDetail = false;
  int? _sectionId;
  AdminClassDetail? _classDetail;
  bool _loadingClass = false;
  String _studentQuery = '';
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _snack(String text, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), backgroundColor: error ? const Color(0xFFC62828) : null),
    );
  }

  String _err(Object e, String fallback) => e is ApiException ? e.message : fallback;

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        _accounts.getRequests(),
        _instructors.getInstructors(),
        _accounts.getSections(),
        _accounts.getActiveAcademicYear(),
      ]);
      if (!mounted) return;
      setState(() {
        _requests = results[0] as List<InstructorAccountRequest>;
        _faculty = results[1] as List<AdminInstructorSummary>;
        _sections = results[2] as List<AdminSection>;
        _activeYear = results[3] as String?;
        _loading = false;
      });
      final active = _faculty.where((f) => f.status == 'active').toList();
      if (_selectedId == null && (active.isNotEmpty || _faculty.isNotEmpty)) {
        _select((active.isNotEmpty ? active : _faculty).first.id);
      } else if (_selectedId != null) {
        _select(_selectedId!, keepSection: true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _snack(_err(e, 'Could not load faculty.'), error: true);
      }
    }
  }

  List<AdminSection> _sectionsOf(int instructorId) => _sections
      .where((s) => s.instructorId == instructorId && (_activeYear == null || s.academicYear == _activeYear))
      .toList();

  String _sectionsLine(int instructorId) {
    final list = _sectionsOf(instructorId);
    if (list.isEmpty) return 'No assigned section';
    return list.map((s) => '${s.program} - ${s.section}').join(', ');
  }

  Future<void> _select(int id, {bool keepSection = false}) async {
    setState(() {
      _selectedId = id;
      _loadingDetail = true;
      if (!keepSection) {
        _sectionId = null;
        _classDetail = null;
      }
    });
    try {
      final detail = await _instructors.getInstructorDetail(id, academicYear: _activeYear);
      if (!mounted || _selectedId != id) return;
      setState(() {
        _detail = detail;
        _loadingDetail = false;
      });
      final sections = detail.assignedSections;
      final keep = keepSection && sections.any((s) => s.id == _sectionId);
      if (sections.isNotEmpty) _openSection(keep ? _sectionId! : sections.first.id);
    } catch (e) {
      if (mounted) {
        setState(() => _loadingDetail = false);
        _snack(_err(e, 'Could not load this instructor.'), error: true);
      }
    }
  }

  Future<void> _openSection(int classId) async {
    setState(() {
      _sectionId = classId;
      _loadingClass = true;
      _page = 0;
      _studentQuery = '';
    });
    try {
      final detail = await _classes.getClassDetail(classId);
      if (!mounted || _sectionId != classId) return;
      setState(() {
        _classDetail = detail;
        _loadingClass = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loadingClass = false);
        _snack(_err(e, 'Could not load the section.'), error: true);
      }
    }
  }

  // ------------------------------------------------------------ actions

  Future<void> _decide(InstructorAccountRequest r, bool approve) async {
    List<int> ids = const [];
    String? reason;
    if (approve) {
      final picked = await _pickSections(title: 'Accept ${r.name}', action: 'Accept & Assign');
      if (picked == null) return;
      ids = picked;
    } else {
      reason = await _askText(
        title: 'Decline ${r.name}?',
        label: 'Reason (sent to the instructor)',
        action: 'Decline',
        danger: true,
      );
      if (reason == null) return;
    }
    try {
      await _accounts.decideRequest(instructorId: r.id, approve: approve, sectionIds: ids, reason: reason);
      _snack(approve ? '${r.name} was approved.' : '${r.name}\'s request was declined.');
      await _load();
    } catch (e) {
      _snack(_err(e, 'Could not save the decision.'), error: true);
    }
  }

  Future<void> _assignSections() async {
    final detail = _detail;
    if (detail == null) return;
    final picked = await _pickSections(title: 'Assign sections to ${detail.name}', action: 'Assign');
    if (picked == null || picked.isEmpty) return;
    try {
      for (final id in picked) {
        await _accounts.assignSection(sectionId: id, instructorId: detail.id);
      }
      _snack('Section${picked.length == 1 ? '' : 's'} assigned.');
      await _load();
    } catch (e) {
      _snack(_err(e, 'Could not assign the section.'), error: true);
    }
  }

  Future<void> _unassignSection(AdminAssignedSection s) async {
    final ok = await _confirm(
      'Unassign ${s.program} - ${s.section}?',
      'The section keeps its students; it just won\'t have an instructor until you assign one.',
      'Unassign',
    );
    if (ok != true) return;
    try {
      await _accounts.assignSection(sectionId: s.id, instructorId: null);
      _snack('Section unassigned.');
      await _load();
    } catch (e) {
      _snack(_err(e, 'Could not unassign the section.'), error: true);
    }
  }

  Future<void> _toggleAccess() async {
    final d = _detail;
    if (d == null) return;
    final revoking = d.status == 'active';
    final ok = await _confirm(
      revoking ? 'Revoke ${d.name}\'s access?' : 'Restore ${d.name}\'s access?',
      revoking
          ? 'They won\'t be able to sign in until you restore access.'
          : 'They will be able to sign in again.',
      revoking ? 'Revoke Access' : 'Restore Access',
    );
    if (ok != true) return;
    try {
      revoking ? await _instructors.revokeAccess(d.id) : await _instructors.reactivate(d.id);
      _snack(revoking ? 'Access revoked.' : 'Access restored.');
      await _load();
    } catch (e) {
      _snack(_err(e, 'Could not update access.'), error: true);
    }
  }

  Future<void> _editInfo() async {
    final d = _detail;
    if (d == null) return;
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => _EditInstructorDialog(detail: d),
    );
    if (result == null) return;
    try {
      await _instructors.updateInstructor(
        instructorId: d.id,
        name: result['name'],
        email: result['email'],
        phone: result['phone'],
        department: result['department'],
        position: result['position'],
      );
      _snack('Information updated.');
      await _load();
    } catch (e) {
      _snack(_err(e, 'Could not update the information.'), error: true);
    }
  }

  Future<void> _downloadList(String format) async {
    final id = _sectionId;
    if (id == null) return;
    try {
      final file = await _classes.exportClasses([id], format: format);
      final saved = downloadBytes(filename: file.filename ?? 'Section-List.$format', bytes: file.bytes);
      _snack(saved ? 'List downloaded.' : 'Downloads are available in the web app.');
    } catch (e) {
      _snack(_err(e, 'Could not download the list.'), error: true);
    }
  }

  Future<void> _invite() async {
    await showDialog<void>(context: context, builder: (context) => _InviteDialog(accounts: _accounts));
  }

  // ------------------------------------------------------------ dialogs

  Future<bool?> _confirm(String title, String body, String action) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: DeskColors.maroon),
            onPressed: () => Navigator.pop(context, true),
            child: Text(action),
          ),
        ],
      ),
    );
  }

  Future<String?> _askText({required String title, required String label, required String action, bool danger = false}) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 380,
          child: TextField(
            controller: controller,
            autofocus: true,
            maxLines: 3,
            decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: danger ? const Color(0xFFC62828) : DeskColors.maroon),
            onPressed: () {
              final t = controller.text.trim();
              if (t.isNotEmpty) Navigator.pop(context, t);
            },
            child: Text(action),
          ),
        ],
      ),
    );
  }

  /// Unassigned sections of the active year, plus "create a new section".
  Future<List<int>?> _pickSections({required String title, required String action}) {
    return showDialog<List<int>>(
      context: context,
      builder: (context) => _SectionPickerDialog(
        title: title,
        action: action,
        accounts: _accounts,
        activeYear: _activeYear,
      ),
    );
  }

  // ----------------------------------------------------------------- UI

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const ColoredBox(color: DeskColors.page, child: Center(child: CircularProgressIndicator(color: DeskColors.maroon)));
    }
    final height = MediaQuery.sizeOf(context).height - 130;
    return DeskPage(
      title: 'Faculty',
      onRefresh: _load,
      children: [
        SizedBox(
          height: height < 620 ? 620 : height,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(width: 330, child: _leftColumn()),
              const SizedBox(width: 16),
              Expanded(child: _rightColumn()),
            ],
          ),
        ),
      ],
    );
  }

  Widget _leftColumn() {
    final q = _query.trim().toLowerCase();
    bool match(AdminInstructorSummary f) => q.isEmpty || f.name.toLowerCase().contains(q) || f.instructorNumber.toLowerCase().contains(q);
    final active = _faculty.where((f) => f.status == 'active' && match(f)).toList();
    final inactive = _faculty.where((f) => f.status != 'active' && match(f)).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_requests.isNotEmpty) ...[
          DeskCard(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Text('Account Requests', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                    const SizedBox(width: 8),
                    DeskPill(label: '${_requests.length} pending'),
                  ],
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 150),
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        for (final r in _requests)
                          Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: DeskColors.tile,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: DeskColors.tileBorder),
                            ),
                            child: Row(
                              children: [
                                _Initials(name: r.name, background: const Color(0xFFFCE7B8), foreground: const Color(0xFFB7791F), radius: 15),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(r.name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                                      Text(r.email, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 9.5, color: DeskColors.muted)),
                                    ],
                                  ),
                                ),
                                _PillButton(label: 'Decline', outlined: true, onTap: () => _decide(r, false)),
                                const SizedBox(width: 4),
                                _PillButton(label: 'Accept', onTap: () => _decide(r, true)),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        Expanded(
          child: DeskCard(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            title: 'Faculty List',
            trailing: Text('${_faculty.length} instructors', style: const TextStyle(fontSize: 10.5, color: DeskColors.muted)),
            child: Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 34,
                    child: TextField(
                      onChanged: (v) => setState(() => _query = v),
                      style: const TextStyle(fontSize: 12),
                      decoration: InputDecoration(
                        hintText: 'Search instructor...',
                        hintStyle: const TextStyle(fontSize: 12, color: DeskColors.muted),
                        prefixIcon: const Icon(Icons.search, size: 18),
                        contentPadding: EdgeInsets.zero,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: const BorderSide(color: Color(0xFFD6D6D6)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: const BorderSide(color: DeskColors.maroon),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: ListView(
                      children: [
                        _groupLabel('ACTIVE', active.length),
                        for (final f in active) _facultyTile(f),
                        const SizedBox(height: 8),
                        _groupLabel('INACTIVE', inactive.length),
                        for (final f in inactive) _facultyTile(f),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 40,
                    child: ElevatedButton.icon(
                      onPressed: _invite,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add Instructor'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7A1424),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _groupLabel(String text, int count) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, top: 2),
      child: Row(
        children: [
          Text(text, style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: DeskColors.muted, letterSpacing: 0.4)),
          const SizedBox(width: 8),
          DeskCountBadge(count: count),
        ],
      ),
    );
  }

  Widget _facultyTile(AdminInstructorSummary f) {
    final selected = f.id == _selectedId;
    final active = f.status == 'active';
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: selected ? const Color(0xFF7A1424) : (active ? Colors.white : const Color(0xFFFAFAFA)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: selected ? const Color(0xFF7A1424) : const Color(0xFFDDDDDD)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => _select(f.id),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
            child: Row(
              children: [
                _Initials(
                  name: f.name,
                  background: selected ? Colors.white24 : (active ? const Color(0xFFF8E9EA) : const Color(0xFFEDEDED)),
                  foreground: selected ? Colors.white : (active ? DeskColors.maroon : DeskColors.muted),
                  radius: 15,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        f.name,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: selected ? Colors.white : (active ? const Color(0xFF1F1F1F) : DeskColors.muted),
                        ),
                      ),
                      Text(
                        active ? _sectionsLine(f.id) : 'No assigned sections',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 9.5, color: selected ? Colors.white70 : DeskColors.muted),
                      ),
                    ],
                  ),
                ),
                DeskStatusChip(label: active ? 'Active' : 'Inactive', tone: active ? DeskChipTone.green : DeskChipTone.red),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _rightColumn() {
    final d = _detail;
    if (_loadingDetail && d == null) {
      return const DeskCard(child: SizedBox(height: 300, child: Center(child: CircularProgressIndicator(color: DeskColors.maroon))));
    }
    if (d == null) {
      return const DeskCard(
        child: SizedBox(height: 300, child: Center(child: Text('Select an instructor.', style: TextStyle(color: DeskColors.muted)))),
      );
    }
    final active = d.status == 'active';
    final sections = d.assignedSections;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DeskCard(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  _Initials(name: d.name, background: const Color(0xFF7A1424), foreground: Colors.white, radius: 26),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: !active
                            ? const Color(0xFF9E9E9E)
                            : sections.isEmpty
                                ? const Color(0xFFFF8A00)
                                : const Color(0xFF1E9E45),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(d.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    if (sections.isEmpty)
                      const DeskStatusChip(label: '● Unassigned', tone: DeskChipTone.yellow)
                    else
                      Text(
                        sections.map((s) => '${s.program} - ${s.section}').join(', '),
                        style: const TextStyle(fontSize: 11.5, color: DeskColors.muted),
                      ),
                  ],
                ),
              ),
              _PillButton(label: 'Edit Information', icon: Icons.edit_outlined, outlined: true, large: true, onTap: _editInfo),
              const SizedBox(width: 8),
              _PillButton(
                label: active ? 'Revoke Access' : 'Restore Access',
                icon: active ? Icons.block : Icons.lock_open,
                outlined: true,
                large: true,
                danger: active,
                onTap: _toggleAccess,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        DeskCard(
          title: 'Account Information',
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
          child: Column(
            children: [
              const Divider(height: 1, color: Color(0xFFEDEDED)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _Info(icon: Icons.person_outline, label: 'Full Name', value: d.name)),
                  Expanded(child: _Info(icon: Icons.phone_outlined, label: 'Contact Number', value: d.phone ?? '--')),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _Info(icon: Icons.mail_outline, label: 'Email Address', value: d.email)),
                  Expanded(
                    child: _Info(
                      icon: Icons.verified_user_outlined,
                      label: 'Account Status',
                      value: active ? 'Active' : 'Inactive',
                      valueColor: active ? const Color(0xFF1E9E45) : const Color(0xFFC62828),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(child: _sectionsCard(d)),
      ],
    );
  }

  Widget _sectionsCard(AdminInstructorDetail d) {
    final sections = d.assignedSections;
    final header = Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const Text('Assigned Sections', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: DeskColors.heading)),
        const SizedBox(width: 6),
        Text('A.Y. ${d.academicYear ?? _activeYear ?? ''}', style: const TextStyle(fontSize: 10.5, color: DeskColors.muted)),
      ],
    );
    if (sections.isEmpty) {
      return DeskCard(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        child: Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              header,
              const SizedBox(height: 14),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFDDDDDD)),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircleAvatar(
                          radius: 26,
                          backgroundColor: Color(0xFFF8E9EA),
                          child: Icon(Icons.groups_outlined, color: DeskColors.maroon, size: 26),
                        ),
                        const SizedBox(height: 12),
                        const Text('No section assigned yet', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text.rich(
                          TextSpan(
                            style: const TextStyle(fontSize: 11, color: DeskColors.muted),
                            children: [
                              TextSpan(text: '${d.name} is currently '),
                              const TextSpan(
                                text: 'Unassigned',
                                style: TextStyle(color: Color(0xFFE8843A), fontWeight: FontWeight.w600),
                              ),
                              const TextSpan(text: '. Assign one or more sections so this instructor can see and manage their students.'),
                            ],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 14),
                        _PillButton(label: 'Assign Section', icon: Icons.add, large: true, onTap: _assignSections),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    final current = sections.where((s) => s.id == _sectionId).firstOrNull ?? sections.first;
    final students = (_classDetail?.students ?? const <AdminClassStudent>[]).where((s) {
      final q = _studentQuery.trim().toLowerCase();
      return q.isEmpty ||
          s.name.toLowerCase().contains(q) ||
          (s.studentNumber ?? '').toLowerCase().contains(q) ||
          s.email.toLowerCase().contains(q);
    }).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    final pages = (students.length / _pageSize).ceil().clamp(1, 1 << 20);
    final page = _page.clamp(0, pages - 1);
    final shown = students.skip(page * _pageSize).take(_pageSize).toList();
    const head = TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF333333));
    const cell = TextStyle(fontSize: 11, color: Color(0xFF1F1F1F));
    return DeskCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      child: Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header,
            const SizedBox(height: 12),
            Row(
              children: [
                for (final s in sections) ...[
                  _SectionTab(
                    label: '${s.program} - ${s.section}',
                    selected: s.id == current.id,
                    onTap: () => _openSection(s.id),
                  ),
                  const SizedBox(width: 8),
                ],
                const Spacer(),
                _PillButton(label: 'Assign Section', icon: Icons.add, outlined: true, large: true, square: true, onTap: _assignSections),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text('${current.program} - ${current.section}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(width: 8),
                DeskCountBadge(count: current.studentCount),
                const SizedBox(width: 6),
                IconButton(
                  tooltip: 'Unassign this section',
                  onPressed: () => _unassignSection(current),
                  icon: const Icon(Icons.link_off, size: 18, color: DeskColors.muted),
                ),
                const Spacer(),
                SizedBox(
                  width: 190,
                  height: 34,
                  child: TextField(
                    onChanged: (v) => setState(() {
                      _studentQuery = v;
                      _page = 0;
                    }),
                    style: const TextStyle(fontSize: 11.5),
                    decoration: InputDecoration(
                      hintText: 'Search student...',
                      hintStyle: const TextStyle(fontSize: 11.5, color: DeskColors.muted),
                      prefixIcon: const Icon(Icons.search, size: 16),
                      contentPadding: EdgeInsets.zero,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: const BorderSide(color: Color(0xFFD6D6D6)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: const BorderSide(color: DeskColors.maroon),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  tooltip: 'Download this section\'s list',
                  position: PopupMenuPosition.under,
                  onSelected: _downloadList,
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'xlsx', child: Text('Excel (.xlsx)')),
                    PopupMenuItem(value: 'pdf', child: Text('PDF')),
                    PopupMenuItem(value: 'csv', child: Text('CSV')),
                  ],
                  child: Container(
                    height: 34,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(color: const Color(0xFF7A1424), borderRadius: BorderRadius.circular(6)),
                    child: const Row(
                      children: [
                        Icon(Icons.download, size: 16, color: Colors.white),
                        SizedBox(width: 6),
                        Text('Download List', style: TextStyle(fontSize: 11.5, color: Colors.white, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              color: const Color(0xFFF5E6E8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: const Row(
                children: [
                  Expanded(flex: 2, child: Text('Student No.', style: head)),
                  Expanded(flex: 3, child: Text('Student Name ↑', style: head)),
                  Expanded(flex: 4, child: Text('Email', style: head)),
                ],
              ),
            ),
            Expanded(
              child: _loadingClass
                  ? const Center(child: CircularProgressIndicator(color: DeskColors.maroon))
                  : shown.isEmpty
                      ? const Center(child: Text('No students in this section yet.', style: TextStyle(fontSize: 12, color: DeskColors.muted)))
                      : ListView.separated(
                          itemCount: shown.length,
                          separatorBuilder: (_, _) => const Divider(height: 1, color: Color(0xFFEDEDED)),
                          itemBuilder: (context, i) {
                            final s = shown[i];
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              child: Row(
                                children: [
                                  Expanded(flex: 2, child: Text(s.studentNumber ?? '--', style: cell)),
                                  Expanded(flex: 3, child: Text(s.name, style: cell.copyWith(fontWeight: FontWeight.w600))),
                                  Expanded(flex: 4, child: Text(s.email, style: cell)),
                                ],
                              ),
                            );
                          },
                        ),
            ),
            const SizedBox(height: 8),
            DeskPager(
              page: page,
              pageSize: _pageSize,
              total: students.length,
              noun: 'students',
              onChanged: (p) => setState(() => _page = p),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- widgets

class _Initials extends StatelessWidget {
  final String name;
  final Color background;
  final Color foreground;
  final double radius;

  const _Initials({required this.name, required this.background, required this.foreground, required this.radius});

  @override
  Widget build(BuildContext context) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    final text = parts.isEmpty ? '?' : (parts.first[0] + (parts.length > 1 ? parts.last[0] : '')).toUpperCase();
    return CircleAvatar(
      radius: radius,
      backgroundColor: background,
      child: Text(text, style: TextStyle(color: foreground, fontSize: radius * 0.62, fontWeight: FontWeight.w700)),
    );
  }
}

class _PillButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool outlined;
  final bool large;
  final bool danger;
  final bool square;
  final IconData? icon;

  const _PillButton({
    required this.label,
    required this.onTap,
    this.outlined = false,
    this.large = false,
    this.danger = false,
    this.square = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final color = danger ? const Color(0xFFC62828) : const Color(0xFF7A1424);
    final shape = square
        ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))
        : const StadiumBorder();
    final padding = EdgeInsets.symmetric(horizontal: large ? 14 : 9, vertical: large ? 10 : 4);
    final text = Text(label, style: TextStyle(fontSize: large ? 11.5 : 9.5, fontWeight: FontWeight.w600));
    final child = icon == null
        ? text
        : Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: large ? 15 : 12), const SizedBox(width: 5), text]);
    return outlined
        ? OutlinedButton(
            onPressed: onTap,
            style: OutlinedButton.styleFrom(
              foregroundColor: color,
              side: BorderSide(color: color),
              padding: padding,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: shape,
            ),
            child: child,
          )
        : ElevatedButton(
            onPressed: onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: padding,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: shape,
            ),
            child: child,
          );
  }
}

class _SectionTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SectionTab({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFF7A1424) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: BorderSide(color: selected ? const Color(0xFF7A1424) : const Color(0xFFD6D6D6)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            label,
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: selected ? Colors.white : const Color(0xFF333333)),
          ),
        ),
      ),
    );
  }
}

class _Info extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _Info({required this.icon, required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(color: const Color(0xFFF8E9EA), borderRadius: BorderRadius.circular(6)),
          child: Icon(icon, size: 15, color: DeskColors.maroon),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 9.5, color: DeskColors.muted)),
              Text(
                value,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: valueColor ?? const Color(0xFF1F1F1F)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EditInstructorDialog extends StatefulWidget {
  final AdminInstructorDetail detail;

  const _EditInstructorDialog({required this.detail});

  @override
  State<_EditInstructorDialog> createState() => _EditInstructorDialogState();
}

class _EditInstructorDialogState extends State<_EditInstructorDialog> {
  late final _name = TextEditingController(text: widget.detail.name);
  late final _email = TextEditingController(text: widget.detail.email);
  late final _phone = TextEditingController(text: widget.detail.phone ?? '');
  late final _department = TextEditingController(text: widget.detail.department ?? '');
  late final _position = TextEditingController(text: widget.detail.position ?? '');

  @override
  Widget build(BuildContext context) {
    Widget field(String label, TextEditingController c) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: TextField(controller: c, decoration: InputDecoration(labelText: label, border: const OutlineInputBorder())),
        );
    return AlertDialog(
      title: const Text('Edit Information'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            field('Full Name', _name),
            field('Email Address', _email),
            field('Contact Number', _phone),
            field('Department', _department),
            field('Position', _position),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: DeskColors.maroon),
          onPressed: () => Navigator.pop(context, {
            'name': _name.text.trim(),
            'email': _email.text.trim(),
            'phone': _phone.text.trim(),
            'department': _department.text.trim(),
            'position': _position.text.trim(),
          }),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

/// Pick unassigned sections of the active year, or create a new one.
class _SectionPickerDialog extends StatefulWidget {
  final String title;
  final String action;
  final AdminAccountsService accounts;
  final String? activeYear;

  const _SectionPickerDialog({required this.title, required this.action, required this.accounts, required this.activeYear});

  @override
  State<_SectionPickerDialog> createState() => _SectionPickerDialogState();
}

class _SectionPickerDialogState extends State<_SectionPickerDialog> {
  List<AdminSection> _free = [];
  final Set<int> _picked = {};
  bool _loading = true;
  final _program = TextEditingController(text: 'BSIT');
  final _section = TextEditingController();
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final all = await widget.accounts.getSections(academicYear: widget.activeYear);
      if (!mounted) return;
      setState(() {
        _free = all.where((s) => s.instructorId == null).toList();
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e is ApiException ? e.message : '$e';
        });
      }
    }
  }

  Future<void> _create() async {
    final program = _program.text.trim().toUpperCase();
    final section = _section.text.trim().toUpperCase();
    if (program.isEmpty || section.isEmpty || widget.activeYear == null) return;
    try {
      await widget.accounts.createSection(program: program, section: section, academicYear: widget.activeYear!);
      _section.clear();
      final all = await widget.accounts.getSections(academicYear: widget.activeYear);
      if (!mounted) return;
      setState(() {
        _free = all.where((s) => s.instructorId == null).toList();
        final made = _free.where((s) => s.program == program && s.section == section).firstOrNull;
        if (made != null) _picked.add(made.id);
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e is ApiException ? e.message : 'Could not create the section.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 420,
        child: _loading
            ? const SizedBox(height: 120, child: Center(child: CircularProgressIndicator()))
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sections without an instructor (A.Y. ${widget.activeYear ?? '-'})',
                    style: const TextStyle(fontSize: 12, color: DeskColors.muted),
                  ),
                  const SizedBox(height: 6),
                  if (_free.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('Every section has an instructor. Create a new one below.', style: TextStyle(fontSize: 12)),
                    ),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 220),
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          for (final s in _free)
                            CheckboxListTile(
                              dense: true,
                              value: _picked.contains(s.id),
                              activeColor: DeskColors.maroon,
                              onChanged: (v) => setState(() => v == true ? _picked.add(s.id) : _picked.remove(s.id)),
                              title: Text('${s.program} - ${s.section}'),
                              subtitle: Text('${s.studentCount} students'),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const Divider(),
                  const Text('Create a new section', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      SizedBox(
                        width: 90,
                        child: TextField(
                          controller: _program,
                          decoration: const InputDecoration(labelText: 'Program', isDense: true, border: OutlineInputBorder()),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _section,
                          decoration: const InputDecoration(labelText: 'Section (e.g. 4A)', isDense: true, border: OutlineInputBorder()),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(onPressed: _create, child: const Text('Add')),
                    ],
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(_error!, style: const TextStyle(color: Color(0xFFC62828), fontSize: 12)),
                  ],
                ],
              ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: DeskColors.maroon),
          onPressed: _picked.isEmpty ? null : () => Navigator.pop(context, _picked.toList()),
          child: Text(widget.action),
        ),
      ],
    );
  }
}

/// Invite Instructor (mockup): a fresh single-use registration code and a
/// link that opens the instructor sign-up with the code filled in.
class _InviteDialog extends StatefulWidget {
  final AdminAccountsService accounts;

  const _InviteDialog({required this.accounts});

  @override
  State<_InviteDialog> createState() => _InviteDialogState();
}

class _InviteDialogState extends State<_InviteDialog> {
  String? _code;
  bool _busy = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _generate();
  }

  Future<void> _generate() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final code = await widget.accounts.createCode();
      if (mounted) {
        setState(() {
          _code = code.code;
          _busy = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e is ApiException ? e.message : 'Could not create a code.';
        });
      }
    }
  }

  String get _link => '${Uri.base.origin}/?code=${_code ?? ''}';

  void _copy(String text, String message) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    const label = TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF333333));
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: SizedBox(
        width: 440,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(child: Text('Invite Instructor', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700))),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    style: IconButton.styleFrom(backgroundColor: const Color(0xFFF8E9EA)),
                    icon: const Icon(Icons.close, size: 16, color: DeskColors.maroon),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Text('Registration Code', style: label),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFCE7B8),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFF0C75E)),
                      ),
                      child: _busy
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : Text(
                              _code ?? '--',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFFD9822B), letterSpacing: 1),
                            ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _code == null ? null : () => _copy(_code!, 'Registration code copied.'),
                    icon: const Icon(Icons.copy, size: 15),
                    label: const Text('Copy Code'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: DeskColors.maroon,
                      side: const BorderSide(color: DeskColors.maroon),
                      minimumSize: const Size(0, 44),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Text('Invite Link', style: label),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFDDDDDD)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.link, size: 15, color: DeskColors.muted),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _code == null ? '--' : _link,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11, color: Color(0xFF555555)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _code == null ? null : () => _copy(_link, 'Invite link copied.'),
                    icon: const Icon(Icons.copy, size: 15),
                    label: const Text('Copy Link'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7A1424),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 40),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAFAFA),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE5E5E5)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Note:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                    SizedBox(height: 4),
                    Text('•  This code can only be used once.', style: TextStyle(fontSize: 11)),
                    Text(
                      '•  After the instructor signs up, approve them under Account Requests and assign their sections.',
                      style: TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: Color(0xFFC62828), fontSize: 12)),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _generate,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Generate New Code'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: DeskColors.maroon,
                      side: const BorderSide(color: DeskColors.maroon),
                      minimumSize: const Size(0, 40),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                  ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7A1424),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(80, 40),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    child: const Text('Close'),
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
