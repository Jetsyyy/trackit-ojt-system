import 'package:flutter/material.dart';
import '../../models/hte_company.dart';
import '../../services/api_client.dart';
import '../common/desk_ui.dart';

/// One company as shown in the merge tool, with what points at it.
class HteMergeCompany {
  final int id;
  final String name;
  final String? location;
  final String source;
  final int students;
  final int reports;

  const HteMergeCompany({
    required this.id,
    required this.name,
    this.location,
    required this.source,
    required this.students,
    required this.reports,
  });

  bool get addedByStudent => source == 'student';

  factory HteMergeCompany.fromJson(Map<String, dynamic> json) => HteMergeCompany(
        id: (json['id'] as num).toInt(),
        name: json['name'] as String? ?? '',
        location: json['location'] as String?,
        source: json['source'] as String? ?? 'admin',
        students: (json['students'] as num?)?.toInt() ?? 0,
        reports: (json['reports'] as num?)?.toInt() ?? 0,
      );
}

/// Companies whose names look like the same company; [keepId] is the
/// suggested record to keep (the admin's, or the one with more students).
class HteDuplicateGroup {
  final int keepId;
  final List<HteMergeCompany> companies;

  const HteDuplicateGroup({required this.keepId, required this.companies});

  factory HteDuplicateGroup.fromJson(Map<String, dynamic> json) => HteDuplicateGroup(
        keepId: (json['keepId'] as num).toInt(),
        companies: (json['companies'] as List<dynamic>)
            .map((c) => HteMergeCompany.fromJson(c as Map<String, dynamic>))
            .toList(),
      );
}

/// What a merge would move (from a dry run).
class HteMergePreview {
  final int students;
  final int reports;
  final int supervisors;

  const HteMergePreview({required this.students, required this.reports, required this.supervisors});
}

/// The calls the merge tool needs (implemented by the admin HTE service).
abstract class HteMergeApi {
  Future<List<HteDuplicateGroup>> getDuplicates();
  Future<HteMergePreview> previewMerge({required int keepId, required List<int> mergeIds});
  Future<void> merge({required int keepId, required List<int> mergeIds});
}

/// Admin HTE Directory → Merge Duplicates. Lists likely duplicates (pick
/// the record to keep) and also lets the admin merge any two companies.
/// Returns true when something was merged.
Future<bool> showHteMergeDialog(
  BuildContext context, {
  required HteMergeApi api,
  required List<HteCompany> companies,
}) async {
  final changed = await showDialog<bool>(
    context: context,
    builder: (_) => _HteMergeDialog(api: api, companies: companies),
  );
  return changed == true;
}

class _HteMergeDialog extends StatefulWidget {
  final HteMergeApi api;
  final List<HteCompany> companies;

  const _HteMergeDialog({required this.api, required this.companies});

  @override
  State<_HteMergeDialog> createState() => _HteMergeDialogState();
}

class _HteMergeDialogState extends State<_HteMergeDialog> {
  List<HteDuplicateGroup> _groups = [];
  final Map<int, int> _keep = {}; // group index -> chosen company id
  bool _loading = true;
  String? _error;
  bool _busy = false;
  bool _changed = false;
  late List<HteCompany> _companies = [...widget.companies]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  int? _manualKeep;
  int? _manualMerge;

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    try {
      final groups = await widget.api.getDuplicates();
      if (!mounted) return;
      setState(() {
        _groups = groups;
        _keep
          ..clear()
          ..addAll({for (var i = 0; i < groups.length; i++) i: groups[i].keepId});
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e is ApiException ? e.message : 'Could not look for duplicates.';
        });
      }
    }
  }

  String _names(List<int> ids) {
    String nameOf(int id) {
      for (final g in _groups) {
        for (final c in g.companies) {
          if (c.id == id) return c.name;
        }
      }
      for (final c in _companies) {
        if (c.id == id) return c.name;
      }
      return 'Company #$id';
    }

    return ids.map((id) => '"${nameOf(id)}"').join(', ');
  }

  String _plural(int n, String one) => '$n $one${n == 1 ? '' : 's'}';

  Future<void> _merge(int keepId, List<int> mergeIds) async {
    if (mergeIds.isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      final preview = await widget.api.previewMerge(keepId: keepId, mergeIds: mergeIds);
      if (!mounted) return;
      final moves = [
        if (preview.students > 0) _plural(preview.students, 'student'),
        if (preview.reports > 0) _plural(preview.reports, 'weekly report'),
        if (preview.supervisors > 0) _plural(preview.supervisors, 'supervisor'),
      ];
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Merge these companies?'),
          content: SizedBox(
            width: 420,
            child: Text(
              'Keep ${_names([keepId])}.\n\n'
              '${_names(mergeIds)} will be merged into it and removed from the directory. '
              '${moves.isEmpty ? 'Nothing is linked to ${mergeIds.length == 1 ? 'it' : 'them'} yet.' : '${moves.join(', ')} will move over.'} '
              'New contacts are copied, and any blank details of the kept company are filled in.\n\n'
              'This can\'t be undone.',
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: DeskColors.maroon),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Merge'),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) {
        setState(() => _busy = false);
        return;
      }
      await widget.api.merge(keepId: keepId, mergeIds: mergeIds);
      if (!mounted) return;
      _changed = true;
      _companies = _companies.where((c) => !mergeIds.contains(c.id)).toList();
      _manualKeep = null;
      _manualMerge = null;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Merged into ${_names([keepId])}.')));
      await _loadGroups();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e is ApiException ? e.message : 'Could not merge the companies.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(24, 20, 12, 0),
      title: Row(
        children: [
          const Icon(Icons.merge_type, color: DeskColors.maroon),
          const SizedBox(width: 8),
          const Expanded(child: Text('Merge Duplicate Companies', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
          IconButton(
            tooltip: 'Close',
            onPressed: _busy ? null : () => Navigator.pop(context, _changed),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      content: SizedBox(
        width: 640,
        child: _loading
            ? const SizedBox(height: 160, child: Center(child: CircularProgressIndicator(color: DeskColors.maroon)))
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Choose the record to keep. The others are merged into it: their students, weekly reports, '
                      'supervisors and contacts move over, then they are removed.',
                      style: TextStyle(fontSize: 12.5, color: DeskColors.muted),
                    ),
                    const SizedBox(height: 14),
                    const Text('Possible duplicates', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    if (_error != null)
                      Text(_error!, style: const TextStyle(color: Color(0xFFC62828)))
                    else if (_groups.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAF5EC),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.check_circle_outline, color: Color(0xFF1E7B3A), size: 18),
                            SizedBox(width: 8),
                            Expanded(child: Text('No likely duplicates found.', style: TextStyle(fontSize: 12.5))),
                          ],
                        ),
                      )
                    else
                      for (var i = 0; i < _groups.length; i++) ...[
                        _groupCard(i),
                        const SizedBox(height: 10),
                      ],
                    const SizedBox(height: 10),
                    const Divider(),
                    const SizedBox(height: 6),
                    const Text('Merge other companies', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    const Text(
                      'For duplicates TrackIT didn\'t spot, e.g. an abbreviation like "BPI".',
                      style: TextStyle(fontSize: 11.5, color: DeskColors.muted),
                    ),
                    const SizedBox(height: 10),
                    _manualPicker(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _groupCard(int index) {
    final group = _groups[index];
    final keepId = _keep[index] ?? group.keepId;
    final others = group.companies.where((c) => c.id != keepId).map((c) => c.id).toList();
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE6C9CD)),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.fromLTRB(4, 6, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RadioGroup<int>(
            groupValue: keepId,
            onChanged: (v) {
              if (v != null && !_busy) setState(() => _keep[index] = v);
            },
            child: Column(
              children: [
                for (final c in group.companies) _companyOption(c, keep: c.id == keepId),
              ],
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              // Read the choice at press time, not from this build.
              onPressed: _busy
                  ? null
                  : () {
                      final keep = _keep[index] ?? group.keepId;
                      _merge(keep, [for (final c in group.companies) if (c.id != keep) c.id]);
                    },
              style: FilledButton.styleFrom(backgroundColor: DeskColors.maroon, visualDensity: VisualDensity.compact),
              icon: const Icon(Icons.merge_type, size: 16),
              label: Text(others.length == 1 ? 'Merge into kept company' : 'Merge ${others.length} into kept company',
                  style: const TextStyle(fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _companyOption(HteMergeCompany c, {required bool keep}) {
    final details = [
      (c.location ?? '').trim().isEmpty ? 'No location yet' : c.location!,
      c.addedByStudent ? 'Added by a student' : 'Added by admin',
      _plural(c.students, 'student'),
      if (c.reports > 0) _plural(c.reports, 'weekly report'),
    ].join('  ·  ');
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: _busy ? null : () => setState(() => _keep[_groups.indexWhere((g) => g.companies.contains(c))] = c.id),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Radio<int>(value: c.id),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  Text(details, style: const TextStyle(fontSize: 11, color: DeskColors.muted)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: keep ? const Color(0xFFEAF5EC) : const Color(0xFFFDEBDD),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                keep ? 'KEEP' : 'MERGE',
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  color: keep ? const Color(0xFF1E7B3A) : const Color(0xFF8A4310),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _manualPicker() {
    DropdownMenu<int> menu({required String label, required int? value, required ValueChanged<int?> onSelected, int? exclude}) {
      return DropdownMenu<int>(
        key: ValueKey('$label-$value-${_companies.length}'),
        label: Text(label),
        initialSelection: value,
        enableFilter: true,
        requestFocusOnTap: true,
        expandedInsets: EdgeInsets.zero,
        menuHeight: 260,
        textStyle: const TextStyle(fontSize: 12.5),
        onSelected: onSelected,
        dropdownMenuEntries: [
          for (final c in _companies)
            if (c.id != exclude)
              DropdownMenuEntry(
                value: c.id,
                label: c.name,
                labelWidget: Text(
                  c.location.trim().isEmpty ? c.name : '${c.name} — ${c.location}',
                  style: const TextStyle(fontSize: 12.5),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
        ],
      );
    }

    final ready = _manualKeep != null && _manualMerge != null && _manualKeep != _manualMerge;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        menu(
          label: 'Keep this company',
          value: _manualKeep,
          exclude: _manualMerge,
          onSelected: (v) => setState(() => _manualKeep = v),
        ),
        const SizedBox(height: 10),
        menu(
          label: 'Merge this one into it',
          value: _manualMerge,
          exclude: _manualKeep,
          onSelected: (v) => setState(() => _manualMerge = v),
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: OutlinedButton.icon(
            onPressed: ready && !_busy ? () => _merge(_manualKeep!, [_manualMerge!]) : null,
            style: OutlinedButton.styleFrom(foregroundColor: DeskColors.maroon),
            icon: const Icon(Icons.merge_type, size: 16),
            label: const Text('Merge', style: TextStyle(fontSize: 12)),
          ),
        ),
      ],
    );
  }
}
