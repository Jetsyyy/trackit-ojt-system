import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../services/admin_requirements_service.dart';
import '../../services/api_client.dart';
import '../../utils/app_colors.dart';
import '../../utils/attachment_launcher.dart';
import '../../utils/requirement_file_types.dart';

/// Official Requirements, managed by the Admin only (System Revisions
/// item 15): the list and order students see in each phase (so the
/// corrected list from item 7 can be entered here), each requirement's
/// downloadable template, and which office issues it (item 6: an issued
/// requirement has no download on the Student side).
class AdminRequirementsScreen extends StatefulWidget {
  final ApiClient client;

  const AdminRequirementsScreen({super.key, required this.client});

  @override
  State<AdminRequirementsScreen> createState() => _AdminRequirementsScreenState();
}

class _AdminRequirementsScreenState extends State<AdminRequirementsScreen> {
  late final AdminRequirementsService _service = AdminRequirementsService(widget.client);
  List<AdminRequirementPhase> _phases = [];
  bool _loading = true;
  Object? _error;
  int? _busyId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final phases = await _service.getPhases();
      if (!mounted) return;
      setState(() {
        _phases = phases;
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

  Future<void> _run(int? busyId, Future<void> Function() action, String success) async {
    setState(() => _busyId = busyId);
    try {
      await action();
      if (mounted) _snack(success);
    } catch (e) {
      if (mounted) {
        _snack(e is ApiException ? e.message : 'Something went wrong. Please try again.', error: true);
      }
    }
    await _load();
    if (mounted) setState(() => _busyId = null);
  }

  Future<void> _edit({AdminRequirementPhase? phase, AdminRequirement? requirement}) async {
    final result = await showDialog<_RequirementForm>(
      context: context,
      builder: (context) => _RequirementDialog(requirement: requirement, phaseTitle: phase?.title),
    );
    if (result == null) return;
    if (requirement == null) {
      // Adding always comes from a phase header, so the phase is set.
      final target = phase!;
      await _run(
        null,
        () => _service.create(
          phaseId: target.id,
          name: result.name,
          description: result.description,
          issuedBy: result.issuedBy,
        ),
        '"${result.name}" added to ${target.title}.',
      );
    } else {
      await _run(
        requirement.id,
        () => _service.update(
          requirement.id,
          name: result.name,
          description: result.description,
          issuedBy: result.issuedBy,
        ),
        'Requirement updated.',
      );
    }
  }

  Future<void> _delete(AdminRequirement requirement) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete "${requirement.name}"?'),
        content: const Text('Students will no longer see or submit this requirement.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.statRedIcon),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _run(requirement.id, () => _service.delete(requirement.id), 'Requirement deleted.');
    }
  }

  Future<void> _uploadTemplate(AdminRequirement requirement) async {
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: requirementFileExtensions,
      withData: true,
    );
    if (picked == null || picked.files.isEmpty || !mounted) return;
    final file = picked.files.single;
    if (file.bytes == null) {
      _snack('Could not read that file.', error: true);
      return;
    }
    await _run(
      requirement.id,
      () => _service.uploadTemplate(
        requirement.id,
        bytes: file.bytes!,
        fileName: file.name,
        contentType: requirementFileContentType(file.extension),
      ),
      'Template uploaded for "${requirement.name}".',
    );
  }

  Future<void> _removeTemplate(AdminRequirement requirement) async {
    await _run(
      requirement.id,
      () => _service.removeTemplate(requirement.id),
      'Template removed from "${requirement.name}".',
    );
  }

  Future<void> _openTemplate(AdminRequirement requirement) async {
    final url = requirement.templateUrl;
    if (url == null) return;
    final opened = await openAttachment(ApiClient.resolveUrl(url));
    if (!opened && mounted) _snack('Could not open the template.', error: true);
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Official Requirements',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 4),
        const Text(
          'The documents students submit, in the order they see them. Upload templates here; '
          'documents issued by an office (e.g. Clinic, Registrar) have no download for students.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              children: [
                for (final phase in _phases) ...[
                  _PhaseHeader(phase: phase, onAdd: () => _edit(phase: phase)),
                  const SizedBox(height: 8),
                  if (phase.requirements.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Text('No requirements in this phase.',
                          style: TextStyle(color: AppColors.textSecondary)),
                    ),
                  for (var i = 0; i < phase.requirements.length; i++)
                    _RequirementRow(
                      requirement: phase.requirements[i],
                      position: i + 1,
                      busy: _busyId == phase.requirements[i].id,
                      canMoveUp: i > 0,
                      canMoveDown: i < phase.requirements.length - 1,
                      onMoveUp: () => _run(phase.requirements[i].id,
                          () => _service.move(phase.requirements[i].id, up: true), 'Order updated.'),
                      onMoveDown: () => _run(phase.requirements[i].id,
                          () => _service.move(phase.requirements[i].id, up: false), 'Order updated.'),
                      onEdit: () => _edit(phase: phase, requirement: phase.requirements[i]),
                      onDelete: () => _delete(phase.requirements[i]),
                      onUpload: () => _uploadTemplate(phase.requirements[i]),
                      onRemoveTemplate: () => _removeTemplate(phase.requirements[i]),
                      onOpenTemplate: () => _openTemplate(phase.requirements[i]),
                    ),
                  const SizedBox(height: 20),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PhaseHeader extends StatelessWidget {
  final AdminRequirementPhase phase;
  final VoidCallback onAdd;

  const _PhaseHeader({required this.phase, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Phase ${phase.order}: ${phase.title}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.primaryMaroon),
          ),
        ),
        TextButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Add Requirement'),
          style: TextButton.styleFrom(foregroundColor: AppColors.primaryMaroon),
        ),
      ],
    );
  }
}

class _RequirementRow extends StatelessWidget {
  final AdminRequirement requirement;
  final int position;
  final bool busy;
  final bool canMoveUp;
  final bool canMoveDown;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onUpload;
  final VoidCallback onRemoveTemplate;
  final VoidCallback onOpenTemplate;

  const _RequirementRow({
    required this.requirement,
    required this.position,
    required this.busy,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onEdit,
    required this.onDelete,
    required this.onUpload,
    required this.onRemoveTemplate,
    required this.onOpenTemplate,
  });

  @override
  Widget build(BuildContext context) {
    final r = requirement;
    final issued = r.issuedBy != null;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.chipGrayBg),
      ),
      child: Row(
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Move up',
                visualDensity: VisualDensity.compact,
                onPressed: canMoveUp && !busy ? onMoveUp : null,
                icon: const Icon(Icons.keyboard_arrow_up, size: 20),
              ),
              Text('$position', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              IconButton(
                tooltip: 'Move down',
                visualDensity: VisualDensity.compact,
                onPressed: canMoveDown && !busy ? onMoveDown : null,
                icon: const Icon(Icons.keyboard_arrow_down, size: 20),
              ),
            ],
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                if (r.description.isNotEmpty)
                  Text(r.description, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (issued)
                      _Tag(
                        icon: Icons.apartment_outlined,
                        text: 'Issued by ${r.issuedBy} · no student download',
                        color: AppColors.statBlueIcon,
                        background: AppColors.statBlueBg,
                      )
                    else if (r.templateUrl != null)
                      ActionChip(
                        avatar: const Icon(Icons.description_outlined, size: 16, color: AppColors.primaryMaroon),
                        label: Text(r.templateName ?? 'Template', style: const TextStyle(fontSize: 12)),
                        tooltip: 'Open template',
                        onPressed: onOpenTemplate,
                      )
                    else
                      const _Tag(
                        icon: Icons.description_outlined,
                        text: 'No template',
                        color: AppColors.textSecondary,
                        background: AppColors.chipGrayBg,
                      ),
                    if (r.submissionCount > 0)
                      Text('${r.submissionCount} submission${r.submissionCount == 1 ? '' : 's'}',
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  ],
                ),
              ],
            ),
          ),
          if (busy)
            const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            PopupMenuButton<String>(
              tooltip: 'Actions',
              onSelected: (value) {
                switch (value) {
                  case 'edit':
                    onEdit();
                  case 'upload':
                    onUpload();
                  case 'remove':
                    onRemoveTemplate();
                  case 'delete':
                    onDelete();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit name / office')),
                if (!issued)
                  PopupMenuItem(
                    value: 'upload',
                    child: Text(r.templateUrl == null ? 'Upload template' : 'Replace template'),
                  ),
                if (r.templateUrl != null) const PopupMenuItem(value: 'remove', child: Text('Remove template')),
                PopupMenuItem(
                  value: 'delete',
                  enabled: r.submissionCount == 0,
                  child: Text(
                    r.submissionCount == 0 ? 'Delete' : 'Delete (has submissions)',
                    style: TextStyle(color: r.submissionCount == 0 ? AppColors.statRedIcon : null),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  final Color background;

  const _Tag({required this.icon, required this.text, required this.color, required this.background});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}

class _RequirementForm {
  final String name;
  final String description;
  final String? issuedBy;

  const _RequirementForm(this.name, this.description, this.issuedBy);
}

class _RequirementDialog extends StatefulWidget {
  final AdminRequirement? requirement;
  final String? phaseTitle;

  const _RequirementDialog({this.requirement, this.phaseTitle});

  @override
  State<_RequirementDialog> createState() => _RequirementDialogState();
}

class _RequirementDialogState extends State<_RequirementDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name = TextEditingController(text: widget.requirement?.name ?? '');
  late final TextEditingController _description =
      TextEditingController(text: widget.requirement?.description ?? '');
  late final TextEditingController _office = TextEditingController(text: widget.requirement?.issuedBy ?? '');
  late bool _issued = widget.requirement?.issuedBy != null;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _office.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.requirement != null;
    return AlertDialog(
      title: Text(editing ? 'Edit Requirement' : 'Add Requirement to ${widget.phaseTitle}'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _name,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Requirement name'),
                validator: (v) => (v ?? '').trim().isEmpty ? 'Name is required' : null,
              ),
              TextFormField(
                controller: _description,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Short description for students'),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeThumbColor: AppColors.primaryMaroon,
                title: const Text('Issued by an office'),
                subtitle: const Text('Students get it from that office; no template download.'),
                value: _issued,
                onChanged: (v) => setState(() => _issued = v),
              ),
              if (_issued)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _office,
                      decoration: const InputDecoration(labelText: 'Office', hintText: 'e.g. Clinic, Registrar'),
                      validator: (v) => _issued && (v ?? '').trim().isEmpty ? 'Enter the office' : null,
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      children: [
                        for (final office in const ['Clinic', 'Registrar'])
                          ActionChip(label: Text(office), onPressed: () => _office.text = office),
                      ],
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.of(context).pop(_RequirementForm(
              _name.text.trim(),
              _description.text.trim(),
              _issued ? _office.text.trim() : null,
            ));
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryMaroon,
            foregroundColor: Colors.white,
          ),
          child: Text(editing ? 'Save' : 'Add'),
        ),
      ],
    );
  }
}
