import 'package:flutter/material.dart';
import '../../../models/company_details.dart';
import '../../../models/ojt_requirement_phase.dart';
import '../../../models/student_profile.dart';
import '../../../services/ojt_requirements_service.dart';
import '../../../services/student_profile_service.dart';
import '../../../utils/app_colors.dart';
import '../../../widgets/common/back_nav_header.dart';
import '../../../widgets/common/skeleton_list_tile.dart';
import '../../../widgets/student/documents/phase_card.dart';
import '../../../widgets/student/student_ui.dart';
import 'account_finalization_screen.dart';
import 'confirm_company_details_screen.dart';
import 'phase_requirements_screen.dart';

/// OJT Requirements (TrackIT student mockup): overall progress, the
/// reminder, the four phases, and the Account Details Finalization card.
class StartupRequirementsScreen extends StatefulWidget {
  final OjtRequirementsService service;
  final StudentProfileService profileService;

  const StartupRequirementsScreen({
    super.key,
    required this.service,
    required this.profileService,
  });

  @override
  State<StartupRequirementsScreen> createState() => _StartupRequirementsScreenState();
}

class _StartupRequirementsScreenState extends State<StartupRequirementsScreen> {
  List<OjtRequirementPhase> _phases = [];
  StudentProfile? _profile;
  bool _loading = true;

  CompanyDetails? get _companyDetails => _profile?.company;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final phases = await widget.service.getPhases();
    final profile = await widget.profileService.getProfile();
    if (!mounted) return;
    setState(() {
      _phases = phases;
      _profile = profile;
      _loading = false;
    });
  }

  Future<void> _openPhase(OjtRequirementPhase phase) async {
    if (phase.status == PhaseStatus.locked) {
      await _showLockedDialog();
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => StudentBackdrop(
          child: PhaseRequirementsScreen(
            phaseId: phase.id,
            service: widget.service,
            isFinalPhase: phase.order == _phases.map((p) => p.order).fold<int>(0, (a, b) => a > b ? a : b),
          ),
        ),
      ),
    );
    _load();
  }

  Future<void> _showLockedDialog() {
    return showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock, size: 46, color: Color(0xFF1F1F1F)),
              const SizedBox(height: 10),
              const Text('Not Yet Available!', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              const Text(
                'Complete and obtain approval for the required documents in the previous phase to proceed.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Color(0xFF333333)),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(foregroundColor: StudentColors.maroon),
                child: const Text('OK'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openFinalization() async {
    final profile = _profile;
    if (profile == null) return;
    final String? result;
    if (_companyDetails == null) {
      result = await Navigator.of(context).push<String>(
        MaterialPageRoute(
          builder: (context) => AccountFinalizationScreen(
            service: widget.profileService,
            profile: profile,
          ),
        ),
      );
    } else {
      // Already submitted: view it and update the supervisor.
      result = await Navigator.of(context).push<String>(
        MaterialPageRoute(
          builder: (context) => StudentBackdrop(
            child: ConfirmCompanyDetailsScreen(
              service: widget.profileService,
              existingDetails: _companyDetails,
            ),
          ),
        ),
      );
    }
    if (!mounted) return;
    await _load();
    if (result != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result), backgroundColor: AppColors.successGreenText),
      );
    }
  }

  double get _progress {
    if (_phases.isEmpty) return 0;
    return _phases.where((p) => p.status == PhaseStatus.completed).length / _phases.length;
  }

  bool get _allCompleted => _phases.isNotEmpty && _phases.every((p) => p.status == PhaseStatus.completed);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const BackNavHeader(subtitle: 'OJT Requirements'),
        Expanded(
          child: _loading
              ? const SkeletonList()
              : RefreshIndicator(
                  color: AppColors.primaryMaroon,
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
                    children: [
                      _OverallProgressCard(progress: _progress),
                      const SizedBox(height: 10),
                      const _ReminderCard(),
                      const SizedBox(height: 20),
                      const Text('Requirements', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 12),
                      for (final phase in _phases) ...[
                        PhaseCard(phase: phase, onTap: () => _openPhase(phase)),
                        const SizedBox(height: 14),
                      ],
                      const SizedBox(height: 6),
                      const Text('Details Confirmation', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 12),
                      _FinalizationCard(
                        unlocked: _allCompleted,
                        submittedCompany: _companyDetails?.name,
                        onTap: _allCompleted ? _openFinalization : null,
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

class _OverallProgressCard extends StatelessWidget {
  final double progress;

  const _OverallProgressCard({required this.progress});

  @override
  Widget build(BuildContext context) {
    return StudentCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text('Overall Progress', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500)),
                ),
              ),
              Text('${(progress * 100).round()}%', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progress),
              duration: const Duration(milliseconds: 500),
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 12,
                backgroundColor: const Color(0xFFC4C4C4),
                valueColor: const AlwaysStoppedAnimation(StudentColors.maroon),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReminderCard extends StatelessWidget {
  const _ReminderCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFCFCFCF)),
      ),
      child: const Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: StudentColors.maroon,
            child: Icon(Icons.priority_high, color: Colors.white, size: 20),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Reminder', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                SizedBox(height: 2),
                Text(
                  'Complete each phase in order. Some phases will unlock automatically once requirements are met.',
                  style: TextStyle(fontSize: 11, color: Color(0xFF333333)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FinalizationCard extends StatelessWidget {
  final bool unlocked;
  final String? submittedCompany;
  final VoidCallback? onTap;

  const _FinalizationCard({required this.unlocked, required this.submittedCompany, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = unlocked ? StudentColors.approved : StudentColors.maroon;
    final message = !unlocked
        ? 'Complete all pre requisite requirements and start your OJT Journey!'
        : submittedCompany == null
            ? 'Requirements Completed. Start Finalizing your Account Information'
            : 'Submitted for $submittedCompany. Tap to view your details or update your supervisor.';
    return StudentCard(
      color: color,
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                submittedCompany != null ? Icons.verified : Icons.check_circle,
                color: unlocked ? Colors.white : Colors.white,
                size: 24,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Account Details Finalization',
                  style: studentSerif(size: 22, color: Colors.white, weight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            message,
            style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: unlocked ? 0.75 : 1)),
          ),
          if (unlocked) ...[
            const SizedBox(height: 12),
            Container(
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                submittedCompany == null ? 'Start Finalization' : 'View Details',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: StudentColors.approved),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
