import '../../../utils/pick_files.dart';
import 'package:flutter/material.dart';
import '../../../models/ojt_requirement_doc.dart';
import '../../../models/ojt_requirement_phase.dart';
import '../../../services/api_client.dart';
import '../../../services/ojt_requirements_service.dart';
import '../../../utils/app_colors.dart';
import '../../../utils/attachment_launcher.dart';
import '../../../utils/requirement_file_types.dart';
import '../../../widgets/common/back_nav_header.dart';
import '../../../widgets/common/skeleton_list_tile.dart';
import '../../../widgets/student/documents/phase_card.dart';
import '../../../widgets/student/documents/requirement_doc_tile.dart';
import '../../../widgets/student/student_ui.dart';

/// One requirement stage (System Revision 2, Figma "OJT Requirements"):
/// the stage card, "OJT Documents" and the document cards with Download
/// Template / Upload. Stage 4 (Final Details) is the information form, not
/// this screen.
class PhaseRequirementsScreen extends StatefulWidget {
  final String phaseId;
  final OjtRequirementsService service;

  const PhaseRequirementsScreen({
    super.key,
    required this.phaseId,
    required this.service,
  });

  @override
  State<PhaseRequirementsScreen> createState() => _PhaseRequirementsScreenState();
}

class _PhaseRequirementsScreenState extends State<PhaseRequirementsScreen> {
  OjtRequirementPhase? _phase;
  bool _loading = true;
  String? _uploadingDocId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final phases = await widget.service.getPhases();
    if (!mounted) return;
    setState(() {
      _phase = phases.firstWhere((p) => p.id == widget.phaseId);
      _loading = false;
    });
  }

  void _snack(String text, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), backgroundColor: error ? AppColors.statRedIcon : null),
    );
  }

  Future<void> _upload(OjtRequirementDoc document) async {
    final result = await pickFilesWithData(
      type: FileType.custom,
      allowedExtensions: requirementFileExtensions,
    );
    if (result == null || result.files.isEmpty || !mounted) return;
    final file = result.files.single;
    if (file.bytes == null) {
      _snack('Could not read that file.', error: true);
      return;
    }
    setState(() => _uploadingDocId = document.id);
    try {
      final phases = await widget.service.submitDocument(
        phaseId: widget.phaseId,
        documentId: document.id,
        fileBytes: file.bytes!,
        fileName: file.name,
        contentType: requirementFileContentType(file.extension),
      );
      if (!mounted) return;
      setState(() {
        _phase = phases.firstWhere((p) => p.id == widget.phaseId);
        _uploadingDocId = null;
      });
      _snack('${file.name} submitted for ${document.name}.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploadingDocId = null);
      _snack(e is ApiException ? e.message : 'Upload failed. Please try again.', error: true);
    }
  }

  Future<void> _open(String? url, String failMessage) async {
    if (url == null) return;
    final opened = await openAttachment(ApiClient.resolveUrl(url));
    if (!opened && mounted) _snack(failMessage, error: true);
  }

  Widget _docTile(OjtRequirementDoc document) {
    if (_uploadingDocId == document.id) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator(color: AppColors.primaryMaroon)),
      );
    }
    return RequirementDocTile(
      document: document,
      onUpload: () => _upload(document),
      onView: () => _open(document.uploadedFileUrl, 'Could not open that file.'),
      onDownloadTemplate: document.templateUrl != null
          ? () => _open(document.templateUrl, 'Could not open the template.')
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final phase = _phase;
    return Column(
      children: [
        const BackNavHeader(subtitle: 'OJT Requirements'),
        Expanded(
          child: _loading || phase == null
              ? const SkeletonList(count: 3)
              : RefreshIndicator(
                  color: AppColors.primaryMaroon,
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
                    children: [
                      StudentCard(
                        padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
                        child: Row(
                          children: [
                            PhaseNumber(number: phase.order),
                            const SizedBox(width: 12),
                            Expanded(child: Text(phase.title, style: studentSerif(size: 24, weight: FontWeight.w600))),
                            phaseStatusPill(phase),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'OJT Documents',
                        style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: StudentColors.heading),
                      ),
                      const Text(
                        'Requirements needed for OJT Deployment',
                        style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 12),
                      for (final document in phase.documents) _docTile(document),
                      if (phase.documents.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Text('No documents in this stage yet.', textAlign: TextAlign.center),
                        ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}
