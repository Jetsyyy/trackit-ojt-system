import 'package:flutter/material.dart';
import '../../models/instructor_class.dart';
import '../../models/ojt_progress.dart';
import '../../models/ojt_stage.dart';
import '../../models/student_registration_request.dart';
import '../../models/teacher_student_summary.dart';
import '../../services/api_client.dart';
import '../../services/teacher_classes_service.dart';
import '../../services/teacher_students_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/file_download.dart';
import '../../widgets/common/desk_ui.dart';
import 'desk/teacher_students_desk.dart';
import 'teacher_registration_requests_screen.dart';

class TeacherStudentsScreen extends StatefulWidget {
  final TeacherClassesService classesService;
  final TeacherStudentsService studentsService;
  final ValueChanged<int> onOpenStudent;

  /// Opens Registration Requests; the list reloads when it returns, since
  /// approved students join the roster.
  final Future<void> Function() onOpenRequests;

  /// Re-fetches when this fires (tab reopened, requests decided elsewhere).
  final Listenable? reloadSignal;

  const TeacherStudentsScreen({
    super.key,
    required this.classesService,
    required this.studentsService,
    required this.onOpenStudent,
    required this.onOpenRequests,
    this.reloadSignal,
  });

  @override
  State<TeacherStudentsScreen> createState() => _TeacherStudentsScreenState();
}

class _TeacherStudentsScreenState extends State<TeacherStudentsScreen> {
  List<InstructorClass> _classes = [];
  List<TeacherStudentSummary> _students = [];
  bool _loading = true;
  String? _companyFilter; // null = All, 'none' = No Company, else a name
  OjtStage? _stageFilter;
  OjtProgressStatus? _progressFilter;
  String _sortBy = 'name'; // 'name' | 'progress'
  bool _sortDescending = false;

  @override
  void initState() {
    super.initState();
    widget.reloadSignal?.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    widget.reloadSignal?.removeListener(_load);
    super.dispose();
  }

  List<StudentRegistrationRequest> _requests = [];

  Future<void> _load() async {
    final results = await Future.wait([
      widget.classesService.getClasses(),
      widget.studentsService.getStudents(),
      widget.studentsService.getRegistrationRequests(),
    ]);
    if (!mounted) return;
    setState(() {
      _classes = results[0] as List<InstructorClass>;
      _students = results[1] as List<TeacherStudentSummary>;
      _requests = results[2] as List<StudentRegistrationRequest>;
      _loading = false;
    });
  }

  // Desktop inline Approve / Remove. Removing asks for a reason, since the
  // student is told why they were declined.
  Future<void> _decide(StudentRegistrationRequest request, bool approve) async {
    String? reason;
    if (!approve) {
      reason = await showDialog<String>(
        context: context,
        builder: (context) => DeclineRegistrationDialog(name: request.name),
      );
      if (reason == null) return;
    }
    try {
      await widget.studentsService.decideRegistration(
        studentId: request.id,
        approve: approve,
        reason: reason,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(approve
              ? '${request.name} was approved and added to your section.'
              : '${request.name}\'s registration was declined.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e is ApiException ? e.message : 'Could not save your decision.'),
          backgroundColor: AppColors.statRedIcon,
        ),
      );
    }
    await _load();
  }

  bool get _filtersActive =>
      _companyFilter != null || _stageFilter != null || _progressFilter != null;

  bool _matchesFilters(TeacherStudentSummary s) {
    final matchesCompany = _companyFilter == null
        ? true
        : _companyFilter == 'none'
            ? s.companyName == null
            : s.companyName == _companyFilter;
    final matchesStage = _stageFilter == null || s.stage == _stageFilter;
    final matchesProgress = _progressFilter == null || s.progressStatus == _progressFilter;
    return matchesCompany && matchesStage && matchesProgress;
  }

  bool _exporting = false;

  // System Revisions item 14: records of every assigned student.
  Future<void> _downloadRecords(String format) async {
    setState(() => _exporting = true);
    try {
      final file = await widget.studentsService.exportRecords(format: format);
      final saved = downloadBytes(
        filename: file.filename ?? 'OJT-Student-Records.$format',
        bytes: file.bytes,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(saved
              ? 'Student records downloaded.'
              : 'Downloads are available in the web app.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e is ApiException ? e.message : 'Could not download the records.'),
          backgroundColor: AppColors.statRedIcon,
        ),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }


  Future<void> _refresh() => _load();


  List<String> get _companyOptions {
    final names = _students
        .map((s) => s.companyName)
        .whereType<String>()
        .toSet()
        .toList();
    names.sort();
    return names;
  }

  /// Students in the order picked in the filter sheet.
  List<TeacherStudentSummary> get _sorted {
    final list = [..._students];
    list.sort((a, b) {
      final result = _sortBy == 'progress'
          ? a.progressRatio.compareTo(b.progressRatio)
          : a.name.compareTo(b.name);
      return _sortDescending ? -result : result;
    });
    return list;
  }

  void _openFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Filter & Sort',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String?>(
                    initialValue: _companyFilter,
                    decoration: const InputDecoration(labelText: 'Assigned Company'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('All')),
                      const DropdownMenuItem(
                        value: 'none',
                        child: Text('No Company Yet'),
                      ),
                      for (final name in _companyOptions)
                        DropdownMenuItem(value: name, child: Text(name)),
                    ],
                    onChanged: (value) {
                      setSheetState(() => _companyFilter = value);
                      setState(() => _companyFilter = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<OjtStage?>(
                    initialValue: _stageFilter,
                    decoration: const InputDecoration(labelText: 'OJT Stage'),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('All')),
                      DropdownMenuItem(
                        value: OjtStage.notStarted,
                        child: Text('Not Started'),
                      ),
                      DropdownMenuItem(
                        value: OjtStage.readyForDeployment,
                        child: Text('Preparing'),
                      ),
                      DropdownMenuItem(value: OjtStage.active, child: Text('Active')),
                      DropdownMenuItem(
                        value: OjtStage.completed,
                        child: Text('Completed'),
                      ),
                    ],
                    onChanged: (value) {
                      setSheetState(() => _stageFilter = value);
                      setState(() => _stageFilter = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<OjtProgressStatus?>(
                    initialValue: _progressFilter,
                    decoration: const InputDecoration(labelText: 'OJT Progress'),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('All')),
                      DropdownMenuItem(
                        value: OjtProgressStatus.onTrack,
                        child: Text('On Track'),
                      ),
                      DropdownMenuItem(
                        value: OjtProgressStatus.behind,
                        child: Text('Behind'),
                      ),
                      DropdownMenuItem(
                        value: OjtProgressStatus.needsAttention,
                        child: Text('Needs Attention'),
                      ),
                      DropdownMenuItem(
                        value: OjtProgressStatus.aheadOfSchedule,
                        child: Text('Ahead of Schedule'),
                      ),
                      DropdownMenuItem(
                        value: OjtProgressStatus.completed,
                        child: Text('Completed'),
                      ),
                    ],
                    onChanged: (value) {
                      setSheetState(() => _progressFilter = value);
                      setState(() => _progressFilter = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _sortBy,
                    decoration: const InputDecoration(labelText: 'Sort By'),
                    items: const [
                      DropdownMenuItem(value: 'name', child: Text('Name')),
                      DropdownMenuItem(value: 'progress', child: Text('OJT Progress')),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setSheetState(() => _sortBy = value);
                      setState(() => _sortBy = value);
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    activeThumbColor: AppColors.primaryMaroon,
                    title: const Text('Descending'),
                    value: _sortDescending,
                    onChanged: (value) {
                      setSheetState(() => _sortDescending = value);
                      setState(() => _sortDescending = value);
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const ColoredBox(
        color: DeskColors.page,
        child: Center(child: CircularProgressIndicator(color: DeskColors.maroon)),
      );
    }
    return TeacherStudentsDesk(
      classes: _classes,
      students: _sorted,
      requests: _requests,
      exporting: _exporting,
      onOpenStudent: widget.onOpenStudent,
      onDecide: _decide,
      onGenerate: _downloadRecords,
      onOpenFilter: _openFilterSheet,
      filtersActive: _filtersActive,
      matchesFilters: _matchesFilters,
      onRefresh: _refresh,
      compact: !isDeskLayout(context),
    );
  }
}