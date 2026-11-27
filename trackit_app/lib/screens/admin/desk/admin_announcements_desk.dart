import '../../../utils/pick_files.dart';
import 'package:flutter/material.dart';
import '../../../models/admin_announcement.dart';
import '../../../services/admin_announcements_service.dart';
import '../../../services/api_client.dart';
import '../../../utils/attachment_launcher.dart';
import '../../../utils/ph_time.dart';
import '../../../widgets/common/desk_ui.dart';

/// Admin Announcements (TrackIT admin mockup): the feed with search,
/// audience filter and pages on the left; Create Announcement on the
/// right (target audience, title, message, attachment).
class AdminAnnouncementsDesk extends StatefulWidget {
  final ApiClient client;

  const AdminAnnouncementsDesk({super.key, required this.client});

  @override
  State<AdminAnnouncementsDesk> createState() => _AdminAnnouncementsDeskState();
}

class _AdminAnnouncementsDeskState extends State<AdminAnnouncementsDesk> {
  static const _pageSize = 5;

  late final AdminAnnouncementsService _service = HttpAdminAnnouncementsService(widget.client);
  List<AdminAnnouncement> _items = [];
  bool _loading = true;
  String _query = '';
  AdminAnnouncementAudience? _filter;
  int _page = 0;

  final _title = TextEditingController();
  final _message = TextEditingController();
  AdminAnnouncementAudience _audience = AdminAnnouncementAudience.all;
  PickedFile? _file;
  bool _posting = false;
  String? _formError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _title.dispose();
    _message.dispose();
    super.dispose();
  }

  void _snack(String text, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), backgroundColor: error ? const Color(0xFFC62828) : null),
    );
  }

  Future<void> _load() async {
    try {
      final items = await _service.getAnnouncements();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _snack(e is ApiException ? e.message : 'Could not load announcements.', error: true);
      }
    }
  }

  List<AdminAnnouncement> get _visible {
    final q = _query.trim().toLowerCase();
    return _items.where((a) {
      if (_filter != null && a.targetAudience != _filter) return false;
      return q.isEmpty || a.title.toLowerCase().contains(q) || a.content.toLowerCase().contains(q);
    }).toList();
  }

  static String _audienceLabel(AdminAnnouncementAudience a) => switch (a) {
        AdminAnnouncementAudience.all => 'All Users',
        AdminAnnouncementAudience.instructors => 'Instructors',
        AdminAnnouncementAudience.students => 'Students',
      };

  static String _contentType(String name) {
    final n = name.toLowerCase();
    if (n.endsWith('.pdf')) return 'application/pdf';
    if (n.endsWith('.docx')) return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    if (n.endsWith('.png')) return 'image/png';
    return 'image/jpeg';
  }

  Future<void> _pickFile() async {
    final result = await pickFilesWithData(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'docx', 'jpg', 'jpeg', 'png'],
    );
    if (result == null || result.files.isEmpty || !mounted) return;
    final f = result.files.single;
    if (f.bytes == null || f.size > 10 * 1024 * 1024) {
      _snack('Choose a file of 10 MB or less.', error: true);
      return;
    }
    setState(() => _file = f);
  }

  void _clear() {
    setState(() {
      _title.clear();
      _message.clear();
      _audience = AdminAnnouncementAudience.all;
      _file = null;
      _formError = null;
    });
  }

  Future<void> _publish() async {
    final title = _title.text.trim();
    final message = _message.text.trim();
    if (title.isEmpty || message.isEmpty) {
      setState(() => _formError = title.isEmpty ? 'Enter a title.' : 'Type your announcement.');
      return;
    }
    setState(() {
      _posting = true;
      _formError = null;
    });
    try {
      await _service.createAnnouncement(
        title: title,
        content: message,
        targetAudience: _audience,
        attachmentBytes: _file?.bytes,
        attachmentFileName: _file?.name,
        attachmentContentType: _file == null ? null : _contentType(_file!.name),
      );
      if (!mounted) return;
      _snack('Announcement published to ${_audienceLabel(_audience)}.');
      _clear();
      await _load();
    } catch (e) {
      if (mounted) setState(() => _formError = e is ApiException ? e.message : 'Could not publish the announcement.');
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  Future<void> _delete(AdminAnnouncement a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete announcement?'),
        content: Text('"${a.title}" will be removed for everyone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFC62828)),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _service.deleteAnnouncement(a.id);
      await _load();
    } catch (e) {
      _snack(e is ApiException ? e.message : 'Could not delete it.', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height - 130;
    return DeskPage(
      title: 'Announcements',
      onRefresh: _load,
      children: [
        SizedBox(
          height: height < 600 ? 600 : height,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: 11, child: _feed()),
              const SizedBox(width: 16),
              Expanded(flex: 8, child: _form()),
            ],
          ),
        ),
      ],
    );
  }

  Widget _feed() {
    final items = _visible;
    final pages = (items.length / _pageSize).ceil().clamp(1, 1 << 20);
    final page = _page.clamp(0, pages - 1);
    final shown = items.skip(page * _pageSize).take(_pageSize).toList();
    return DeskCard(
      title: 'Announcement Feed',
      child: Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
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
                        hintText: 'Search Announcements...',
                        hintStyle: const TextStyle(fontSize: 12, color: DeskColors.muted),
                        prefixIcon: const Icon(Icons.search, size: 18, color: DeskColors.maroon),
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
                PopupMenuButton<int>(
                  tooltip: 'Filter by audience',
                  position: PopupMenuPosition.under,
                  onSelected: (v) => setState(() {
                    _filter = v < 0 ? null : AdminAnnouncementAudience.values[v];
                    _page = 0;
                  }),
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: -1, child: Text('Everyone')),
                    for (final a in AdminAnnouncementAudience.values)
                      PopupMenuItem(value: a.index, child: Text(_audienceLabel(a))),
                  ],
                  child: Container(
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: _filter == null ? Colors.white : const Color(0xFFFBEFF0),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _filter == null ? const Color(0xFFD6D6D6) : DeskColors.maroon),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.filter_alt_outlined, size: 18, color: DeskColors.maroon),
                        const SizedBox(width: 4),
                        Text(_filter == null ? 'Filter' : _audienceLabel(_filter!), style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: DeskColors.maroon))
                  : shown.isEmpty
                      ? const Center(
                          child: Text('No announcements yet.', style: TextStyle(fontSize: 12.5, color: DeskColors.muted)),
                        )
                      : ListView.separated(
                          itemCount: shown.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 10),
                          itemBuilder: (context, i) => _tile(shown[i]),
                        ),
            ),
            const Divider(height: 18),
            DeskPager(
              page: page,
              pageSize: _pageSize,
              total: items.length,
              noun: 'Announcements',
              onChanged: (p) => setState(() => _page = p),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tile(AdminAnnouncement a) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 6, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFDDDDDD)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CircleAvatar(
            radius: 22,
            backgroundColor: Color(0xFF6E1423),
            child: Icon(Icons.campaign_outlined, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(a.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text(
                  a.content,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF555555)),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined, size: 13, color: Color(0xFF555555)),
                    const SizedBox(width: 5),
                    Text(
                      formatPh(a.createdAt, 'MMM d, yyyy - hh:mm a'),
                      style: const TextStyle(fontSize: 11, color: Color(0xFF555555)),
                    ),
                    const SizedBox(width: 10),
                    DeskStatusChip(label: _audienceLabel(a.targetAudience), tone: DeskChipTone.blue),
                    if (a.attachmentUrl != null) ...[
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: () => openAttachment(ApiClient.resolveUrl(a.attachmentUrl!)),
                        child: Row(
                          children: [
                            const Icon(Icons.attach_file, size: 13, color: DeskColors.maroon),
                            Text(
                              a.attachmentName ?? 'Attachment',
                              style: const TextStyle(fontSize: 10.5, color: DeskColors.maroon, decoration: TextDecoration.underline),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Delete',
            visualDensity: VisualDensity.compact,
            onPressed: () => _delete(a),
            icon: const Icon(Icons.delete_outline, size: 18, color: DeskColors.maroon),
          ),
        ],
      ),
    );
  }

  Widget _form() {
    const label = TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF555555));
    InputDecoration deco(String hint) => InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(fontSize: 12, color: DeskColors.muted),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFDDDDDD)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: DeskColors.maroon),
          ),
        );
    Widget audience(AdminAnnouncementAudience a, IconData icon) {
      final selected = _audience == a;
      return Expanded(
        child: Material(
          color: selected ? const Color(0xFF6E1423) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: selected ? const Color(0xFF6E1423) : const Color(0xFFDDDDDD)),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => setState(() => _audience = a),
            child: SizedBox(
              height: 40,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(selected ? Icons.check_circle : icon, size: 17, color: selected ? Colors.white : DeskColors.maroon),
                  const SizedBox(width: 6),
                  Text(
                    _audienceLabel(a),
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: selected ? Colors.white : const Color(0xFF333333),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return DeskCard(
      title: 'Create Announcement',
      child: Expanded(
        child: ListView(
          children: [
            const Text('Target Audience', style: label),
            const SizedBox(height: 6),
            Row(
              children: [
                audience(AdminAnnouncementAudience.all, Icons.public),
                const SizedBox(width: 6),
                audience(AdminAnnouncementAudience.instructors, Icons.groups),
                const SizedBox(width: 6),
                audience(AdminAnnouncementAudience.students, Icons.groups_outlined),
              ],
            ),
            const SizedBox(height: 12),
            const Text('Title', style: label),
            const SizedBox(height: 6),
            TextField(controller: _title, style: const TextStyle(fontSize: 13), decoration: deco('Enter announcement title...')),
            const SizedBox(height: 12),
            const Text('Message', style: label),
            const SizedBox(height: 6),
            TextField(
              controller: _message,
              minLines: 7,
              maxLines: 12,
              style: const TextStyle(fontSize: 13),
              decoration: deco('Type your announcement here...'),
            ),
            const SizedBox(height: 12),
            const Text('Attachment (Optional)', style: label),
            const SizedBox(height: 6),
            InkWell(
              onTap: _pickFile,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFDDDDDD)),
                ),
                child: _file != null
                    ? Row(
                        children: [
                          const Icon(Icons.insert_drive_file_outlined, color: DeskColors.maroon),
                          const SizedBox(width: 8),
                          Expanded(child: Text(_file!.name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5))),
                          IconButton(
                            tooltip: 'Remove',
                            onPressed: () => setState(() => _file = null),
                            icon: const Icon(Icons.close, size: 18),
                          ),
                        ],
                      )
                    : const Column(
                        children: [
                          Icon(Icons.file_upload_outlined, color: DeskColors.maroon),
                          SizedBox(height: 6),
                          Text(
                            'Click to Upload',
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: DeskColors.maroon),
                          ),
                          SizedBox(height: 2),
                          Text('PDF, DOCX, JPG, PNG (Max. 10MB)', style: TextStyle(fontSize: 11, color: DeskColors.muted)),
                        ],
                      ),
              ),
            ),
            if (_formError != null) ...[
              const SizedBox(height: 10),
              Text(_formError!, style: const TextStyle(fontSize: 12, color: Color(0xFFC62828))),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 44,
                    child: OutlinedButton(
                      onPressed: _posting ? null : _clear,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: DeskColors.maroon,
                        side: const BorderSide(color: Color(0xFFDDDDDD)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Clear All'),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 5,
                  child: SizedBox(
                    height: 44,
                    child: ElevatedButton.icon(
                      onPressed: _posting ? null : _publish,
                      icon: _posting
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.send_outlined, size: 18),
                      label: const Text('Publish Announcement'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6E1423),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
