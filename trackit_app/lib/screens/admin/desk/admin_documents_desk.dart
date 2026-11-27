import '../../../utils/pick_files.dart';
import 'package:flutter/material.dart';
import '../../../services/admin_requirements_service.dart';
import '../../../services/api_client.dart';
import '../../../utils/attachment_launcher.dart';
import '../../../utils/ph_time.dart';
import '../../../utils/requirement_file_types.dart';
import '../../../widgets/common/desk_ui.dart';

/// Admin Documents (TrackIT admin mockups): the Requirements List grouped
/// by stage on the left; the selected requirement's details and its
/// Template / Format on the right. Add Requirement, Edit Information and
/// Replace Template open dialogs. Only the Admin manages this list
/// (System Revisions item 15).
class AdminDocumentsDesk extends StatefulWidget {
  final ApiClient client;

  const AdminDocumentsDesk({super.key, required this.client});

  @override
  State<AdminDocumentsDesk> createState() => _AdminDocumentsDeskState();
}

class _AdminDocumentsDeskState extends State<AdminDocumentsDesk> {
  late final AdminRequirementsService _service = AdminRequirementsService(widget.client);
  List<AdminRequirementPhase> _phases = [];
  bool _loading = true;
  int? _selectedId;
  bool _busy = false;

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
      final phases = await _service.getPhases();
      if (!mounted) return;
      setState(() {
        _phases = phases;
        _loading = false;
        final all = [for (final p in phases) ...p.requirements];
        if (_selectedId == null || !all.any((r) => r.id == _selectedId)) {
          _selectedId = all.isEmpty ? null : all.first.id;
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _snack(_err(e, 'Could not load the documents.'), error: true);
      }
    }
  }

  AdminRequirement? get _selected {
    for (final p in _phases) {
      for (final r in p.requirements) {
        if (r.id == _selectedId) return r;
      }
    }
    return null;
  }

  AdminRequirementPhase? _phaseOf(AdminRequirement r) => _phases.where((p) => p.id == r.phaseId).firstOrNull;

  String _stageLabel(AdminRequirementPhase? p) => p == null ? '--' : 'Stage ${p.order} · ${p.title}';

  Future<void> _run(Future<void> Function() action, String done) async {
    setState(() => _busy = true);
    try {
      await action();
      await _load();
      if (mounted) _snack(done);
    } catch (e) {
      if (mounted) _snack(_err(e, 'Something went wrong.'), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _add() async {
    final result = await showDialog<_RequirementForm>(
      context: context,
      builder: (context) => _RequirementDialog(phases: _phases, initialPhaseId: _selected?.phaseId),
    );
    if (result == null) return;
    await _run(() async {
      final id = await _service.create(
        phaseId: result.phaseId,
        name: result.name,
        description: result.description,
        issuedBy: result.issuedBy,
        copiesRequired: result.copies,
      );
      if (id != null) {
        _selectedId = id;
        if (result.file != null) {
          await _service.uploadTemplate(
            id,
            bytes: result.file!.bytes!,
            fileName: result.file!.name,
            contentType: requirementFileContentType(result.file!.extension),
          );
        }
      }
    }, 'Requirement "${result.name}" added.');
  }

  Future<void> _edit(AdminRequirement r) async {
    final result = await showDialog<_RequirementForm>(
      context: context,
      builder: (context) => _RequirementDialog(phases: _phases, existing: r),
    );
    if (result == null) return;
    await _run(() async {
      await _service.update(
        r.id,
        name: result.name,
        description: result.description,
        issuedBy: result.issuedBy,
        copiesRequired: result.copies,
        phaseId: result.phaseId != r.phaseId ? result.phaseId : null,
      );
      if (result.file != null) {
        await _service.uploadTemplate(
          r.id,
          bytes: result.file!.bytes!,
          fileName: result.file!.name,
          contentType: requirementFileContentType(result.file!.extension),
        );
      }
    }, 'Changes saved.');
  }

  Future<void> _replace(AdminRequirement r) async {
    final file = await _pickTemplate();
    if (file == null || !mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => _ReplaceDialog(requirement: r, file: file),
    );
    if (ok != true) return;
    await _run(
      () => _service.uploadTemplate(
        r.id,
        bytes: file.bytes!,
        fileName: file.name,
        contentType: requirementFileContentType(file.extension),
      ),
      r.templateName == null ? 'Template uploaded.' : 'Template replaced.',
    );
  }

  Future<void> _removeTemplate(AdminRequirement r) async {
    final ok = await _confirm('Remove the template?', 'Students will no longer be able to download "${r.templateName}".', 'Remove');
    if (ok != true) return;
    await _run(() => _service.removeTemplate(r.id), 'Template removed.');
  }

  Future<void> _delete(AdminRequirement r) async {
    final ok = await _confirm(
      'Delete "${r.name}"?',
      'It will be removed from every student\'s requirements. A requirement that students already submitted can\'t be deleted.',
      'Delete',
    );
    if (ok != true) return;
    await _run(() => _service.delete(r.id), 'Requirement deleted.');
  }

  Future<bool?> _confirm(String title, String body, String action) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFC62828)),
            onPressed: () => Navigator.pop(context, true),
            child: Text(action),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height - 130;
    final total = _phases.fold<int>(0, (s, p) => s + p.requirements.length);
    return DeskPage(
      title: 'Documents',
      onRefresh: _load,
      children: [
        SizedBox(
          height: height < 620 ? 620 : height,
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: DeskColors.maroon))
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(width: 330, child: _list(total)),
                    const SizedBox(width: 16),
                    Expanded(child: _detail()),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _list(int total) {
    return DeskCard(
      title: 'Requirements List',
      trailing: Text('$total documents', style: const TextStyle(fontSize: 10.5, color: DeskColors.muted)),
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
      child: Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ListView(
                children: [
                  for (final p in _phases) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 4, bottom: 6),
                      child: Row(
                        children: [
                          Text(
                            'STAGE ${p.order} · ${p.title.toUpperCase()}',
                            style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: DeskColors.muted, letterSpacing: 0.4),
                          ),
                          const SizedBox(width: 6),
                          DeskCountBadge(count: p.requirements.length),
                        ],
                      ),
                    ),
                    if (p.requirements.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 8, left: 4),
                        child: Text('No documents in this stage yet.', style: TextStyle(fontSize: 11, color: DeskColors.muted)),
                      ),
                    for (final r in p.requirements) _listItem(r),
                    const SizedBox(height: 6),
                  ],
                ],
              ),
            ),
            const Divider(height: 18),
            SizedBox(
              height: 42,
              child: ElevatedButton.icon(
                onPressed: _busy ? null : _add,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Requirement'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7A1424),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _listItem(AdminRequirement r) {
    final selected = r.id == _selectedId;
    final office = r.issuedBy != null && r.issuedBy!.trim().isNotEmpty;
    final copies = '${r.copiesRequired} photocop${r.copiesRequired == 1 ? 'y' : 'ies'}';
    final fg = selected ? Colors.white : const Color(0xFF1F1F1F);
    final sub = selected ? Colors.white70 : DeskColors.muted;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: selected ? const Color(0xFF7A1424) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: selected ? const Color(0xFF7A1424) : const Color(0xFFDDDDDD)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => setState(() => _selectedId = r.id),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: selected ? Colors.white24 : const Color(0xFFF8E9EA),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(Icons.description_outlined, size: 16, color: selected ? Colors.white : DeskColors.maroon),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.name, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg)),
                      if (office)
                        Text('Managed by ${r.issuedBy}', overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 9.5, color: sub))
                      else
                        Text.rich(
                          TextSpan(
                            style: TextStyle(fontSize: 9.5, color: sub),
                            children: [
                              TextSpan(text: '$copies · '),
                              r.templateName != null
                                  ? const TextSpan(text: 'Template uploaded')
                                  : TextSpan(
                                      text: 'No template yet',
                                      style: TextStyle(
                                        color: selected ? const Color(0xFFFFD29A) : const Color(0xFFD9822B),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                if (office)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: selected ? Colors.white24 : const Color(0xFFEDEDED),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lock_outline, size: 10, color: selected ? Colors.white : const Color(0xFF6B6B6B)),
                        const SizedBox(width: 3),
                        Text('Locked', style: TextStyle(fontSize: 9, color: selected ? Colors.white : const Color(0xFF6B6B6B))),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _detail() {
    final r = _selected;
    if (r == null) {
      return const DeskCard(
        child: SizedBox(
          height: 300,
          child: Center(child: Text('Add a requirement to get started.', style: TextStyle(color: DeskColors.muted))),
        ),
      );
    }
    final phase = _phaseOf(r);
    final office = r.issuedBy != null && r.issuedBy!.trim().isNotEmpty;
    return ListView(
      children: [
        DeskCard(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(color: const Color(0xFF7A1424), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.description_outlined, color: Colors.white, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        DeskStatusChip(label: _stageLabel(phase), tone: DeskChipTone.red),
                      ],
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : () => _edit(r),
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Edit Information'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF7A1424),
                      side: const BorderSide(color: Color(0xFF7A1424)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      shape: const StadiumBorder(),
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'More',
                    onSelected: (v) async {
                      if (v == 'up' || v == 'down') {
                        await _run(() => _service.move(r.id, up: v == 'up'), 'Order updated.');
                      } else if (v == 'delete') {
                        await _delete(r);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'up', child: Text('Move up')),
                      const PopupMenuItem(value: 'down', child: Text('Move down')),
                      PopupMenuItem(
                        value: 'delete',
                        enabled: r.submissionCount == 0,
                        child: Text(r.submissionCount == 0 ? 'Delete' : 'Delete (already submitted by ${r.submissionCount})'),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(height: 1, color: Color(0xFFEDEDED)),
              const SizedBox(height: 12),
              _pair(
                _Info(icon: Icons.description_outlined, label: 'Document Name', value: r.name),
                _Info(icon: Icons.layers_outlined, label: 'Stage', value: _stageLabel(phase)),
              ),
              _pair(
                office
                    ? _Info(icon: Icons.local_hospital_outlined, label: 'Issued By', value: r.issuedBy!)
                    : _Info(
                        icon: Icons.copy_all_outlined,
                        label: 'Photocopies Required',
                        value: '${r.copiesRequired} cop${r.copiesRequired == 1 ? 'y' : 'ies'}',
                      ),
                const _Info(icon: Icons.groups_outlined, label: 'Visible To', value: 'Students and Instructors'),
              ),
              _pair(
                _Info(
                  icon: Icons.schedule,
                  label: 'Last Updated',
                  value: r.updatedAt == null ? 'Not changed yet' : formatPh(r.updatedAt!, 'MMM d, yyyy'),
                ),
                _Info(icon: Icons.person_outline, label: 'Updated By', value: r.updatedByName ?? '--'),
              ),
              const SizedBox(height: 6),
              const Text('Description / Instructions', style: TextStyle(fontSize: 10.5, color: DeskColors.muted)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF6F3F3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE7E1E1)),
                ),
                child: Text(
                  r.description.isEmpty ? 'No instructions yet. Use Edit Information to add them.' : r.description,
                  style: TextStyle(fontSize: 12.5, height: 1.45, color: r.description.isEmpty ? DeskColors.muted : const Color(0xFF333333)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        DeskCard(
          title: 'Template / Format',
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Transform.translate(
                offset: const Offset(0, -10),
                child: Text(
                  office
                      ? 'Issued by the ${r.issuedBy}: there is no TrackIT template to download or replace.'
                      : 'Only students can download this file from their side.',
                  style: const TextStyle(fontSize: 11, color: DeskColors.muted),
                ),
              ),
              // Office-issued documents (Medical Certificate from the Clinic,
              // Registration Form from the Library) never have a TrackIT
              // template: students submit the actual issued document.
              if (office)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFBF4F4),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFEBD3D6)),
                  ),
                  child: Row(
                    children: [
                      const DeskIconBox(icon: Icons.local_hospital_outlined, size: 36),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Students get the ${r.name} from the ${r.issuedBy} and upload the actual issued document. '
                          'To use a TrackIT template instead, edit this document and clear "Issued by".',
                          style: const TextStyle(fontSize: 12, height: 1.4, color: Color(0xFF333333)),
                        ),
                      ),
                    ],
                  ),
                ),
              if (!office && r.templateName != null) ...[
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE0E0E0)),
                  ),
                  child: Row(
                    children: [
                      const DeskIconBox(icon: Icons.description_outlined, size: 32),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(r.templateName!, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            Text(
                              [
                                r.templateName!.split('.').last.toUpperCase(),
                                if (r.templateSize != null) _size(r.templateSize!),
                                if (r.templateUploadedAt != null)
                                  'Uploaded ${formatPh(r.templateUploadedAt!, 'MMM d, yyyy')}${r.updatedByName != null ? ' by ${r.updatedByName}' : ''}',
                              ].join(' · '),
                              style: const TextStyle(fontSize: 10.5, color: DeskColors.muted),
                            ),
                          ],
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: r.templateUrl == null ? null : () => openAttachment(ApiClient.resolveUrl(r.templateUrl!)),
                        icon: const Icon(Icons.download, size: 15),
                        label: const Text('Download'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF7A1424),
                          side: const BorderSide(color: Color(0xFF7A1424)),
                          shape: const StadiumBorder(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: _busy ? null : () => _replace(r),
                        icon: const Icon(Icons.upload, size: 15),
                        label: const Text('Replace'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7A1424),
                          foregroundColor: Colors.white,
                          shape: const StadiumBorder(),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Remove template',
                        onPressed: _busy ? null : () => _removeTemplate(r),
                        icon: const Icon(Icons.delete_outline, size: 18, color: DeskColors.muted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (!office)
              InkWell(
                onTap: _busy ? null : () => _replace(r),
                borderRadius: BorderRadius.circular(10),
                child: CustomPaint(
                  painter: _DashedBox(),
                  child: Container(
                    height: 150,
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircleAvatar(
                          radius: 18,
                          backgroundColor: Color(0xFFF8E9EA),
                          child: Icon(Icons.upload, size: 18, color: DeskColors.maroon),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          r.templateName == null ? 'Click to choose a template file' : 'Click to choose a new file to replace it',
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        const Text('Accepted formats: PDF, DOC, DOCX, XLS, XLSX · Max 10 MB', style: TextStyle(fontSize: 10.5, color: DeskColors.muted)),
                      ],
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

  Widget _pair(Widget a, Widget b) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(children: [Expanded(child: a), const SizedBox(width: 16), Expanded(child: b)]),
      );
}

String _size(int bytes) {
  if (bytes >= 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  return '${(bytes / 1024).ceil()} KB';
}

Future<PickedFile?> _pickTemplate() async {
  final picked = await pickFilesWithData(
    type: FileType.custom,
    allowedExtensions: requirementFileExtensions,
  );
  final file = picked?.files.single;
  if (file == null || file.bytes == null) return null;
  return file;
}

class _Info extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _Info({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(color: const Color(0xFFF8E9EA), borderRadius: BorderRadius.circular(6)),
          child: Icon(icon, size: 16, color: DeskColors.maroon),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 10, color: DeskColors.muted)),
              Text(value, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ],
    );
  }
}

class _DashedBox extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFCFC4C4)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    final rrect = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(10));
    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      for (double d = 0; d < metric.length; d += 10) {
        canvas.drawPath(metric.extractPath(d, d + 6), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// What the Add / Edit dialog returns.
class _RequirementForm {
  final String name;
  final int phaseId;
  final int copies;
  final String description;
  final String? issuedBy;
  final PickedFile? file;

  const _RequirementForm({
    required this.name,
    required this.phaseId,
    required this.copies,
    required this.description,
    required this.issuedBy,
    required this.file,
  });
}

/// Add Requirement / Edit Information (mockups).
class _RequirementDialog extends StatefulWidget {
  final List<AdminRequirementPhase> phases;
  final AdminRequirement? existing;
  final int? initialPhaseId;

  const _RequirementDialog({required this.phases, this.existing, this.initialPhaseId});

  @override
  State<_RequirementDialog> createState() => _RequirementDialogState();
}

class _RequirementDialogState extends State<_RequirementDialog> {
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _description = TextEditingController(text: widget.existing?.description ?? '');
  late final _office = TextEditingController(text: widget.existing?.issuedBy ?? '');
  late int? _phaseId = widget.existing?.phaseId ?? widget.initialPhaseId ?? widget.phases.firstOrNull?.id;
  late int _copies = widget.existing?.copiesRequired ?? 1;
  PickedFile? _file;
  String? _error;

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
        width: 470,
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
                      editing ? 'Edit Information' : 'Add Requirement',
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
              const Text('Document Name', style: label),
              const SizedBox(height: 6),
              TextField(controller: _name, style: const TextStyle(fontSize: 13), decoration: deco('e.g. Barangay Clearance')),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('Stage', style: label),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<int>(
                          initialValue: _phaseId,
                          isExpanded: true,
                          style: const TextStyle(fontSize: 13, color: Color(0xFF1F1F1F)),
                          decoration: deco(''),
                          items: [
                            for (final p in widget.phases)
                              DropdownMenuItem(value: p.id, child: Text('Stage ${p.order} · ${p.title}', overflow: TextOverflow.ellipsis)),
                          ],
                          onChanged: (v) => setState(() => _phaseId = v),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 160,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('Photocopies Required', style: label),
                        const SizedBox(height: 6),
                        Container(
                          height: 44,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFDDDDDD)),
                          ),
                          child: Row(
                            children: [
                              _StepButton(icon: Icons.remove, onTap: _copies > 0 ? () => setState(() => _copies--) : null),
                              Expanded(child: Center(child: Text('$_copies', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)))),
                              _StepButton(icon: Icons.add, onTap: _copies < 20 ? () => setState(() => _copies++) : null),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text.rich(
                TextSpan(
                  text: 'Description / Instructions ',
                  style: label,
                  children: [TextSpan(text: '(optional)', style: TextStyle(fontWeight: FontWeight.w400, color: DeskColors.muted))],
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _description,
                minLines: 3,
                maxLines: 5,
                style: const TextStyle(fontSize: 13),
                decoration: deco('Tell students what to prepare and where to submit this document.'),
              ),
              const SizedBox(height: 12),
              const Text.rich(
                TextSpan(
                  text: 'Issued by an office ',
                  style: label,
                  children: [
                    TextSpan(
                      text: '(optional — e.g. School Clinic; students then get it there, with no template)',
                      style: TextStyle(fontWeight: FontWeight.w400, color: DeskColors.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              TextField(controller: _office, style: const TextStyle(fontSize: 13), decoration: deco('Leave empty if students download a template')),
              const SizedBox(height: 12),
              const Text.rich(
                TextSpan(
                  text: 'Template / Format ',
                  style: label,
                  children: [TextSpan(text: '(optional)', style: TextStyle(fontWeight: FontWeight.w400, color: DeskColors.muted))],
                ),
              ),
              const SizedBox(height: 6),
              if (_file != null || existingFile != null)
                Container(
                  padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFDDDDDD)),
                  ),
                  child: Row(
                    children: [
                      const DeskIconBox(icon: Icons.description_outlined, size: 28),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_file?.name ?? existingFile!, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                            Text(
                              _file != null
                                  ? '${_file!.extension?.toUpperCase() ?? ''} · ${_size(_file!.size)} · ready to upload'
                                  : 'Current template',
                              style: const TextStyle(fontSize: 10.5, color: DeskColors.muted),
                            ),
                          ],
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () async {
                          final f = await _pickTemplate();
                          if (f != null) setState(() => _file = f);
                        },
                        icon: const Icon(Icons.upload, size: 15),
                        label: const Text('Replace', style: TextStyle(fontSize: 12)),
                        style: TextButton.styleFrom(foregroundColor: DeskColors.maroon),
                      ),
                    ],
                  ),
                )
              else
                InkWell(
                  onTap: () async {
                    final f = await _pickTemplate();
                    if (f != null) setState(() => _file = f);
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: CustomPaint(
                    painter: _DashedBox(),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 14, horizontal: 14),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircleAvatar(
                            radius: 15,
                            backgroundColor: Color(0xFFF8E9EA),
                            child: Icon(Icons.upload, size: 15, color: DeskColors.maroon),
                          ),
                          SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Click to choose a file', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                              Text('PDF, DOC, DOCX, XLS, XLSX · Max 10 MB', style: TextStyle(fontSize: 10.5, color: DeskColors.muted)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: const TextStyle(color: Color(0xFFC62828), fontSize: 12)),
              ],
              const SizedBox(height: 18),
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
                    onPressed: () {
                      final name = _name.text.trim();
                      if (name.isEmpty || _phaseId == null) {
                        setState(() => _error = 'Enter the document name and choose a stage.');
                        return;
                      }
                      Navigator.pop(
                        context,
                        _RequirementForm(
                          name: name,
                          phaseId: _phaseId!,
                          copies: _copies,
                          description: _description.text.trim(),
                          issuedBy: _office.text.trim().isEmpty ? null : _office.text.trim(),
                          file: _file,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7A1424),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(140, 42),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text(editing ? 'Save Changes' : 'Add Requirement'),
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

class _StepButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _StepButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 40,
        height: double.infinity,
        color: const Color(0xFFF8E9EA),
        child: Icon(icon, size: 16, color: onTap == null ? DeskColors.muted : DeskColors.maroon),
      ),
    );
  }
}

/// Replace Template (mockup): confirms the newly chosen file.
class _ReplaceDialog extends StatelessWidget {
  final AdminRequirement requirement;
  final PickedFile file;

  const _ReplaceDialog({required this.requirement, required this.file});

  @override
  Widget build(BuildContext context) {
    final old = requirement.templateName;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: SizedBox(
        width: 420,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(old == null ? 'Upload Template' : 'Replace Template', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
                        Text(requirement.name, style: const TextStyle(fontSize: 12, color: DeskColors.muted)),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: IconButton.styleFrom(backgroundColor: const Color(0xFFF8E9EA)),
                    icon: const Icon(Icons.close, size: 16, color: DeskColors.maroon),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Text('New File', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.fromLTRB(10, 10, 6, 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFDDDDDD)),
                ),
                child: Row(
                  children: [
                    const DeskIconBox(icon: Icons.description_outlined, size: 30),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(file.name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                          Text('${file.extension?.toUpperCase() ?? ''} · ${_size(file.size)}', style: const TextStyle(fontSize: 10.5, color: DeskColors.muted)),
                        ],
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => Navigator.pop(context, false),
                      icon: const Icon(Icons.close, size: 14),
                      label: const Text('Remove', style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(foregroundColor: DeskColors.maroon),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Row(
                children: [
                  Icon(Icons.check_circle_outline, size: 15, color: Color(0xFF1E9E45)),
                  SizedBox(width: 5),
                  Text('Ready to upload', style: TextStyle(fontSize: 11.5, color: Color(0xFF1E9E45), fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF6F3F3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE7E1E1)),
                ),
                child: Text.rich(
                  TextSpan(
                    style: const TextStyle(fontSize: 12, color: Color(0xFF333333)),
                    children: old == null
                        ? const [TextSpan(text: 'Students will be able to download this file from now on.')]
                        : [
                            const TextSpan(text: 'This replaces '),
                            TextSpan(text: old, style: const TextStyle(fontWeight: FontWeight.w700)),
                            const TextSpan(text: '. Students will download the new file from now on.'),
                          ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: DeskColors.maroon,
                      side: const BorderSide(color: DeskColors.maroon),
                      minimumSize: const Size(100, 42),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context, true),
                    icon: const Icon(Icons.upload, size: 16),
                    label: const Text('Upload Template'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7A1424),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(140, 42),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
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
