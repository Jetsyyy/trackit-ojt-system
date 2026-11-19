import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/student_registration_request.dart';
import '../../services/api_client.dart';
import '../../services/teacher_students_service.dart';
import '../../utils/app_colors.dart';
import '../../widgets/common/back_nav_header.dart';
import '../../widgets/common/empty_state_view.dart';
import '../../widgets/common/skeleton_list_tile.dart';

/// Students who registered with one of this instructor's section codes
/// and can't log in until approved (System Revisions item 11).
class TeacherRegistrationRequestsScreen extends StatefulWidget {
  final TeacherStudentsService service;

  const TeacherRegistrationRequestsScreen({super.key, required this.service});

  @override
  State<TeacherRegistrationRequestsScreen> createState() =>
      _TeacherRegistrationRequestsScreenState();
}

class _TeacherRegistrationRequestsScreenState extends State<TeacherRegistrationRequestsScreen> {
  List<StudentRegistrationRequest> _requests = [];
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
      final requests = await widget.service.getRegistrationRequests();
      if (!mounted) return;
      setState(() {
        _requests = requests;
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

  Future<void> _decide(StudentRegistrationRequest request, {required bool approve, String? reason}) async {
    setState(() => _busyId = request.id);
    try {
      await widget.service.decideRegistration(
        studentId: request.id,
        approve: approve,
        reason: reason,
      );
      if (!mounted) return;
      setState(() {
        _requests.removeWhere((r) => r.id == request.id);
        _busyId = null;
      });
      _snack(approve
          ? '${request.name} approved. They can now log in.'
          : '${request.name}\'s registration was declined.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _busyId = null);
      _snack(e is ApiException ? e.message : 'Could not save. Please try again.', error: true);
      await _load();
    }
  }

  Future<void> _confirmApprove(StudentRegistrationRequest request) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Approve ${request.name}?'),
        content: Text(
          'They will join ${request.program} - ${request.section} as your student '
          'and can log in right away. Only approve students you recognize.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.successGreenText,
              foregroundColor: Colors.white,
            ),
            child: const Text('Approve'),
          ),
        ],
      ),
    );
    if (ok == true) await _decide(request, approve: true);
  }

  Future<void> _askDecline(StudentRegistrationRequest request) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => DeclineRegistrationDialog(name: request.name),
    );
    if (reason != null) await _decide(request, approve: false, reason: reason);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      bottom: false,
      child: Column(
        children: [
          const BackNavHeader(subtitle: 'Registration Requests'),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const SkeletonList();
    if (_error != null) {
      return ListView(
        children: [
          EmptyStateView(icon: Icons.cloud_off, title: 'Could not load requests', message: '$_error'),
          Center(child: OutlinedButton(onPressed: _load, child: const Text('Retry'))),
        ],
      );
    }
    return RefreshIndicator(
      color: AppColors.primaryMaroon,
      onRefresh: _load,
      child: _requests.isEmpty
          ? ListView(
              children: const [
                EmptyStateView(
                  icon: Icons.how_to_reg_outlined,
                  title: 'No pending requests',
                  message: 'Students who register with your section code will appear '
                      'here for approval.',
                ),
              ],
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              itemCount: _requests.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final request = _requests[index];
                return _RequestCard(
                  request: request,
                  busy: _busyId == request.id,
                  onApprove: _busyId == null ? () => _confirmApprove(request) : null,
                  onDecline: _busyId == null ? () => _askDecline(request) : null,
                );
              },
            ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final StudentRegistrationRequest request;
  final bool busy;
  final VoidCallback? onApprove;
  final VoidCallback? onDecline;

  const _RequestCard({
    required this.request,
    required this.busy,
    required this.onApprove,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    Widget line(IconData icon, String text) => Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              Icon(icon, size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(text, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ),
            ],
          ),
        );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.cardWhite, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            request.name,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
          ),
          line(Icons.email_outlined, request.email),
          if ((request.studentNumber ?? '').isNotEmpty) line(Icons.badge_outlined, request.studentNumber!),
          line(Icons.groups_outlined, '${request.program} - ${request.section}'),
          line(
            Icons.schedule,
            'Requested ${DateFormat('MMM d, yyyy h:mm a').format(request.requestedAt)}',
          ),
          const SizedBox(height: 12),
          if (busy)
            const Center(
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onDecline,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.statRedIcon,
                      side: const BorderSide(color: AppColors.statRedIcon),
                    ),
                    child: const Text('Decline'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onApprove,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.successGreenText,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Approve'),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class DeclineRegistrationDialog extends StatefulWidget {
  final String name;

  const DeclineRegistrationDialog({super.key, required this.name});

  @override
  State<DeclineRegistrationDialog> createState() => DeclineRegistrationDialogState();
}

class DeclineRegistrationDialogState extends State<DeclineRegistrationDialog> {
  final _controller = TextEditingController();
  bool _showError = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      setState(() => _showError = true);
      return;
    }
    Navigator.of(context).pop(text);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Decline ${widget.name}?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'They won\'t be able to log in. They can register again after fixing '
            'the issue you describe.',
            style: TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Reason',
              helperText: 'e.g. Not in my section, or wrong student number.',
              helperMaxLines: 2,
              errorText: _showError ? 'A reason is required' : null,
              alignLabelWithHint: true,
              border: const OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.statRedIcon,
            foregroundColor: Colors.white,
          ),
          child: const Text('Decline'),
        ),
      ],
    );
  }
}
