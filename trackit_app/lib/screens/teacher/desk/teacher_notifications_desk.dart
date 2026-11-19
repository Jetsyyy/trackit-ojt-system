import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../models/announcement.dart';
import '../../../models/instructor_class.dart';
import '../../../services/api_client.dart';
import '../../../services/teacher_announcements_service.dart';
import '../../../services/teacher_classes_service.dart';
import '../../../services/teacher_notifications_service.dart';
import '../../../utils/ph_time.dart';
import '../../../widgets/common/desk_ui.dart';

/// Desktop Notification page (instructor mockup): Notifications /
/// Announcement tabs with the feed on the left and the Create
/// Announcement panel on the right.
class TeacherNotificationsDesk extends StatefulWidget {
  final TeacherNotificationsService notificationsService;
  final TeacherAnnouncementsService announcementsService;
  final TeacherClassesService classesService;

  const TeacherNotificationsDesk({
    super.key,
    required this.notificationsService,
    required this.announcementsService,
    required this.classesService,
  });

  @override
  State<TeacherNotificationsDesk> createState() => _TeacherNotificationsDeskState();
}

class _TeacherNotificationsDeskState extends State<TeacherNotificationsDesk> {
  int _tab = 1;
  String _query = '';
  int? _sectionFilter;
  List<Announcement> _announcements = [];
  List<InstructorClass> _classes = [];
  bool _loading = true;

  // Create / edit form
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  final Set<int> _targets = {};
  Announcement? _editing;
  Uint8List? _imageBytes;
  String? _imageName;
  String? _imageType;
  bool _removeImage = false;
  bool _posting = false;
  String? _formError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        widget.announcementsService.getAnnouncements(),
        widget.classesService.getClasses(),
      ]);
      if (!mounted) return;
      setState(() {
        _announcements = results[0] as List<Announcement>;
        _classes = results[1] as List<InstructorClass>;
        _loading = false;
        if (_targets.isEmpty && _classes.length == 1) _targets.add(_classes.first.id);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _snack(e is ApiException ? e.message : 'Could not load announcements.', error: true);
    }
  }

  void _snack(String text, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), backgroundColor: error ? const Color(0xFFC62828) : null),
    );
  }

  List<Announcement> get _visibleAnnouncements {
    final q = _query.trim().toLowerCase();
    return _announcements.where((a) {
      if (_sectionFilter != null && !a.targets.any((t) => t.classId == _sectionFilter)) return false;
      if (q.isEmpty) return true;
      return a.title.toLowerCase().contains(q) || a.content.toLowerCase().contains(q);
    }).toList();
  }

  void _clearForm() {
    setState(() {
      _editing = null;
      _titleController.clear();
      _messageController.clear();
      _targets
        ..clear()
        ..addAll(_classes.length == 1 ? [_classes.first.id] : const []);
      _imageBytes = null;
      _imageName = null;
      _imageType = null;
      _removeImage = false;
      _formError = null;
    });
  }

  void _startEdit(Announcement a) {
    setState(() {
      _editing = a;
      _titleController.text = a.title;
      _messageController.text = a.content;
      _targets
        ..clear()
        ..addAll(a.targets.map((t) => t.classId));
      _imageBytes = null;
      _imageName = null;
      _imageType = null;
      _removeImage = false;
      _formError = null;
    });
  }

  Future<void> _pickImage() async {
    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 85);
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (bytes.length > 10 * 1024 * 1024) {
        _snack('That image is larger than 10 MB.', error: true);
        return;
      }
      final name = picked.name;
      final lower = name.toLowerCase();
      setState(() {
        _imageBytes = bytes;
        _imageName = name;
        _imageType = picked.mimeType ??
            (lower.endsWith('.png')
                ? 'image/png'
                : lower.endsWith('.webp')
                    ? 'image/webp'
                    : 'image/jpeg');
        _removeImage = false;
      });
    } catch (_) {
      _snack('Could not open that image.', error: true);
    }
  }

  Future<void> _post() async {
    final title = _titleController.text.trim();
    final message = _messageController.text.trim();
    if (_targets.isEmpty || title.isEmpty || message.isEmpty) {
      setState(() => _formError = _targets.isEmpty
          ? 'Choose at least one section.'
          : title.isEmpty
              ? 'Enter a title.'
              : 'Type your announcement.');
      return;
    }
    setState(() {
      _posting = true;
      _formError = null;
    });
    try {
      if (_editing == null) {
        await widget.announcementsService.createAnnouncement(
          title: title,
          content: message,
          classIds: _targets.toList(),
          imageBytes: _imageBytes,
          imageFileName: _imageName,
          imageContentType: _imageType,
        );
      } else {
        await widget.announcementsService.updateAnnouncement(
          id: _editing!.id,
          title: title,
          content: message,
          classIds: _targets.toList(),
          imageBytes: _imageBytes,
          imageFileName: _imageName,
          imageContentType: _imageType,
          removeImage: _removeImage,
        );
      }
      if (!mounted) return;
      _snack(_editing == null ? 'Announcement posted.' : 'Announcement updated.');
      _clearForm();
      await _load();
    } catch (e) {
      if (mounted) setState(() => _formError = e is ApiException ? e.message : 'Could not post the announcement.');
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  Future<void> _delete(Announcement a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete announcement?'),
        content: Text('"${a.title}" will be removed for every student in its sections.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFC62828)),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await widget.announcementsService.deleteAnnouncement(a.id);
      if (_editing?.id == a.id) _clearForm();
      await _load();
      if (mounted) _snack('Announcement deleted.');
    } catch (e) {
      if (mounted) _snack(e is ApiException ? e.message : 'Could not delete it.', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height - 150;
    return DeskPage(
      title: 'Notification',
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: 340,
            child: DeskSegmentedTabs(
              labels: const ['Notifications', 'Announcement'],
              selectedIndex: _tab,
              onChanged: (i) => setState(() => _tab = i),
              height: 42,
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: height < 540 ? 540 : height,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: 11, child: _tab == 0 ? _notificationsCard() : _feedCard()),
              const SizedBox(width: 18),
              Expanded(flex: 9, child: _createCard()),
            ],
          ),
        ),
      ],
    );
  }

  Widget _searchRow({required String hint, Widget? trailing}) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 36,
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              style: const TextStyle(fontSize: 12.5),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(fontSize: 12.5, color: DeskColors.muted),
                prefixIcon: const Icon(Icons.search, size: 18, color: DeskColors.muted),
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
        if (trailing != null) ...[const SizedBox(width: 8), trailing],
      ],
    );
  }

  Widget _feedCard() {
    final items = _visibleAnnouncements;
    return DeskCard(
      title: 'Announcement Feed',
      child: Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _searchRow(
              hint: 'Search announcements',
              trailing: PopupMenuButton<int?>(
                tooltip: 'Filter by section',
                position: PopupMenuPosition.under,
                onSelected: (v) => setState(() => _sectionFilter = v == -1 ? null : v),
                itemBuilder: (context) => [
                  const PopupMenuItem(value: -1, child: Text('All sections')),
                  for (final c in _classes) PopupMenuItem(value: c.id, child: Text('${c.program} - ${c.section}')),
                ],
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFD6D6D6)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _sectionFilter == null ? Icons.filter_alt_outlined : Icons.filter_alt,
                        size: 18,
                        color: DeskColors.maroon,
                      ),
                      const SizedBox(width: 4),
                      const Text('Filter', style: TextStyle(fontSize: 12.5)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: DeskColors.maroon))
                  : items.isEmpty
                      ? const Center(
                          child: Text(
                            'No announcements yet. Post one using the form on the right.',
                            style: TextStyle(fontSize: 12.5, color: DeskColors.muted),
                          ),
                        )
                      : ListView.separated(
                          itemCount: items.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 10),
                          itemBuilder: (context, i) => _AnnouncementTile(
                            announcement: items[i],
                            editing: _editing?.id == items[i].id,
                            onEdit: () => _startEdit(items[i]),
                            onDelete: () => _delete(items[i]),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _notificationsCard() {
    return DeskCard(
      title: 'Notifications',
      trailing: TextButton(
        onPressed: () async {
          for (final n in widget.notificationsService.notifications.where((n) => !n.isRead).toList()) {
            await widget.notificationsService.markAsRead(n.id);
          }
        },
        style: TextButton.styleFrom(foregroundColor: DeskColors.maroon),
        child: const Text('Mark all as read', style: TextStyle(fontSize: 12)),
      ),
      child: Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _searchRow(hint: 'Search Notifications'),
            const SizedBox(height: 12),
            Expanded(
              child: ListenableBuilder(
                listenable: widget.notificationsService,
                builder: (context, _) {
                  final q = _query.trim().toLowerCase();
                  final items = widget.notificationsService.notifications
                      .where((n) =>
                          q.isEmpty || n.title.toLowerCase().contains(q) || n.message.toLowerCase().contains(q))
                      .toList();
                  if (items.isEmpty) {
                    return const Center(
                      child: Text('No notifications.', style: TextStyle(fontSize: 12.5, color: DeskColors.muted)),
                    );
                  }
                  return ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final n = items[i];
                      return DeskTile(
                        onTap: n.isRead ? null : () => widget.notificationsService.markAsRead(n.id),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const DeskIconBox(icon: Icons.notifications_none, size: 30),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    n.title,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: n.isRead ? FontWeight.w500 : FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(n.message, style: const TextStyle(fontSize: 12, color: Color(0xFF555555))),
                                  const SizedBox(height: 4),
                                  Text(timeAgo(n.createdAt), style: const TextStyle(fontSize: 11, color: DeskColors.muted)),
                                ],
                              ),
                            ),
                            if (!n.isRead)
                              Container(
                                width: 8,
                                height: 8,
                                margin: const EdgeInsets.only(top: 4),
                                decoration: const BoxDecoration(color: Color(0xFFFF7A1A), shape: BoxShape.circle),
                              ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _createCard() {
    final editing = _editing != null;
    final hasExistingImage = editing && _editing!.imageUrl != null && !_removeImage && _imageBytes == null;
    InputDecoration field(String hint) => InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(fontSize: 12.5, color: DeskColors.muted),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFD6D6D6)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: DeskColors.maroon),
          ),
        );
    const label = TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF555555));
    return DeskCard(
      title: editing ? 'Edit Announcement' : 'Create Announcement',
      child: Expanded(
        child: ListView(
          children: [
            const Text('Sections', style: label),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in _classes)
                  _SectionChoice(
                    label: '${c.program} - ${c.section}',
                    selected: _targets.contains(c.id),
                    onTap: () => setState(() {
                      if (!_targets.remove(c.id)) _targets.add(c.id);
                    }),
                  ),
                if (_classes.isEmpty)
                  const Text('No sections assigned yet.', style: TextStyle(fontSize: 12, color: DeskColors.muted)),
              ],
            ),
            const SizedBox(height: 12),
            const Text('Title', style: label),
            const SizedBox(height: 6),
            TextField(
              controller: _titleController,
              style: const TextStyle(fontSize: 13),
              decoration: field('Enter announcement title...'),
            ),
            const SizedBox(height: 12),
            const Text('Message', style: label),
            const SizedBox(height: 6),
            TextField(
              controller: _messageController,
              minLines: 6,
              maxLines: 10,
              style: const TextStyle(fontSize: 13),
              decoration: field('Type your announcement here...'),
            ),
            const SizedBox(height: 12),
            const Text('Attachment (Optional)', style: label),
            const SizedBox(height: 6),
            InkWell(
              onTap: _pickImage,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFD6D6D6)),
                ),
                child: _imageBytes != null
                    ? Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Image.memory(_imageBytes!, width: 48, height: 48, fit: BoxFit.cover),
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: Text(_imageName ?? 'Image', overflow: TextOverflow.ellipsis)),
                          IconButton(
                            tooltip: 'Remove',
                            onPressed: () => setState(() {
                              _imageBytes = null;
                              _imageName = null;
                            }),
                            icon: const Icon(Icons.close, size: 18),
                          ),
                        ],
                      )
                    : hasExistingImage
                        ? Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: Image.network(
                                  ApiClient.resolveUrl(_editing!.imageUrl!),
                                  width: 48,
                                  height: 48,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Expanded(child: Text('Current image — click to replace')),
                              IconButton(
                                tooltip: 'Remove image',
                                onPressed: () => setState(() => _removeImage = true),
                                icon: const Icon(Icons.close, size: 18),
                              ),
                            ],
                          )
                        : const Column(
                            children: [
                              Icon(Icons.file_upload_outlined, color: DeskColors.maroon),
                              SizedBox(height: 6),
                              Text(
                                'Click to Upload an image',
                                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: DeskColors.maroon),
                              ),
                              SizedBox(height: 2),
                              Text('JPG, PNG (Max. 10MB)', style: TextStyle(fontSize: 11, color: DeskColors.muted)),
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
                    height: 42,
                    child: OutlinedButton(
                      onPressed: _posting ? null : _clearForm,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF333333),
                        side: const BorderSide(color: Color(0xFFD6D6D6)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text(editing ? 'Cancel' : 'Clear All'),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 5,
                  child: SizedBox(
                    height: 42,
                    child: ElevatedButton.icon(
                      onPressed: _posting ? null : _post,
                      icon: _posting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.send_outlined, size: 18),
                      label: Text(editing ? 'Save Changes' : 'Post Announcement'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: DeskColors.maroon,
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

class _SectionChoice extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SectionChoice({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? DeskColors.maroon : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: DeskColors.maroon),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                selected ? Icons.check_circle : Icons.check_circle_outline,
                size: 16,
                color: selected ? Colors.white : DeskColors.maroon,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : DeskColors.maroon,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnnouncementTile extends StatelessWidget {
  final Announcement announcement;
  final bool editing;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _AnnouncementTile({
    required this.announcement,
    required this.editing,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final a = announcement;
    return DeskTile(
      selected: editing,
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CircleAvatar(
            radius: 20,
            backgroundColor: DeskColors.maroon,
            child: Icon(Icons.campaign_outlined, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(a.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(a.content, style: const TextStyle(fontSize: 12, color: Color(0xFF444444), height: 1.4)),
                if (a.imageUrl != null) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.network(
                      ApiClient.resolveUrl(a.imageUrl!),
                      height: 120,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stack) => const SizedBox.shrink(),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final t in a.targets)
                      DeskStatusChip(label: '${t.program} - ${t.section}', tone: DeskChipTone.blue),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${formatPh(a.createdAt, 'MMMM d, yyyy')}   •   ${formatPh(a.createdAt, 'hh:mm a')}',
                  style: const TextStyle(fontSize: 11, color: DeskColors.muted),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Edit',
            visualDensity: VisualDensity.compact,
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined, size: 18, color: DeskColors.maroon),
          ),
          IconButton(
            tooltip: 'Delete',
            visualDensity: VisualDensity.compact,
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline, size: 18, color: DeskColors.maroon),
          ),
        ],
      ),
    );
  }
}
