import 'package:flutter/material.dart';
import '../../../models/ojt_requirement_doc.dart';
import '../../../utils/ph_time.dart';
import '../student_ui.dart';

/// One requirement document (TrackIT student mockup "Document State"):
/// icon, name and description; the uploaded file and when; the actions
/// (Download Template / Upload / Re-Upload / View); and a colored bar at
/// the bottom with the review result.
class RequirementDocTile extends StatelessWidget {
  final OjtRequirementDoc document;
  final VoidCallback onUpload;
  final VoidCallback onView;
  final VoidCallback? onDownloadTemplate;

  const RequirementDocTile({
    super.key,
    required this.document,
    required this.onUpload,
    required this.onView,
    this.onDownloadTemplate,
  });

  @override
  Widget build(BuildContext context) {
    final d = document;
    final hasFile = d.uploadedFileName != null &&
        (d.status == RequirementDocStatus.submitted ||
            d.status == RequirementDocStatus.approved ||
            d.status == RequirementDocStatus.rejected);
    final (barText, barColor) = switch (d.status) {
      RequirementDocStatus.approved => ('Document Approved', StudentColors.approved),
      RequirementDocStatus.rejected => ('Re-Upload File  |  Declined', StudentColors.declined),
      RequirementDocStatus.submitted || RequirementDocStatus.pending => ('Pending for Verification', StudentColors.pending),
      RequirementDocStatus.missing => (null, null),
    };
    final canUpload = d.uploadRequired &&
        (d.status == RequirementDocStatus.missing || d.status == RequirementDocStatus.rejected);
    final officeIssued = d.issuedBy != null && d.issuedBy!.trim().isNotEmpty;

    final buttons = <Widget>[
      // A declined document shows only Re-Upload and View (mockup).
      if (onDownloadTemplate != null && d.status != RequirementDocStatus.rejected)
        _ActionButton(icon: Icons.download, label: 'Download Template', onTap: onDownloadTemplate),
      if (canUpload)
        _ActionButton(
          icon: Icons.upload,
          label: d.status == RequirementDocStatus.rejected ? 'Re-Upload' : 'Upload',
          onTap: onUpload,
          danger: d.status == RequirementDocStatus.rejected,
        ),
      if (hasFile) _ActionButton(icon: Icons.visibility_outlined, label: 'View', onTap: onView, view: true),
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Color(0x33000000), blurRadius: 5, offset: Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFF555555)),
                        ),
                        child: const Icon(Icons.description, size: 22, color: Color(0xFF1F1F1F)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(d.name, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w500)),
                            Text(
                              officeIssued ? '${d.description.isEmpty ? '' : '${d.description} · '}From the ${d.issuedBy}' : d.description,
                              style: const TextStyle(fontSize: 11, color: StudentColors.muted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (hasFile)
                    Row(
                      children: [
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(border: Border.all(color: const Color(0xFF9A9A9A))),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.image_outlined, size: 12, color: Color(0xFF555555)),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    d.uploadedFileName!,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 9.5, color: Color(0xFF333333)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (d.submittedAt != null) ...[
                          Text(
                            formatPh(d.submittedAt!, 'MMMM d, yyyy - hh:mm a'),
                            style: const TextStyle(fontSize: 9, color: Color(0xFF555555)),
                          ),
                          const SizedBox(width: 3),
                          const Icon(Icons.access_time, size: 11, color: Color(0xFF555555)),
                        ],
                      ],
                    ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Divider(height: 1, color: Color(0xFF3A3A3A)),
                  ),
                  if (d.status == RequirementDocStatus.rejected && d.remarks != null && d.remarks!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        'Instructor note: ${d.remarks}',
                        style: const TextStyle(fontSize: 11, color: StudentColors.declined, fontWeight: FontWeight.w600),
                      ),
                    ),
                  if (buttons.isEmpty)
                    Text(
                      officeIssued
                          ? 'Get this document from the ${d.issuedBy}, then upload it here.'
                          : !d.uploadRequired
                              ? 'The template will be available here to download.'
                              : 'No file needed yet.',
                      style: const TextStyle(fontSize: 11, color: StudentColors.muted),
                    )
                  else
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var i = 0; i < buttons.length; i++) ...[
                          if (i > 0)
                            Container(
                              width: 2,
                              height: 26,
                              margin: const EdgeInsets.symmetric(horizontal: 10),
                              color: const Color(0xFF1F1F1F),
                            ),
                          // Shrink to fit rather than cutting labels off.
                          Flexible(child: FittedBox(fit: BoxFit.scaleDown, child: buttons[i])),
                        ],
                      ],
                    ),
                ],
              ),
            ),
            if (barText != null)
              Container(
                color: barColor,
                padding: const EdgeInsets.symmetric(vertical: 6),
                alignment: Alignment.center,
                child: Text(
                  barText,
                  style: const TextStyle(color: Colors.white, fontSize: 11.5, fontStyle: FontStyle.italic, fontWeight: FontWeight.w500),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool view;
  final bool danger;

  const _ActionButton({required this.icon, required this.label, required this.onTap, this.view = false, this.danger = false});

  @override
  Widget build(BuildContext context) {
    final fg = view
        ? const Color(0xFF6B9BD1)
        : danger
            ? StudentColors.declined
            : const Color(0xFF1F1F1F);
    final bg = view ? const Color(0xFFE3ECF7) : (danger ? const Color(0xFFF6E3E4) : Colors.white);
    return SizedBox(
      height: 28,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 14),
        label: Text(label, style: const TextStyle(fontSize: 11)),
        style: OutlinedButton.styleFrom(
          foregroundColor: fg,
          backgroundColor: bg,
          side: BorderSide(color: view ? const Color(0xFF9DBBE0) : (danger ? StudentColors.declined : const Color(0xFF555555))),
          padding: EdgeInsets.symmetric(horizontal: view ? 20 : 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
        ),
      ),
    );
  }
}
