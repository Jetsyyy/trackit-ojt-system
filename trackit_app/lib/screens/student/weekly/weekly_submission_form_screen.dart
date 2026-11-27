import 'dart:typed_data';

import '../../../utils/pick_files.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../models/weekly_submission.dart';
import '../../../services/api_client.dart';
import '../../../services/weekly_submissions_service.dart';
import '../../../utils/app_colors.dart';
import '../../../utils/attachment_launcher.dart';
import '../../../utils/ph_time.dart';
import '../../../widgets/common/back_nav_header.dart';
import '../../../widgets/student/student_ui.dart';
import 'weekly_submissions_screen.dart';

const double _maxClaimedHours = 168;

/// One week's page (TrackIT student mockups "Weekly Submission"):
/// 1 Accumulated Time (hours : minutes from the DTR), 2 DTR upload,
/// 3 AR upload, then Submit. Waiting and approved weeks are read-only and
/// show "Submitted"; a returned week can be resubmitted.
class WeeklySubmissionFormScreen extends StatefulWidget {
  final WeeklySubmissionsService service;
  final WeeklySubmission week;

  const WeeklySubmissionFormScreen({super.key, required this.service, required this.week});

  @override
  State<WeeklySubmissionFormScreen> createState() => _WeeklySubmissionFormScreenState();
}

class _PickedFile {
  final PickedWeeklyFile file;
  final DateTime pickedAt;

  _PickedFile(this.file) : pickedAt = DateTime.now();
}

class _WeeklySubmissionFormScreenState extends State<WeeklySubmissionFormScreen> {
  late WeeklySubmission _week = widget.week;
  final _hours = TextEditingController();
  final _minutes = TextEditingController();
  final List<_PickedFile> _dtr = [];
  final List<_PickedFile> _ar = [];
  bool _saving = false;
  String? _confirmation;

  bool get _editable => _week.canSubmit;

  @override
  void initState() {
    super.initState();
    // A returned week starts from the hours it was submitted with.
    final claimed = _week.claimedHours;
    if (claimed != null && _editable) {
      final total = (claimed * 60).round();
      _hours.text = '${total ~/ 60}';
      _minutes.text = (total % 60).toString().padLeft(2, '0');
    }
    _hours.addListener(_changed);
    _minutes.addListener(_changed);
  }

  void _changed() => setState(() {});

  @override
  void dispose() {
    _hours.dispose();
    _minutes.dispose();
    super.dispose();
  }

  void _snack(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: error ? AppColors.statRedIcon : null),
    );
  }

  /// Claimed hours from the two boxes, rounded to 2 decimals (the server's
  /// limit), or null if not entered / invalid.
  double? get _claimed {
    final h = int.tryParse(_hours.text.trim()) ?? 0;
    final m = int.tryParse(_minutes.text.trim()) ?? 0;
    if (_hours.text.trim().isEmpty && _minutes.text.trim().isEmpty) return null;
    if (m > 59) return null;
    final value = ((h + m / 60) * 100).round() / 100;
    if (value <= 0 || value > _maxClaimedHours) return null;
    return value;
  }

  bool get _ready => _claimed != null && _dtr.isNotEmpty && _ar.isNotEmpty;

  Future<void> _pick(List<_PickedFile> target, String label) async {
    final room = weeklyMaxFilesPerKind - target.length;
    if (room <= 0) {
      _snack('You can attach up to $weeklyMaxFilesPerKind files for the $label.', error: true);
      return;
    }
    final result = await pickFilesWithData(
      type: FileType.custom,
      allowedExtensions: weeklyFileExtensions,
      allowMultiple: true,
    );
    if (result == null || !mounted) return;
    final skipped = <String>[];
    final added = <_PickedFile>[];
    for (final f in result.files) {
      if (f.bytes == null || f.size > weeklyMaxFileBytes || added.length >= room) {
        skipped.add(f.name);
        continue;
      }
      added.add(_PickedFile(PickedWeeklyFile(fileName: f.name, bytes: f.bytes!)));
    }
    setState(() => target.addAll(added));
    if (skipped.isNotEmpty) {
      _snack('Not added: ${skipped.join(', ')}. Each file must be 10 MB or smaller.', error: true);
    }
  }

  Future<void> _submit() async {
    final claimed = _claimed;
    if (claimed == null) {
      _snack('Enter the total time on this week\'s DTR (minutes 0-59, at most 168 hours).', error: true);
      return;
    }
    if (_dtr.isEmpty || _ar.isEmpty) {
      _snack('Upload both this week\'s DTR and Accomplishment Report.', error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      final data = await widget.service.submitWeek(
        weekNumber: _week.weekNumber,
        claimedHours: claimed,
        description: _week.description ?? '',
        dtrFiles: [for (final f in _dtr) f.file],
        arFiles: [for (final f in _ar) f.file],
      );
      if (!mounted) return;
      final updated = data.weeks.where((w) => w.weekNumber == _week.weekNumber).firstOrNull;
      setState(() {
        if (updated != null) _week = updated;
        _dtr.clear();
        _ar.clear();
        _confirmation = 'Week ${_week.weekNumber} submitted. Your instructor will review it.';
      });
      _snack(_confirmation!);
    } on ApiException catch (e) {
      if (mounted) _snack(e.message, error: true);
    } catch (_) {
      if (mounted) _snack('Could not submit. Check your connection and try again.', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _previewLocal(_PickedFile f) {
    final name = f.file.fileName.toLowerCase();
    final isImage = !name.endsWith('.pdf') && !name.endsWith('.heic');
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
              child: Row(
                children: [
                  Expanded(child: Text(f.file.fileName, overflow: TextOverflow.ellipsis)),
                  IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close)),
                ],
              ),
            ),
            Flexible(
              child: isImage
                  ? InteractiveViewer(child: Image.memory(Uint8List.fromList(f.file.bytes), fit: BoxFit.contain))
                  : const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('This PDF is ready to upload. It can be opened after you submit.'),
                    ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Future<void> _openRemote(WeeklyFile f) async {
    if (f.url == null) return;
    final ok = await openAttachment(ApiClient.resolveUrl(f.url!));
    if (!ok && mounted) _snack('Could not open that file.', error: true);
  }

  @override
  Widget build(BuildContext context) {
    final week = _week;
    final readOnlyMinutes = week.claimedHours == null ? null : (week.claimedHours! * 60).round();
    return Column(
      children: [
        BackNavHeader(
          subtitle: 'Weekly Submissions',
          onBack: () => Navigator.of(context).pop(_confirmation),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
            children: [
              WeekRow(
                weekNumber: week.weekNumber,
                start: week.weekStartDate,
                end: week.weekEndDate,
                status: weekStatusChip(week.status),
                onTap: null,
                showChevron: false,
              ),
              const SizedBox(height: 16),
              const Text(
                'This Week Requirements',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: StudentColors.heading),
              ),
              Text(
                'Upload the required images for Week ${week.weekNumber}',
                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500),
              ),
              if (week.status == WeeklySubmissionStatus.rejected && (week.remarks ?? '').isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF6D9DB),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFE2A9AE)),
                  ),
                  child: Text(
                    'Returned by your instructor: ${week.remarks}\nFix it and upload the files again.',
                    style: const TextStyle(fontSize: 11.5, color: StudentColors.declined, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
              const SizedBox(height: 10),
              _StepCard(
                number: 1,
                title: 'Accumulated Time',
                subtitle: 'Total OJT Hours from this week DTR',
                child: Container(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFE7E7),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFFD9CFCF)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_editable)
                        const Text(
                          'Enter Total Time',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: StudentColors.heading),
                        ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _TimeBox(
                            label: 'HOUR',
                            controller: _editable ? _hours : null,
                            value: readOnlyMinutes == null ? null : '${readOnlyMinutes ~/ 60}',
                            maxLength: 3,
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: Text(':', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700)),
                          ),
                          _TimeBox(
                            label: 'MINUTE',
                            controller: _editable ? _minutes : null,
                            value: readOnlyMinutes == null ? null : (readOnlyMinutes % 60).toString().padLeft(2, '0'),
                            maxLength: 2,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              _StepCard(
                number: 2,
                title: 'Daily Time Record (DTR)',
                subtitle: 'Upload an image of this week DTR',
                child: _files(
                  label: 'DTR',
                  picked: _dtr,
                  remote: week.dtrFiles,
                  when: week.submittedAt,
                ),
              ),
              _StepCard(
                number: 3,
                title: 'Accomplishment Report',
                subtitle: 'Upload an image of this week AR',
                child: _files(
                  label: 'AR',
                  picked: _ar,
                  remote: week.arFiles,
                  when: week.submittedAt,
                ),
              ),
              const SizedBox(height: 4),
              if (_editable)
                SizedBox(
                  height: 44,
                  child: ElevatedButton(
                    onPressed: _ready && !_saving ? _submit : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: StudentColors.maroon,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFFB9A0A2),
                      disabledForegroundColor: const Color(0xFF6B5557),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _saving
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(
                            week.status == WeeklySubmissionStatus.rejected
                                ? 'Resubmit Week ${week.weekNumber}'
                                : 'Submit Week ${week.weekNumber}',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                          ),
                  ),
                )
              else
                Container(
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFF9C6B70),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Submitted',
                    style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700, fontStyle: FontStyle.italic),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _files({
    required String label,
    required List<_PickedFile> picked,
    required List<WeeklyFile> remote,
    required DateTime? when,
  }) {
    if (!_editable) {
      if (remote.isEmpty) {
        return const Text('No file.', style: TextStyle(fontSize: 11.5, color: StudentColors.muted));
      }
      return Column(
        children: [
          for (final f in remote)
            _FileTile(
              name: f.fileName,
              detail: when == null ? null : formatPh(when, 'MMM. d, yyyy, h:mm a'),
              thumbnailUrl: _isImage(f.fileName) && f.url != null ? ApiClient.resolveUrl(f.url!) : null,
              onView: () => _openRemote(f),
            ),
        ],
      );
    }
    if (picked.isEmpty) {
      return _UploadArea(label: label, onTap: () => _pick(picked, label));
    }
    return Column(
      children: [
        for (final f in picked)
          _FileTile(
            name: f.file.fileName,
            detail: '${_size(f.file.size)} - ${DateFormat('MMM. d, yyyy, h:mm a').format(f.pickedAt)}',
            thumbnailBytes: _isImage(f.file.fileName) ? Uint8List.fromList(f.file.bytes) : null,
            onView: () => _previewLocal(f),
            onDelete: () => setState(() => picked.remove(f)),
          ),
        if (picked.length < weeklyMaxFilesPerKind)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _pick(picked, label),
              style: TextButton.styleFrom(foregroundColor: StudentColors.maroon),
              icon: const Icon(Icons.add, size: 16),
              label: Text('Add another $label page', style: const TextStyle(fontSize: 11.5)),
            ),
          ),
      ],
    );
  }

  static bool _isImage(String name) {
    final n = name.toLowerCase();
    return n.endsWith('.jpg') || n.endsWith('.jpeg') || n.endsWith('.png') || n.endsWith('.webp');
  }

  static String _size(int bytes) {
    if (bytes >= 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / 1024).ceil()} KB';
  }
}

class _StepCard extends StatelessWidget {
  final int number;
  final String title;
  final String subtitle;
  final Widget child;

  const _StepCard({required this.number, required this.title, required this.subtitle, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFBDBDBD)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              PhaseNumber(number: number, size: 32),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: StudentColors.heading)),
                    Text(subtitle, style: const TextStyle(fontSize: 9.5, color: Color(0xFF1F1F1F))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

/// One flip-clock style digit box: editable (controller) or read-only (value).
class _TimeBox extends StatelessWidget {
  final String label;
  final TextEditingController? controller;
  final String? value;
  final int maxLength;

  const _TimeBox({required this.label, required this.controller, required this.value, required this.maxLength});

  static const _digits = TextStyle(fontSize: 30, fontWeight: FontWeight.w700, color: StudentColors.heading, letterSpacing: 1);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 64,
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(3),
            boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 3, offset: Offset(0, 2))],
          ),
          child: controller == null
              ? Text(value ?? '--', style: _digits)
              : TextField(
                  controller: controller,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(maxLength),
                  ],
                  style: _digits,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: '- -',
                    hintStyle: _digits,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
        ),
        const SizedBox(height: 3),
        Text(label, style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w500, color: StudentColors.heading)),
      ],
    );
  }
}

class _UploadArea extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _UploadArea({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: CustomPaint(
        painter: _DashedBorderPainter(),
        child: Container(
          height: 118,
          color: const Color(0xFFEFE7E7),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.upload_file, size: 34, color: StudentColors.maroon),
              const SizedBox(height: 6),
              Text('Upload $label', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1F1F1F))),
              const SizedBox(height: 2),
              const Text('JPG, PNG or PDF', style: TextStyle(fontSize: 9.5, color: Color(0xFF333333))),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF8C1C2A)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    const dash = 6.0;
    const gap = 4.0;
    void line(Offset a, Offset b) {
      final total = (b - a).distance;
      final dir = (b - a) / total;
      for (double d = 0; d < total; d += dash + gap) {
        canvas.drawLine(a + dir * d, a + dir * (d + dash).clamp(0, total), paint);
      }
    }

    line(Offset.zero, Offset(size.width, 0));
    line(Offset(size.width, 0), Offset(size.width, size.height));
    line(Offset(size.width, size.height), Offset(0, size.height));
    line(Offset(0, size.height), Offset.zero);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _FileTile extends StatelessWidget {
  final String name;
  final String? detail;
  final Uint8List? thumbnailBytes;
  final String? thumbnailUrl;
  final VoidCallback onView;
  final VoidCallback? onDelete;

  const _FileTile({
    required this.name,
    required this.detail,
    required this.onView,
    this.thumbnailBytes,
    this.thumbnailUrl,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    Widget thumb;
    if (thumbnailBytes != null) {
      thumb = Image.memory(thumbnailBytes!, width: 50, height: 34, fit: BoxFit.cover);
    } else if (thumbnailUrl != null) {
      thumb = Image.network(
        thumbnailUrl!,
        width: 50,
        height: 34,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stack) => const Icon(Icons.image_outlined, size: 26),
      );
    } else {
      thumb = const SizedBox(width: 50, height: 34, child: Icon(Icons.picture_as_pdf_outlined, size: 26));
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
      decoration: BoxDecoration(
        color: const Color(0xFFD6E2F0),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFB7C8DD)),
      ),
      child: InkWell(
        onTap: onDelete == null ? onView : null,
        child: Row(
          children: [
            ClipRRect(borderRadius: BorderRadius.circular(2), child: thumb),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                  if (detail != null) Text(detail!, style: const TextStyle(fontSize: 9, color: Color(0xFF333333))),
                ],
              ),
            ),
            if (onDelete != null) ...[
              _SquareIcon(icon: Icons.visibility_outlined, tooltip: 'View', onTap: onView),
              const SizedBox(width: 4),
              _SquareIcon(icon: Icons.delete_outline, tooltip: 'Remove', onTap: onDelete!),
            ],
          ],
        ),
      ),
    );
  }
}

class _SquareIcon extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _SquareIcon({required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: const Color(0xFF9A9A9A)),
          ),
          child: Icon(icon, size: 15, color: const Color(0xFF333333)),
        ),
      ),
    );
  }
}
