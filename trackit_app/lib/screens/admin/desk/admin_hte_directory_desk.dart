import 'package:flutter/material.dart';
import '../../../models/hte_company.dart';
import '../../../services/admin_hte_companies_service.dart';
import '../../../services/api_client.dart';
import '../../../utils/file_download.dart';
import '../../../widgets/common/desk_ui.dart';
import '../admin_hte_company_form_screen.dart';

enum _Sort { az, most, least, none }

/// Admin HTE Directory (TrackIT admin mockups): Partner Companies with
/// search, Location / Sections / Sort filters and expandable rows showing
/// the deployed students, plus the Reports panel that downloads a report
/// for exactly what's filtered.
class AdminHteDirectoryDesk extends StatefulWidget {
  final ApiClient client;

  const AdminHteDirectoryDesk({super.key, required this.client});

  @override
  State<AdminHteDirectoryDesk> createState() => _AdminHteDirectoryDeskState();
}

class _AdminHteDirectoryDeskState extends State<AdminHteDirectoryDesk> {
  static const _pageSize = 8;

  late final AdminHteCompaniesService _service = HttpAdminHteCompaniesService(widget.client);
  final _locationMenu = MenuController();
  final _sectionMenu = MenuController();
  final _sortMenu = MenuController();

  List<HteCompany> _companies = [];
  bool _loading = true;
  String? _error;
  String _query = '';
  Set<String> _locations = {};
  Set<String> _sections = {};
  _Sort _sort = _Sort.az;
  int _page = 0;
  int? _expanded;
  bool _withStudents = true;
  bool _generating = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final companies = await _service.getCompanies();
      if (!mounted) return;
      setState(() {
        _companies = companies;
        _loading = false;
        _error = null;
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

  // ---------------------------------------------------------- filtering

  List<String> get _allLocations {
    final set = <String>{};
    for (final c in _companies) {
      if (c.region.isNotEmpty) set.add(c.region);
    }
    return set.toList()..sort();
  }

  List<String> get _allSections {
    final set = <String>{};
    for (final c in _companies) {
      for (final s in c.students) {
        set.add('${s.program} - ${s.section}');
      }
    }
    return set.toList()..sort();
  }

  List<HtePlacement> _studentsOf(HteCompany c) => _sections.isEmpty
      ? c.students
      : c.students.where((s) => _sections.contains('${s.program} - ${s.section}')).toList();

  List<HteCompany> get _filtered {
    final q = _query.trim().toLowerCase();
    var list = _companies.where((c) {
      if (_locations.isNotEmpty && !_locations.contains(c.region) && !_locations.contains(c.location)) {
        return false;
      }
      if (_sections.isNotEmpty && _studentsOf(c).isEmpty) return false;
      if (q.isEmpty) return true;
      return c.name.toLowerCase().contains(q) ||
          c.address.toLowerCase().contains(q) ||
          c.location.toLowerCase().contains(q) ||
          c.students.any((s) => '${s.program} - ${s.section}'.toLowerCase().contains(q));
    }).toList();
    switch (_sort) {
      case _Sort.az:
        list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      case _Sort.most:
        list.sort((a, b) => _studentsOf(b).length.compareTo(_studentsOf(a).length));
      case _Sort.least:
        list.sort((a, b) => _studentsOf(a).length.compareTo(_studentsOf(b).length));
      case _Sort.none:
        list = list.where((c) => c.students.isEmpty).toList()
          ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    }
    return list;
  }

  static String _sortLabel(_Sort s) => switch (s) {
        _Sort.az => 'Company A-Z',
        _Sort.most => 'Most students',
        _Sort.least => 'Least students',
        _Sort.none => 'No students',
      };

  // ------------------------------------------------------------ actions

  Future<void> _generate(String format) async {
    setState(() => _generating = true);
    try {
      final file = await _service.downloadReport(
        format: format,
        location: _locations.isEmpty ? null : _locations.join(','),
        type: _withStudents ? 'students' : 'info',
        sections: _sections.toList(),
      );
      final saved = downloadBytes(filename: file.filename ?? 'HTE-Report.$format', bytes: file.bytes);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(saved ? 'Report downloaded.' : 'Downloads are available in the web app.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e is ApiException ? e.message : 'Could not generate the report.')),
      );
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _openForm([HteCompany? company]) async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => AdminHteCompanyFormScreen(service: _service, existingCompany: company)),
    );
    if (result == null) return;
    await _load();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result)));
  }

  Future<void> _delete(HteCompany company) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove company?'),
        content: Text('Remove "${company.name}" from the HTE Directory? This can\'t be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFC62828)),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _service.deleteCompany(company.id);
      await _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Company removed.')));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e is ApiException ? e.message : 'Could not remove it.')),
        );
      }
    }
  }

  // ---------------------------------------------------------------- UI

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final pages = (filtered.length / _pageSize).ceil().clamp(1, 1 << 20);
    final page = _page.clamp(0, pages - 1);
    final shown = filtered.skip(page * _pageSize).take(_pageSize).toList();
    final totalStudents = filtered.fold<int>(0, (s, c) => s + _studentsOf(c).length);
    return DeskPage(
      title: 'HTE Directory',
      onRefresh: _load,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: DeskCard(
                title: 'Partner Companies',
                trailing: TextButton.icon(
                  onPressed: () => _openForm(),
                  style: TextButton.styleFrom(foregroundColor: DeskColors.maroon),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Company', style: TextStyle(fontSize: 12)),
                ),
                child: _loading
                    ? const SizedBox(height: 300, child: Center(child: CircularProgressIndicator(color: DeskColors.maroon)))
                    : _error != null
                        ? Text('Could not load the directory: $_error')
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _filters(),
                              const SizedBox(height: 12),
                              _tableHeader(),
                              const SizedBox(height: 6),
                              if (shown.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 30),
                                  child: Text('No companies match these filters.', textAlign: TextAlign.center),
                                ),
                              for (final c in shown) ...[
                                _companyRow(c),
                                const SizedBox(height: 8),
                              ],
                              const SizedBox(height: 10),
                              DeskPager(
                                page: page,
                                pageSize: _pageSize,
                                total: filtered.length,
                                noun: 'Companies',
                                onChanged: (p) => setState(() => _page = p),
                              ),
                            ],
                          ),
              ),
            ),
            const SizedBox(width: 16),
            SizedBox(width: 250, child: _reportsPanel(totalStudents)),
          ],
        ),
      ],
    );
  }

  Widget _filters() {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 36,
            child: TextField(
              onChanged: (v) => setState(() {
                _query = v;
                _page = 0;
              }),
              style: const TextStyle(fontSize: 12),
              decoration: InputDecoration(
                hintText: 'Search company, location, or section...',
                hintStyle: const TextStyle(fontSize: 12, color: DeskColors.muted),
                prefixIcon: const Icon(Icons.search, size: 18),
                contentPadding: EdgeInsets.zero,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFD6D6D6)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: DeskColors.maroon),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        DeskFilterButton(
          icon: Icons.location_on_outlined,
          label: 'Location',
          active: _locations.isNotEmpty,
          controller: _locationMenu,
          menuChildren: [
            _CheckListPanel(
              options: _allLocations,
              selected: _locations,
              searchHint: 'Search location...',
              onApply: (v) {
                setState(() {
                  _locations = v;
                  _page = 0;
                });
                _locationMenu.close();
              },
            ),
          ],
        ),
        const SizedBox(width: 8),
        DeskFilterButton(
          icon: Icons.grid_view_rounded,
          label: 'Sections',
          active: _sections.isNotEmpty,
          controller: _sectionMenu,
          menuChildren: [
            _CheckListPanel(
              options: _allSections,
              selected: _sections,
              onApply: (v) {
                setState(() {
                  _sections = v;
                  _page = 0;
                });
                _sectionMenu.close();
              },
            ),
          ],
        ),
        const SizedBox(width: 8),
        DeskFilterButton(
          icon: Icons.swap_vert,
          prefix: 'Sort by',
          label: _sortLabel(_sort),
          active: _sort != _Sort.az,
          controller: _sortMenu,
          menuChildren: [
            SizedBox(
              width: 210,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(8, 4, 8, 8),
                    child: Text(
                      'SORT COMPANIES BY',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: DeskColors.muted),
                    ),
                  ),
                  for (final s in _Sort.values) ...[
                    if (s == _Sort.none) const Divider(height: 10),
                    Material(
                      color: _sort == s ? const Color(0xFFFBEFF0) : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(6),
                        onTap: () {
                          setState(() {
                            _sort = s;
                            _page = 0;
                          });
                          _sortMenu.close();
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          child: Row(
                            children: [
                              Icon(
                                _sort == s ? Icons.radio_button_checked : Icons.radio_button_off,
                                size: 18,
                                color: _sort == s ? DeskColors.maroon : const Color(0xFF8A8A8A),
                              ),
                              const SizedBox(width: 10),
                              Text(_sortLabel(s), style: const TextStyle(fontSize: 12.5)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _tableHeader() {
    const style = TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF333333));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      decoration: BoxDecoration(color: const Color(0xFFF5E6E8), borderRadius: BorderRadius.circular(6)),
      child: const Row(
        children: [
          SizedBox(width: 180, child: Text('Company', style: style)),
          Expanded(child: Text('Address', style: style)),
          SizedBox(width: 90, child: Text('Students', style: style)),
        ],
      ),
    );
  }

  Widget _companyRow(HteCompany c) {
    final students = _studentsOf(c);
    final open = _expanded == c.id;
    return Container(
      decoration: BoxDecoration(
        color: open ? const Color(0xFFFFF8F8) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: open ? const Color(0xFFE2B8BD) : const Color(0xFFDDDDDD)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = open ? null : c.id),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
              child: Row(
                children: [
                  SizedBox(
                    width: 180,
                    child: Text(c.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
                  Expanded(
                    child: Text(
                      c.address.isNotEmpty ? c.address : c.location,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11.5, color: Color(0xFF333333)),
                    ),
                  ),
                  SizedBox(
                    width: 50,
                    child: Center(child: DeskCountBadge(count: students.length)),
                  ),
                  Material(
                    color: open ? DeskColors.maroon : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                      side: BorderSide(color: open ? DeskColors.maroon : const Color(0xFFDDDDDD)),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: () => setState(() => _expanded = open ? null : c.id),
                      child: SizedBox(
                        width: 30,
                        height: 30,
                        child: Icon(
                          open ? Icons.close_fullscreen : Icons.open_in_full,
                          size: 15,
                          color: open ? Colors.white : const Color(0xFF333333),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (open) _deployed(c, students),
        ],
      ),
    );
  }

  Widget _deployed(HteCompany c, List<HtePlacement> students) {
    const head = TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF333333));
    const cell = TextStyle(fontSize: 11, color: Color(0xFF1F1F1F));
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Divider(height: 1, color: Color(0xFFEBD3D6)),
          const SizedBox(height: 10),
          Row(
            children: [
              const Expanded(
                child: Text('Deployed Students', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
              ),
              TextButton.icon(
                onPressed: () => _openForm(c),
                icon: const Icon(Icons.edit_outlined, size: 14),
                label: const Text('Edit company', style: TextStyle(fontSize: 11)),
                style: TextButton.styleFrom(foregroundColor: DeskColors.maroon),
              ),
              TextButton.icon(
                onPressed: () => _delete(c),
                icon: const Icon(Icons.delete_outline, size: 14),
                label: const Text('Remove', style: TextStyle(fontSize: 11)),
                style: TextButton.styleFrom(foregroundColor: const Color(0xFFC62828)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (students.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Text('No students deployed here this academic year.', style: TextStyle(fontSize: 11.5, color: DeskColors.muted)),
            )
          else
            Container(
              decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE0E0E0)), color: Colors.white),
              child: Column(
                children: [
                  Container(
                    color: const Color(0xFFF2F2F2),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    child: const Row(
                      children: [
                        Expanded(flex: 4, child: Text('Student Name', style: head)),
                        Expanded(flex: 2, child: Text('Section', style: head)),
                        Expanded(flex: 4, child: Text('Supervisor', style: head)),
                        Expanded(flex: 3, child: Text('Contact Number', style: head)),
                      ],
                    ),
                  ),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 180),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: students.length,
                      separatorBuilder: (_, _) => const Divider(height: 1, color: Color(0xFFEDEDED)),
                      itemBuilder: (context, i) {
                        final s = students[i];
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          child: Row(
                            children: [
                              Expanded(flex: 4, child: Text(s.name, style: cell)),
                              Expanded(
                                flex: 2,
                                child: Text('${s.program} - ${s.section}', style: cell.copyWith(fontWeight: FontWeight.w700, fontSize: 10)),
                              ),
                              Expanded(flex: 4, child: Text(s.supervisor ?? '--', style: cell)),
                              Expanded(flex: 3, child: Text(s.contactNumber ?? '--', style: cell)),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          if (students.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Text('Showing ${students.length} of ${students.length} students', style: const TextStyle(fontSize: 10, color: DeskColors.muted)),
                const Spacer(),
                if (students.length > 5)
                  const Text('↓ Scroll to view all students', style: TextStyle(fontSize: 10, color: DeskColors.muted)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _reportsPanel(int totalStudents) {
    const label = TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF333333));
    Widget docType(bool students, String title, String subtitle) {
      final selected = _withStudents == students;
      return InkWell(
        onTap: () => setState(() => _withStudents = students),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFFBEFF0) : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: selected ? DeskColors.maroon : const Color(0xFFDDDDDD)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                size: 16,
                color: selected ? DeskColors.maroon : const Color(0xFF8A8A8A),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: const TextStyle(fontSize: 10, color: DeskColors.muted)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    final where = _locations.isEmpty ? 'All Locations' : _locations.join(', ');
    return DeskCard(
      title: 'Reports',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Transform.translate(
            offset: const Offset(0, -10),
            child: const Text('Preview of filters applied to your report.', style: TextStyle(fontSize: 10.5, color: DeskColors.muted)),
          ),
          const Divider(height: 1, color: Color(0xFFEDEDED)),
          const SizedBox(height: 10),
          const Text('SELECTED FILTERS', style: TextStyle(fontSize: 9.5, color: DeskColors.muted, letterSpacing: 0.4)),
          const SizedBox(height: 10),
          const Text('Total No. of Students', style: label),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFF8E9EA), borderRadius: BorderRadius.circular(10)),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(color: DeskColors.maroon, borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.groups_outlined, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$totalStudents', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: DeskColors.maroon)),
                      Text('deployed in $where', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: DeskColors.muted)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFEDEDED)),
          const SizedBox(height: 12),
          const Text('Location', style: label),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _locations.isEmpty
                ? [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFDDDDDD)),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('All Locations', style: TextStyle(fontSize: 10.5, color: DeskColors.muted)),
                    ),
                  ]
                : [
                    for (final l in _locations)
                      _RemovableChip(label: l, onRemove: () => setState(() => _locations = {..._locations}..remove(l))),
                  ],
          ),
          if (_sections.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('Sections', style: label),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final s in _sections)
                  _RemovableChip(label: s, onRemove: () => setState(() => _sections = {..._sections}..remove(s))),
              ],
            ),
          ],
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFEDEDED)),
          const SizedBox(height: 12),
          const Text('Document Type', style: label),
          const SizedBox(height: 8),
          docType(false, 'HTE Information', 'Company, address, and contact'),
          const SizedBox(height: 8),
          docType(true, 'HTE with Students Info', 'Adds deployed students, sections, supervisors, and contacts'),
          const SizedBox(height: 14),
          PopupMenuButton<String>(
            enabled: !_generating,
            tooltip: 'Generate report',
            position: PopupMenuPosition.under,
            onSelected: _generate,
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'pdf', child: Text('PDF')),
              PopupMenuItem(value: 'xlsx', child: Text('Excel (.xlsx)')),
            ],
            child: Container(
              height: 42,
              decoration: BoxDecoration(color: DeskColors.maroon, borderRadius: BorderRadius.circular(8)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _generating
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.download, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  const Text('Generate Report', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RemovableChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;

  const _RemovableChip({required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 4, 4, 4),
      decoration: BoxDecoration(color: DeskColors.maroon, borderRadius: BorderRadius.circular(6)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(fontSize: 10.5, color: Colors.white)),
          const SizedBox(width: 4),
          InkWell(
            onTap: onRemove,
            child: const Icon(Icons.cancel, size: 14, color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

/// Multi-select dropdown panel with optional search, Clear and Apply.
class _CheckListPanel extends StatefulWidget {
  final List<String> options;
  final Set<String> selected;
  final ValueChanged<Set<String>> onApply;
  final String? searchHint;

  const _CheckListPanel({required this.options, required this.selected, required this.onApply, this.searchHint});

  @override
  State<_CheckListPanel> createState() => _CheckListPanelState();
}

class _CheckListPanelState extends State<_CheckListPanel> {
  late Set<String> _picked = {...widget.selected};
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final options = widget.options.where((o) => o.toLowerCase().contains(_q.toLowerCase())).toList();
    return SizedBox(
      width: 210,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.searchHint != null) ...[
            SizedBox(
              height: 32,
              child: TextField(
                onChanged: (v) => setState(() => _q = v),
                style: const TextStyle(fontSize: 11.5),
                decoration: InputDecoration(
                  hintText: widget.searchHint,
                  hintStyle: const TextStyle(fontSize: 11.5),
                  prefixIcon: const Icon(Icons.search, size: 16),
                  contentPadding: EdgeInsets.zero,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          if (options.isEmpty)
            const Padding(padding: EdgeInsets.all(8), child: Text('Nothing to choose yet.', style: TextStyle(fontSize: 11.5))),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  for (final o in options)
                    Material(
                      color: _picked.contains(o) ? const Color(0xFFFBEFF0) : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(6),
                        onTap: () => setState(() {
                          if (!_picked.remove(o)) _picked.add(o);
                        }),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                          child: Row(
                            children: [
                              Icon(
                                _picked.contains(o) ? Icons.check_box : Icons.check_box_outline_blank,
                                size: 18,
                                color: _picked.contains(o) ? DeskColors.maroon : const Color(0xFF8A8A8A),
                              ),
                              const SizedBox(width: 8),
                              Expanded(child: Text(o, style: const TextStyle(fontSize: 12))),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const Divider(height: 14),
          Row(
            children: [
              TextButton(
                onPressed: () => setState(() => _picked = {}),
                style: TextButton.styleFrom(foregroundColor: DeskColors.maroon),
                child: const Text('Clear', style: TextStyle(fontSize: 11.5, decoration: TextDecoration.underline)),
              ),
              const Spacer(),
              FilledButton(
                onPressed: () => widget.onApply({..._picked}),
                style: FilledButton.styleFrom(
                  backgroundColor: DeskColors.maroon,
                  visualDensity: VisualDensity.compact,
                  shape: const StadiumBorder(),
                ),
                child: const Text('Apply', style: TextStyle(fontSize: 11.5)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
