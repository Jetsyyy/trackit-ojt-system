import '../../../utils/pick_files.dart';
import 'package:flutter/material.dart';
import '../../../models/ojt_requirement_doc.dart';
import '../../../models/ojt_requirement_phase.dart';
import '../../../services/api_client.dart';
import '../../../services/ojt_requirements_service.dart';
import '../../../utils/app_colors.dart';
import '../../../utils/attachment_launcher.dart';
import '../../../utils/ph_time.dart';
import '../../../utils/requirement_file_types.dart';
import '../../../widgets/common/back_nav_header.dart';
import '../../../widgets/common/skeleton_list_tile.dart';
import '../../../widgets/student/documents/phase_card.dart';
import '../../../widgets/student/documents/requirement_doc_tile.dart';
import '../../../widgets/student/student_ui.dart';

/// One requirement phase (TrackIT student mockups "OJT Requirements 1-4"):
/// phase title card, "First Phase" heading and the document cards. The last
/// phase (Final Documents) lists the documents to prepare and has the
/// "I have all the Documents Ready" button.
class PhaseRequirementsScreen extends StatefulWidget {
  final String phaseId;
  final OjtRequirementsService service;
  final bool isFinalPhase;

  const PhaseRequirementsScreen({
    super.key,
    required this.phaseId,
    required this.service,
    this.isFinalPhase = false,
  });

  @override
  State<PhaseRequirementsScreen> createState() => _PhaseRequirementsScreenState();
}

class _PhaseRequirementsScreenState extends State<PhaseRequirementsScreen> {
  static const _ordinals = ['First', 'Second', 'Third', 'Fourth', 'Fifth', 'Sixth', 'Seventh', 'Eighth'];

  OjtRequirementPhase? _phase;
  bool _loading = true;
  String? _uploadingDocId;
  DateTime? _readyAt;
  bool _sendingReady = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final phases = await widget.service.getPhases();
    DateTime? readyAt;
    if (widget.isFinalPhase) {
      try {
        readyAt = await widget.service.getFinalDocumentsReadyAt();
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      _phase = phases.firstWhere((p) => p.id == widget.phaseId);
      _readyAt = readyAt;
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

  Future<void> _markReady() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('All documents ready?'),
        content: const Text(
          'Your instructor will be told that all your required documents are ready and '
          'submitted, for their review and confirmation.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Not yet')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: StudentColors.maroon),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Notify my instructor'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _sendingReady = true);
    try {
      final at = await widget.service.markFinalDocumentsReady();
      if (!mounted) return;
      setState(() => _readyAt = at ?? DateTime.now());
      _snack('Your instructor was notified.');
    } catch (e) {
      if (mounted) _snack(e is ApiException ? e.message : 'Could not notify your instructor.', error: true);
    } finally {
      if (mounted) setState(() => _sendingReady = false);
    }
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
                      Text(
                        '${phase.order >= 1 && phase.order <= _ordinals.length ? _ordinals[phase.order - 1] : 'Phase ${phase.order}'}'
                        '${phase.order >= 1 && phase.order <= _ordinals.length ? ' Phase' : ''}',
                        style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: StudentColors.heading),
                      ),
                      if (widget.isFinalPhase) ..._finalPhase(phase) else ...[
                        const Text(
                          'Listed below all notes / document submissions',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                        if (phase.description.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(phase.description, style: const TextStyle(fontSize: 11.5, color: StudentColors.muted)),
                        ],
                        const SizedBox(height: 12),
                        for (final document in phase.documents) _docTile(document),
                        if (phase.documents.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Text('No documents in this phase yet.', textAlign: TextAlign.center),
                          ),
                      ],
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  List<Widget> _finalPhase(OjtRequirementPhase phase) {
    const body = TextStyle(fontSize: 12, color: Color(0xFF1F1F1F), height: 1.35);
    return [
      const Text(
        'Please ensure that you have all the required documents listed below. Keep your original '
        'copies on hand, as they may be needed for verification or future reference.\n\n'
        'Prepare the required number of photocopies for each document, as specified in its '
        'respective instructions, since additional copies may be requested by your company or '
        'the SIPP Coordinator.',
        textAlign: TextAlign.justify,
        style: body,
      ),
      const SizedBox(height: 12),
      for (final d in phase.documents) ...[
        _FinalDocRow(
          document: d,
          onTap: () => showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            backgroundColor: StudentColors.page,
            builder: (sheetContext) => SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: StatefulBuilder(
                  builder: (context, _) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      RequirementDocTile(
                        document: d,
                        onUpload: () async {
                          Navigator.of(sheetContext).pop();
                          await _upload(d);
                        },
                        onView: () => _open(d.uploadedFileUrl, 'Could not open that file.'),
                        onDownloadTemplate: d.templateUrl != null
                            ? () => _open(d.templateUrl, 'Could not open the template.')
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
      const SizedBox(height: 10),
      const Text(
        '•  Prepare the required number of photocopies for each requirement.\n'
        '•  Check the individual instructions for the required number of copies.\n'
        '•  Ensure that all documents are complete and properly signed.\n'
        '•  Submit the required documents to your respective Adviser for collection and endorsement '
        'to the SIPP Coordinator.',
        style: body,
      ),
      const SizedBox(height: 14),
      Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFBDBDBD)),
          color: const Color(0xFFF1EEED),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 44,
              child: ElevatedButton(
                onPressed: _readyAt != null || _sendingReady ? null : _markReady,
                style: ElevatedButton.styleFrom(
                  backgroundColor: StudentColors.maroon,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: StudentColors.approved,
                  disabledForegroundColor: Colors.white,
                  shape: const RoundedRectangleBorder(),
                ),
                child: _sendingReady
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(
                        _readyAt == null
                            ? 'I have all the Documents Ready'
                            : 'Instructor notified · ${formatPh(_readyAt!, 'MMM d, yyyy')}',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                      ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(12, 8, 12, 10),
              child: Text(
                'By clicking this button, you are notifying your respective Instructor that all required '
                'documents are ready and have been submitted. Your submission will then be subject to your '
                'instructor\'s review and confirmation.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 9.5, color: Color(0xFF555555)),
              ),
            ),
          ],
        ),
      ),
    ];
  }
}

class _FinalDocRow extends StatelessWidget {
  final OjtRequirementDoc document;
  final VoidCallback onTap;

  const _FinalDocRow({required this.document, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final d = document;
    final (label, color) = switch (d.status) {
      RequirementDocStatus.approved => ('Approved', StudentColors.approved),
      RequirementDocStatus.submitted || RequirementDocStatus.pending => ('Pending', StudentColors.pending),
      RequirementDocStatus.rejected => ('Re-Upload', StudentColors.declined),
      RequirementDocStatus.missing => (null, null),
    };
    return Material(
      color: Colors.white,
      elevation: 1,
      shadowColor: Colors.black26,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFF555555)),
                ),
                child: const Icon(Icons.description, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(d.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                    if (d.description.isNotEmpty)
                      Text(d.description, style: const TextStyle(fontSize: 10.5, color: StudentColors.muted)),
                  ],
                ),
              ),
              if (label != null)
                Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
            ],
          ),
        ),
      ),
    );
  }
}
