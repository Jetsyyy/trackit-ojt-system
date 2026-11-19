import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../../models/admin_class.dart';
import '../../../models/admin_overview.dart';
import '../../../models/hte_company.dart';
import '../../../services/admin_classes_service.dart';
import '../../../services/admin_hte_companies_service.dart';
import '../../../services/admin_overview_service.dart';
import '../../../services/api_client.dart';
import '../../../widgets/admin/academic_year_picker.dart';
import '../../../widgets/common/desk_ui.dart';
import '../admin_overview_detail_screens.dart';

const _ink = Color(0xFF2A1215);
const _muted = Color(0xFF6B6B6B);
const _shades = [Color(0xFF6E1423), Color(0xFFC94A5E), Color(0xFFE48A99), Color(0xFFF0BCC4)];

/// Admin Dashboard (TrackIT admin mockup): totals, OJT Student Completion,
/// HTE Industry Contribution and Student Locations for an academic year.
/// Wide windows use the mockup's two-column grid; narrower ones stack the
/// same cards so the charts never get squeezed.
class AdminDashboardDesk extends StatefulWidget {
  final ApiClient client;
  final String adminName;
  final VoidCallback onOpenHteDirectory;

  const AdminDashboardDesk({
    super.key,
    required this.client,
    required this.adminName,
    required this.onOpenHteDirectory,
  });

  @override
  State<AdminDashboardDesk> createState() => _AdminDashboardDeskState();
}

class _AdminDashboardDeskState extends State<AdminDashboardDesk> {
  late final AdminClassesService _classes = HttpAdminClassesService(widget.client);
  late final AdminOverviewService _overviewService = HttpAdminOverviewService(widget.client);
  late final AdminHteCompaniesService _hte = HttpAdminHteCompaniesService(widget.client);

  List<AdminAcademicYear> _years = [];
  String? _year;
  AdminOverview? _overview;
  List<HteCompany> _companies = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final years = await _classes.getAcademicYears();
      final now = DateTime.now();
      final start = now.month >= 8 ? now.year : now.year - 1;
      final working = years.isEmpty
          ? [AdminAcademicYear(year: '$start-${start + 1}', classCount: 0, isCurrent: true)]
          : years;
      _years = working;
      _year = working.firstWhere((y) => y.isCurrent, orElse: () => working.first).year;
      await _load();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e is ApiException ? e.message : '$e';
          _loading = false;
        });
      }
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([_overviewService.getOverview(academicYear: _year!), _hte.getCompanies()]);
      if (!mounted) return;
      setState(() {
        _overview = results[0] as AdminOverview;
        _companies = results[1] as List<HteCompany>;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e is ApiException ? e.message : '$e';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final first = widget.adminName.trim().split(' ').first;
    return DeskPage(
      title: '${phGreeting()}, ${first.isEmpty ? 'Admin' : first}!',
      onRefresh: _load,
      trailing: _years.isEmpty
          ? null
          : AcademicYearPicker(
              years: _years,
              selected: _year,
              onSelected: (y) {
                setState(() => _year = y);
                _load();
              },
            ),
      children: [
        if (_loading && _overview == null)
          const SizedBox(
            height: 300,
            child: Center(child: CircularProgressIndicator(color: DeskColors.maroon)),
          )
        else if (_error != null && _overview == null)
          DeskCard(child: Text('Could not load the dashboard: $_error'))
        else
          LayoutBuilder(builder: (context, box) => _content(_overview!, box.maxWidth)),
      ],
    );
  }

  Widget _content(AdminOverview o, double width) {
    final stats = [
      (Icons.groups_outlined, 'Total OJT Students', o.totalStudents),
      (Icons.person_outline, 'Total Instructors', o.totalInstructors),
      (Icons.apartment_outlined, 'Total Host Training\nEstablishments (HTE)', _companies.length),
    ];
    final wide = width >= 940;
    final panelWidth = (wide ? (width - 18) * 9 / 14 : width) - 48;
    Widget completion({required bool fill}) => _Panel(
      child: _DonutSection(
        width: panelWidth,
        title: 'OJT Student Completion',
        headLabel: 'COMPLETION STATUS',
        centerValue: o.totalStudents,
        centerLabel: 'Total students',
        fill: fill,
        slices: [
          _Slice('Completed', o.completedCount, _shades[0]),
          _Slice('Ongoing', o.ongoingCount, _shades[1]),
          _Slice('Not Started', o.notStartedCount, _shades[3]),
        ],
        buttonLabel: 'View Student List  >',
        onButton: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => AdminOverviewStudentListScreen(students: o.studentList))),
      ),
    );
    Widget industry({required bool fill}) =>
        _IndustryCard(companies: _companies, onView: widget.onOpenHteDirectory, fill: fill);
    Widget locations({required bool fill}) => _Panel(
      child: _locationsSection(fill: fill, width: panelWidth),
    );

    // Mockup grid: stats + completion on top, industry + locations below.
    if (wide) {
      return Column(
        children: [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 5,
                  child: Column(
                    children: [
                      for (var i = 0; i < stats.length; i++) ...[
                        if (i > 0) const SizedBox(height: 14),
                        Expanded(
                          child: _StatCard(icon: stats[i].$1, label: stats[i].$2, value: stats[i].$3),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(flex: 9, child: completion(fill: true)),
              ],
            ),
          ),
          const SizedBox(height: 18),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 5, child: industry(fill: true)),
                const SizedBox(width: 18),
                Expanded(flex: 9, child: locations(fill: true)),
              ],
            ),
          ),
        ],
      );
    }

    // Narrow: everything in one column (stats side by side on tablets).
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (width >= 600)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < stats.length; i++) ...[
                  if (i > 0) const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(icon: stats[i].$1, label: stats[i].$2, value: stats[i].$3),
                  ),
                ],
              ],
            ),
          )
        else
          for (var i = 0; i < stats.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            _StatCard(icon: stats[i].$1, label: stats[i].$2, value: stats[i].$3),
          ],
        const SizedBox(height: 16),
        completion(fill: false),
        const SizedBox(height: 16),
        industry(fill: false),
        const SizedBox(height: 16),
        locations(fill: false),
      ],
    );
  }

  /// The city a company is in: the part of its location (or address) that
  /// names a city, else the location's first part.
  static String _cityOf(HteCompany c) {
    final cityLike = RegExp(r'city|manila|municipality', caseSensitive: false);
    for (final source in [c.location, c.address]) {
      for (final part in source.split(',')) {
        final p = part.trim();
        if (p.isNotEmpty && cityLike.hasMatch(p)) return p;
      }
    }
    final first = c.location.split(',').first.trim();
    if (first.isNotEmpty) return first;
    final region = c.region.trim();
    return region.isEmpty ? 'Not set' : region;
  }

  Widget _locationsSection({required bool fill, required double width}) {
    final byCity = <String, int>{};
    for (final c in _companies) {
      if (c.students.isEmpty) continue;
      final key = _cityOf(c);
      byCity[key] = (byCity[key] ?? 0) + c.students.length;
    }
    final sorted = byCity.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.take(4).toList();
    final others = sorted.skip(4).fold<int>(0, (sum, e) => sum + e.value);
    final slices = [
      for (var i = 0; i < top.length; i++) _Slice(top[i].key, top[i].value, _shades[i]),
      if (others > 0) _Slice('Other locations', others, const Color(0xFFCFC9C9)),
    ];
    final total = slices.fold<int>(0, (s, e) => s + e.count);
    return _DonutSection(
      width: width,
      title: 'Student Locations',
      headLabel: 'CITY / REGION',
      centerValue: total,
      centerLabel: 'Students placed',
      slices: slices,
      fill: fill,
      emptyText: 'No students placed at a company yet.',
      buttonLabel: 'View Location Report  >',
      onButton: widget.onOpenHteDirectory,
    );
  }
}

/// White rounded card with the soft drop shadow used in the mockup.
class _Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _Panel({required this.child, this.padding = const EdgeInsets.fromLTRB(24, 22, 24, 20)});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Color(0x1F000000), blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: child,
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final int value;

  const _StatCard({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return _Panel(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(color: const Color(0xFFF8E9EA), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: DeskColors.maroon, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: const TextStyle(fontSize: 12.5, color: Color(0xFF555555), height: 1.25)),
                const SizedBox(height: 2),
                Text(
                  '$value',
                  style: const TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1F1F1F),
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Slice {
  final String label;
  final int count;
  final Color color;

  const _Slice(this.label, this.count, this.color);
}

/// Donut chart with its legend table (label / students / share) and a
/// button underneath. Below 480px wide the legend moves under the donut.
class _DonutSection extends StatelessWidget {
  final String title;
  final String headLabel;
  final int centerValue;
  final String centerLabel;
  final List<_Slice> slices;
  final String buttonLabel;
  final VoidCallback onButton;
  final String? emptyText;

  /// True when the card has a fixed height to fill (the wide grid), so the
  /// button sits at the bottom.
  final bool fill;

  /// Inner width of the card.
  final double width;

  const _DonutSection({
    required this.width,
    required this.title,
    required this.headLabel,
    required this.centerValue,
    required this.centerLabel,
    required this.slices,
    required this.buttonLabel,
    required this.onButton,
    required this.fill,
    this.emptyText,
  });

  Widget _donut(double size) => SizedBox(
    width: size,
    height: size,
    child: CustomPaint(
      painter: _DonutPainter(slices, stroke: size * 0.17),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$centerValue',
              style: TextStyle(fontSize: size * 0.2, fontWeight: FontWeight.w800, color: _ink, height: 1.1),
            ),
            Text(centerLabel, style: const TextStyle(fontSize: 11, color: _muted)),
          ],
        ),
      ),
    ),
  );

  Widget _legend() {
    final total = slices.fold<int>(0, (s, e) => s + e.count);
    const head = TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _muted, letterSpacing: 0.4);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(headLabel, style: head)),
            const SizedBox(
              width: 70,
              child: Text('STUDENTS', textAlign: TextAlign.right, style: head),
            ),
            const SizedBox(
              width: 70,
              child: Text('SHARE', textAlign: TextAlign.right, style: head),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (slices.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Text(emptyText ?? 'No data yet.', style: const TextStyle(fontSize: 12.5, color: DeskColors.muted)),
          ),
        for (var i = 0; i < slices.length; i++) ...[
          if (i > 0) const Divider(height: 1, color: Color(0xFFECE7E7)),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 11),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: slices[i].color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    slices[i].label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13.5, color: _ink),
                  ),
                ),
                SizedBox(
                  width: 70,
                  child: Text(
                    '${slices[i].count}',
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _ink),
                  ),
                ),
                SizedBox(
                  width: 70,
                  child: Text(
                    total == 0 ? '0%' : '${(slices[i].count / total * 100).toStringAsFixed(1)}%',
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 12.5, color: _muted),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final button = SizedBox(
      height: 40,
      child: OutlinedButton(
        onPressed: onButton,
        style: OutlinedButton.styleFrom(
          foregroundColor: DeskColors.maroon,
          side: const BorderSide(color: Color(0xFFDDDDDD)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(buttonLabel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      ),
    );
    {
      final stacked = width < 480;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: _ink),
          ),
          const SizedBox(height: 18),
          if (stacked) ...[
            Center(child: _donut(170)),
            const SizedBox(height: 18),
            _legend(),
            const SizedBox(height: 14),
            button,
          ] else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _donut(width >= 640 ? 184 : 156),
                const SizedBox(width: 32),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [_legend(), const SizedBox(height: 18), button],
                  ),
                ),
              ],
            ),
          if (fill) const Spacer(),
        ],
      );
    }
  }
}

class _DonutPainter extends CustomPainter {
  final List<_Slice> slices;
  final double stroke;

  _DonutPainter(this.slices, {required this.stroke});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(stroke / 2);
    final total = slices.fold<int>(0, (s, e) => s + e.count);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    if (total == 0) {
      canvas.drawArc(rect, 0, math.pi * 2, false, paint..color = const Color(0xFFEDE8E8));
      return;
    }
    final shown = slices.where((s) => s.count > 0).length;
    // A thin white gap between slices, like the mockup.
    final gap = shown > 1 ? 0.03 : 0.0;
    var start = -math.pi / 2;
    for (final s in slices) {
      if (s.count == 0) continue;
      final sweep = math.pi * 2 * s.count / total;
      canvas.drawArc(rect, start + gap / 2, math.max(sweep - gap, 0.001), false, paint..color = s.color);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) => true;
}

class _IndustryCard extends StatelessWidget {
  final List<HteCompany> companies;
  final VoidCallback onView;
  final bool fill;

  const _IndustryCard({required this.companies, required this.onView, required this.fill});

  static IconData _icon(String industry) {
    final i = industry.toLowerCase();
    if (i.contains('tech') || i.contains(' it') || i.startsWith('it') || i.contains('software')) return Icons.laptop;
    if (i.contains('bank') || i.contains('business') || i.contains('financ')) return Icons.business_center;
    if (i.contains('engineer') || i.contains('electric') || i.contains('manufact')) return Icons.settings;
    if (i.contains('gov')) return Icons.account_balance;
    if (i.contains('health') || i.contains('medic') || i.contains('hospital')) return Icons.local_hospital;
    if (i.contains('educ') || i.contains('universit') || i.contains('school')) return Icons.school;
    if (i.contains('retail') || i.contains('grocer')) return Icons.storefront;
    if (i.contains('bpo') || i.contains('call')) return Icons.headset_mic;
    if (i.contains('research')) return Icons.science;
    return Icons.apartment;
  }

  /// Short chart label for a long industry name (the full name is in the
  /// tooltip), e.g. "Healthcare and Medical Services" -> "Healthcare".
  static String _short(String industry) {
    final i = industry.toLowerCase();
    if (i.contains('tech')) return 'Technology';
    if (i.contains('business') || i.contains('financ') || i.contains('bank')) return 'Business / Finance';
    if (i.contains('engineer') || i.contains('electric')) return 'Engineering';
    if (i.contains('gov')) return 'Government';
    if (i.contains('health') || i.contains('medic') || i.contains('hospital')) return 'Healthcare';
    if (i.contains('manufact')) return 'Manufacturing';
    if (i.contains('educ') || i.contains('universit') || i.contains('school')) return 'Education';
    if (i.contains('research')) return 'Research';
    if (i.contains('bpo')) return 'BPO';
    return industry;
  }

  @override
  Widget build(BuildContext context) {
    final counts = <String, int>{};
    for (final c in companies) {
      final key = c.industry.trim().isEmpty ? 'Other' : c.industry.trim();
      counts[key] = (counts[key] ?? 0) + 1;
    }
    final top = (counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).take(5).toList();
    final max = top.isEmpty ? 1 : top.first.value;
    const shades = [Color(0xFF5C1219), Color(0xFFC94A5E), Color(0xFFD65D70), Color(0xFFE9A3AE), Color(0xFFF3C9CF)];
    return _Panel(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'HTE Industry Contribution',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _ink),
          ),
          const SizedBox(height: 6),
          const Text('Distribution of registered HTEs by industry.', style: TextStyle(fontSize: 12, color: _muted)),
          const SizedBox(height: 16),
          if (top.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('No companies yet.', style: TextStyle(fontSize: 12.5, color: DeskColors.muted)),
            ),
          for (var i = 0; i < top.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 9),
              child: Row(
                children: [
                  SizedBox(width: 26, child: Icon(_icon(top[i].key), size: 22, color: const Color(0xFF3A1A1D))),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 6,
                    child: Tooltip(
                      message: top[i].key,
                      child: Text(
                        _short(top[i].key),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, color: _ink),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 5,
                    child: Container(
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE6E0E0)),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: (top[i].value / max).clamp(0.04, 1.0),
                        child: Container(
                          decoration: BoxDecoration(color: shades[i], borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 38,
                    child: Text(
                      '${top[i].value}',
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _ink),
                    ),
                  ),
                ],
              ),
            ),
          if (fill) const Spacer(),
          const SizedBox(height: 12),
          SizedBox(
            height: 40,
            child: OutlinedButton(
              onPressed: onView,
              style: OutlinedButton.styleFrom(
                foregroundColor: DeskColors.maroon,
                side: const BorderSide(color: Color(0xFFDDDDDD)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('View HTE Directory  >', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}
