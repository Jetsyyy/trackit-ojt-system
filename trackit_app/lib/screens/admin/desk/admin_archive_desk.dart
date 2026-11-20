import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../services/admin_archive_service.dart';
import '../../../services/api_client.dart';
import '../../../utils/file_download.dart';
import '../../../widgets/common/desk_ui.dart';

/// Admin > Archive (revised design): the active academic year's Current
/// Records, archiving it after the Admin confirms their email and
/// password, and the list of archived academic years to download. Class
/// Management was removed, so the archive is per academic year, not per
/// class.
class AdminArchiveDesk extends StatefulWidget {
  final ApiClient client;
  final String adminEmail;

  const AdminArchiveDesk({super.key, required this.client, required this.adminEmail});

  @override
  State<AdminArchiveDesk> createState() => _AdminArchiveDeskState();
}

/// "2026-2027" -> "A.Y. 2026 – 2027".
String ayLabel(String? year) =>
    year == null || year.isEmpty ? 'A.Y. —' : 'A.Y. ${year.replaceAll('-', ' – ')}';

class _AdminArchiveDeskState extends State<AdminArchiveDesk> {
  static const _pageSize = 4;

  late final AdminArchiveService _service = HttpAdminArchiveService(widget.client);
  late final _emailController = TextEditingController(text: widget.adminEmail);
  final _passwordController = TextEditingController();

  ArchiveStatus? _status;
  List<HteSnapshotSummary> _years = [];
  bool _loading = true;
  String? _error;
  bool _archiving = false;
  bool _showPassword = false;
  String? _formError;
  int _page = 0;
  String? _downloading;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([_service.getStatus(), _service.getHteSnapshots()]);
      if (!mounted) return;
      setState(() {
        _status = results[0] as ArchiveStatus;
        _years = results[1] as List<HteSnapshotSummary>;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e is ApiException ? e.message : '$e';
      });
    }
  }

  void _snack(String message) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  Future<void> _archive() async {
    final status = _status;
    if (status?.activeYear == null) return;
    if (_emailController.text.trim().isEmpty || _passwordController.text.isEmpty) {
      setState(() => _formError = 'Enter your admin email and password to confirm.');
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Archive ${ayLabel(status!.activeYear)}?'),
        content: Text(
          'This saves the year\'s OJT records (${status.companies} companies, ${status.students} students, '
          '${status.sections} sections) to the archive and makes ${ayLabel(status.nextYear)} the active '
          'academic year. This can\'t be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: DeskColors.maroon),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Archive'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() {
      _archiving = true;
      _formError = null;
    });
    try {
      final result = await _service.archiveActiveYear(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      _passwordController.clear();
      await _load();
      if (mounted) {
        _snack('${ayLabel(result.archivedYear)} archived. ${ayLabel(result.activeYear)} is now active.');
      }
    } catch (e) {
      if (mounted) setState(() => _formError = e is ApiException ? e.message : 'Could not archive. Try again.');
    } finally {
      if (mounted) setState(() => _archiving = false);
    }
  }

  Future<void> _download(HteSnapshotSummary year, String format) async {
    setState(() => _downloading = year.academicYear);
    try {
      final file = await _service.downloadHteSnapshot(year.academicYear, format: format);
      final saved = downloadBytes(
        filename: file.filename ?? 'TrackIT-Archive-${year.academicYear}.$format',
        bytes: file.bytes,
      );
      if (mounted) _snack(saved ? 'Download started.' : 'Downloads are available in the web app.');
    } catch (e) {
      if (mounted) _snack(e is ApiException ? e.message : 'Could not download the archive.');
    } finally {
      if (mounted) setState(() => _downloading = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DeskPage(
      title: 'Archive',
      onRefresh: _load,
      children: [
        if (_loading)
          const SizedBox(height: 300, child: Center(child: CircularProgressIndicator(color: DeskColors.maroon)))
        else if (_error != null)
          DeskCard(child: Text('Could not load the archive: $_error'))
        else ...[
          _CardShell(
            child: LayoutBuilder(
              builder: (context, box) {
                final wide = box.maxWidth >= 720;
                final records = _currentRecords();
                final confirm = _confirmForm();
                if (!wide) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [records, const Divider(height: 36), confirm],
                  );
                }
                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(flex: 11, child: records),
                      const VerticalDivider(width: 44, color: Color(0xFFE6DCDD)),
                      Expanded(flex: 8, child: confirm),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 18),
          _CardShell(child: _archivedTable()),
        ],
      ],
    );
  }

  Widget _currentRecords() {
    final s = _status!;
    Widget stat(String label, int value) => Expanded(
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2DADB)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: DeskColors.heading)),
                const SizedBox(height: 2),
                Text('$value', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFF1F1F1F))),
              ],
            ),
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.only(bottom: 3),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: DeskColors.heading, width: 2))),
          child: const Text(
            'Current Records',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: DeskColors.heading),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            const _YearIcon(),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ayLabel(s.activeYear), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                Text(
                  s.alreadyArchived ? 'OJT Records · Archived' : 'OJT Records · In progress',
                  style: const TextStyle(fontSize: 11, color: DeskColors.muted),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            stat('Companies', s.companies),
            const SizedBox(width: 10),
            stat('Students', s.students),
            const SizedBox(width: 10),
            stat('Sections', s.sections),
          ],
        ),
      ],
    );
  }

  Widget _confirmForm() {
    final s = _status!;
    final canArchive = s.activeYear != null && !s.alreadyArchived && !_archiving && _passwordController.text.isNotEmpty;
    InputDecoration field(String hint, IconData icon, {Widget? suffix}) => InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(fontSize: 12.5, color: DeskColors.muted),
          prefixIcon: Icon(icon, size: 18, color: const Color(0xFF555555)),
          suffixIcon: suffix,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFDDDDDD)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: DeskColors.maroon),
          ),
        );
    const label = TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text("Confirm it's you", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        const Text('Email', style: label),
        const SizedBox(height: 4),
        TextField(
          controller: _emailController,
          style: const TextStyle(fontSize: 12.5),
          decoration: field('Admin email', Icons.mail_outline),
        ),
        const SizedBox(height: 10),
        const Text('Password', style: label),
        const SizedBox(height: 4),
        TextField(
          controller: _passwordController,
          obscureText: !_showPassword,
          style: const TextStyle(fontSize: 12.5),
          onSubmitted: (_) => canArchive ? _archive() : null,
          decoration: field(
            'Enter your password',
            Icons.lock_outline,
            suffix: IconButton(
              tooltip: _showPassword ? 'Hide password' : 'Show password',
              icon: Icon(_showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18),
              onPressed: () => setState(() => _showPassword = !_showPassword),
            ),
          ),
        ),
        if (_formError != null) ...[
          const SizedBox(height: 8),
          Text(_formError!, style: const TextStyle(fontSize: 11.5, color: Color(0xFFC62828))),
        ],
        const SizedBox(height: 14),
        SizedBox(
          height: 44,
          child: FilledButton.icon(
            onPressed: canArchive ? _archive : null,
            style: FilledButton.styleFrom(
              backgroundColor: DeskColors.maroon,
              disabledBackgroundColor: DeskColors.maroon.withValues(alpha: 0.55),
              disabledForegroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: _archiving
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.inventory_2_outlined, size: 18),
            label: Text(
              s.alreadyArchived ? '${ayLabel(s.activeYear)} is archived' : 'Archive ${ayLabel(s.activeYear)}',
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }

  Widget _archivedTable() {
    final pages = (_years.length / _pageSize).ceil().clamp(1, 1 << 20);
    final page = _page.clamp(0, pages - 1);
    final shown = _years.skip(page * _pageSize).take(_pageSize).toList();
    const head = TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF3A1A1D));
    const num = TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: DeskColors.heading);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
          decoration: BoxDecoration(color: const Color(0xFFF5E6E8), borderRadius: BorderRadius.circular(8)),
          child: const Row(
            children: [
              Expanded(flex: 5, child: Padding(padding: EdgeInsets.only(left: 46), child: Text('Academic Year', style: head))),
              Expanded(flex: 2, child: Text('Companies', style: head, textAlign: TextAlign.center)),
              Expanded(flex: 2, child: Text('Students', style: head, textAlign: TextAlign.center)),
              Expanded(flex: 2, child: Text('Sections', style: head, textAlign: TextAlign.center)),
              Expanded(flex: 3, child: Text('Archived On', style: head, textAlign: TextAlign.center)),
              SizedBox(width: 120),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (shown.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 36),
            child: Text(
              'No archived academic years yet. Archive the current year above when it ends.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: DeskColors.muted),
            ),
          ),
        for (final y in shown) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2DADB)),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 5,
                  child: Row(
                    children: [
                      const _YearIcon(),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(ayLabel(y.academicYear), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF3A1A1D))),
                            const Text('OJT Records', style: TextStyle(fontSize: 10.5, color: DeskColors.muted)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(flex: 2, child: Text('${y.companies}', style: num, textAlign: TextAlign.center)),
                Expanded(flex: 2, child: Text('${y.students}', style: num, textAlign: TextAlign.center)),
                Expanded(flex: 2, child: Text('${y.sections}', style: num, textAlign: TextAlign.center)),
                Expanded(
                  flex: 3,
                  child: Text(
                    DateFormat('MMM d, yyyy').format(y.archivedAt),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF333333)),
                  ),
                ),
                SizedBox(width: 120, child: Align(alignment: Alignment.centerRight, child: _downloadButton(y))),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
        const Divider(height: 22, color: Color(0xFFEDE3E4)),
        DeskPager(
          page: page,
          pageSize: _pageSize,
          total: _years.length,
          noun: 'Academic Years',
          onChanged: (p) => setState(() => _page = p),
        ),
      ],
    );
  }

  Widget _downloadButton(HteSnapshotSummary y) {
    final busy = _downloading == y.academicYear;
    return PopupMenuButton<String>(
      tooltip: 'Download ${ayLabel(y.academicYear)}',
      enabled: !busy,
      position: PopupMenuPosition.under,
      onSelected: (format) => _download(y, format),
      itemBuilder: (context) => const [
        PopupMenuItem(value: 'pdf', child: Text('PDF')),
        PopupMenuItem(value: 'xlsx', child: Text('Excel (.xlsx)')),
      ],
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(color: DeskColors.maroon, borderRadius: BorderRadius.circular(6)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            busy
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.download, size: 16, color: Colors.white),
            const SizedBox(width: 8),
            const Text('Download', style: TextStyle(fontSize: 11.5, color: Colors.white, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

class _CardShell extends StatelessWidget {
  final Widget child;

  const _CardShell({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Color(0x1F000000), blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: child,
    );
  }
}

class _YearIcon extends StatelessWidget {
  const _YearIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: const BoxDecoration(color: Color(0xFF6E1423), shape: BoxShape.circle),
      child: const Icon(Icons.inventory_2_outlined, size: 17, color: Colors.white),
    );
  }
}
