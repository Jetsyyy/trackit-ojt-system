import '../../../utils/pick_files.dart';
import 'package:flutter/material.dart';
import '../../../models/custom_requirement.dart';
import '../../../services/api_client.dart';
import '../../../services/custom_requirements_service.dart';
import '../../../utils/app_colors.dart';
import '../../../utils/attachment_launcher.dart';
import '../../../utils/ph_time.dart';
import '../../../utils/requirement_file_types.dart';
import '../../../widgets/common/back_nav_header.dart';
import '../../../widgets/common/empty_state_view.dart';
import '../../../widgets/common/skeleton_list_tile.dart';
import '../../../widgets/student/documents/requirement_doc_tile.dart';

/// Instructor-created requirements, targeted at the student's class.
/// Unlike Official Requirements, these aren't stage-locked -- each one
/// can be submitted independently as soon as it's posted.
class AdditionalRequirementsScreen extends StatefulWidget {
  final CustomRequirementsService service;

  const AdditionalRequirementsScreen({super.key, required this.service});

  @override
  State<AdditionalRequirementsScreen> createState() =>
      _AdditionalRequirementsScreenState();
}

class _AdditionalRequirementsScreenState
    extends State<AdditionalRequirementsScreen> {
  List<CustomRequirement> _requirements = [];
  bool _loading = true;
  String? _uploadingId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final requirements = await widget.service.getRequirements();
    if (!mounted) return;
    setState(() {
      _requirements = requirements;
      _loading = false;
    });
  }

  Future<void> _upload(CustomRequirement requirement) async {
    final result = await pickFilesWithData(
      type: FileType.custom,
      allowedExtensions: requirementFileExtensions,
    );
    if (result == null || result.files.isEmpty || !mounted) return;
    final file = result.files.single;
    if (file.bytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not read that file.'),
          backgroundColor: AppColors.statRedIcon,
        ),
      );
      return;
    }

    setState(() => _uploadingId = requirement.id);
    try {
      final requirements = await widget.service.submitRequirement(
        requirementId: requirement.id,
        fileBytes: file.bytes!,
        fileName: file.name,
        contentType: requirementFileContentType(file.extension),
      );
      if (!mounted) return;
      setState(() {
        _requirements = requirements;
        _uploadingId = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${file.name} submitted for ${requirement.name}.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploadingId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: $e'), backgroundColor: AppColors.statRedIcon),
      );
    }
  }

  Future<void> _viewFile(CustomRequirement requirement) async {
    final url = requirement.uploadedFileUrl;
    if (url == null) return;
    final opened = await openAttachment(ApiClient.resolveUrl(url));
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open that file.'),
          backgroundColor: AppColors.statRedIcon,
        ),
      );
    }
  }

  Future<void> _downloadTemplate(CustomRequirement requirement) async {
    final url = requirement.templateUrl;
    if (url == null) return;
    final opened = await openAttachment(ApiClient.resolveUrl(url));
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open the template.'),
          backgroundColor: AppColors.statRedIcon,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      bottom: false,
      child: Column(
        children: [
          const BackNavHeader(subtitle: 'Scheduled Requirements'),
          Expanded(
            child: _loading
                ? const SkeletonList(count: 3)
                : _requirements.isEmpty
                ? const EmptyStateView(
                    icon: Icons.playlist_add_check_outlined,
                    title: 'Nothing Scheduled Yet',
                    message:
                        'Requirements with deadlines from the OJT office or your instructor, '
                        'like evaluation forms, will appear here.',
                  )
                : RefreshIndicator(
                    color: AppColors.primaryMaroon,
                    onRefresh: _load,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                      children: [
                        for (final requirement in _requirements)
                          _uploadingId == requirement.id
                              ? const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 24),
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      color: AppColors.primaryMaroon,
                                    ),
                                  ),
                                )
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    _DueBanner(requirement: requirement),
                                    RequirementDocTile(
                                  document: requirement.toDoc(),
                                  onUpload: () => _upload(requirement),
                                  onView: () => _viewFile(requirement),
                                  onDownloadTemplate: requirement.templateUrl != null
                                      ? () => _downloadTemplate(requirement)
                                      : null,
                                    ),
                                  ],
                                ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Period, who posted it and when it's due, above the document card:
/// red once overdue (or submitted late), orange within a day.
class _DueBanner extends StatelessWidget {
  final CustomRequirement requirement;
  const _DueBanner({required this.requirement});

  @override
  Widget build(BuildContext context) {
    final r = requirement;
    final due = r.dueAt ?? r.deadline;
    final now = DateTime.now();
    final overdue = due != null && !r.isDone && now.isAfter(r.dueAt ?? due.add(const Duration(days: 1)));
    final soon = due != null && !r.isDone && !overdue && (r.dueAt ?? due).difference(now).inHours < 24;
    final color = r.isLate || overdue
        ? AppColors.statRedIcon
        : soon
            ? const Color(0xFFB85A1A)
            : const Color(0xFF555555);
    final dueText = due == null
        ? 'No deadline'
        : r.dueAt != null
            ? 'Due ${formatPh(r.dueAt!, 'MMM d, yyyy · h:mm a')}'
            : 'Due ${formatPh(due, 'MMM d, yyyy')}';
    final state = r.isLate
        ? 'Submitted late'
        : overdue
            ? 'Overdue'
            : soon
                ? 'Due soon'
                : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF7A1424),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              r.fromOffice ? (r.period?.isNotEmpty == true ? r.period! : 'OJT Office') : 'Instructor',
              style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.schedule, size: 14, color: color),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              state == null ? dueText : '$dueText · $state',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: color),
            ),
          ),
        ],
      ),
    );
  }
}
