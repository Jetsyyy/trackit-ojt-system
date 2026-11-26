import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/api_client.dart';
import '../common/desk_ui.dart';

/// A student's Forgot Password request (System Revision 4).
class PasswordResetRequest {
  final int id;
  final int studentId;
  final String name;
  final String? studentNumber;
  final int classId;
  final String section;
  final DateTime requestedAt;

  const PasswordResetRequest({
    required this.id,
    required this.studentId,
    required this.name,
    this.studentNumber,
    required this.classId,
    required this.section,
    required this.requestedAt,
  });

  factory PasswordResetRequest.fromJson(Map<String, dynamic> json) => PasswordResetRequest(
        id: (json['id'] as num).toInt(),
        studentId: (json['studentId'] as num).toInt(),
        name: json['name'] as String,
        studentNumber: json['studentNumber'] as String?,
        classId: (json['classId'] as num).toInt(),
        section: json['section'] as String? ?? '',
        requestedAt: DateTime.parse(json['requestedAt'] as String).toLocal(),
      );
}

/// "Password Reset Requests" on the instructor's Students page: Reset gives
/// a one-time temporary password to hand to the student; Dismiss closes
/// the request. Hidden when there are none.
class PasswordResetRequestsCard extends StatelessWidget {
  final List<PasswordResetRequest> requests;

  /// Returns the temporary password.
  final Future<String> Function(PasswordResetRequest request) onReset;
  final Future<void> Function(PasswordResetRequest request) onDismiss;
  final bool compact;

  const PasswordResetRequestsCard({
    super.key,
    required this.requests,
    required this.onReset,
    required this.onDismiss,
    this.compact = false,
  });

  Future<void> _reset(BuildContext context, PasswordResetRequest r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Reset ${r.name}\'s password?'),
        content: const Text(
          'TrackIT will create a temporary password for you to give the student in person or by message. '
          'Their old password stops working, and they must choose a new one when they sign in.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: DeskColors.maroon),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset password'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      final temp = await onReset(r);
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.key, color: DeskColors.maroon, size: 30),
          title: const Text('Temporary password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Give this to ${r.name}. It is shown only once.'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFBE4E5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: DeskColors.maroon.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: SelectableText(
                        temp,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: 1, fontFamily: 'monospace'),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Copy',
                      icon: const Icon(Icons.copy, size: 18),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: temp));
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Temporary password copied.')));
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'The student signs in with it and must set their own password right away.',
                style: TextStyle(fontSize: 12, color: DeskColors.muted),
              ),
            ],
          ),
          actions: [
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: DeskColors.maroon),
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e is ApiException ? e.message : 'Could not reset the password.')),
        );
      }
    }
  }

  Future<void> _dismiss(BuildContext context, PasswordResetRequest r) async {
    try {
      await onDismiss(r);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e is ApiException ? e.message : 'Could not dismiss the request.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (requests.isEmpty) return const SizedBox.shrink();
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(compact ? 14 : 10),
        border: Border.all(color: const Color(0xFFE8843A).withValues(alpha: 0.7)),
        boxShadow: compact ? const [BoxShadow(color: Color(0x22000000), blurRadius: 6, offset: Offset(0, 3))] : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: const Color(0xFFFDEBDD),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                const Icon(Icons.lock_reset, size: 18, color: Color(0xFFB85A1A)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Password Reset Requests',
                    style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: Color(0xFF8A4310)),
                  ),
                ),
                DeskCountBadge(count: requests.length),
              ],
            ),
          ),
          for (var i = 0; i < requests.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: DeskColors.tileBorder),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  DeskAvatar(name: requests[i].name, radius: 16),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          requests[i].name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '${requests[i].section} • forgot password ${timeAgo(requests[i].requestedAt)}',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 10.5, color: DeskColors.muted),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => _dismiss(context, requests[i]),
                    style: TextButton.styleFrom(foregroundColor: DeskColors.muted, visualDensity: VisualDensity.compact),
                    child: const Text('Dismiss', style: TextStyle(fontSize: 11.5)),
                  ),
                  const SizedBox(width: 4),
                  FilledButton(
                    onPressed: () => _reset(context, requests[i]),
                    style: FilledButton.styleFrom(
                      backgroundColor: DeskColors.maroon,
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    child: const Text('Reset', style: TextStyle(fontSize: 11.5)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
