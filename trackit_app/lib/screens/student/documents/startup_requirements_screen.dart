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

/// OJT Requirements (System Revision 2, Figma): overall progress, the
/// reminder and the four stages. Stages 1-3 hold documents; Stage 4 (Final
/// Details) is the student's final company and supervisor information.
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
    if (phase.isFinalDetails) {
      await _openFinalization(phase);
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => StudentBackdrop(
          child: PhaseRequirementsScreen(phaseId: phase.id, service: widget.service),
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

  Future<void> _openFinalization(OjtRequirementPhase stage) async {
    final profile = _profile;
    if (profile == null) return;
    final String? result;
    if (_companyDetails == null) {
      result = await Navigator.of(context).push<String>(
        MaterialPageRoute(
          builder: (context) => StudentBackdrop(
            child: AccountFinalizationScreen(
              service: widget.profileService,
              profile: profile,
              stage: stage,
            ),
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
