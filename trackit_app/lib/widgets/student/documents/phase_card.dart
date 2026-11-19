import 'package:flutter/material.dart';
import '../../../models/ojt_requirement_doc.dart';
import '../../../models/ojt_requirement_phase.dart';
import '../student_ui.dart';

/// Status pill for a requirement phase: Approved / Re-Upload / Pending /
/// Locked (TrackIT student mockup).
StudentStatusPill phaseStatusPill(OjtRequirementPhase phase) {
  if (phase.status == PhaseStatus.completed) {
    return const StudentStatusPill(label: 'Approved', background: Color(0xFFD3EBD7), foreground: Color(0xFF2E7D45));
  }
  if (phase.status == PhaseStatus.locked) {
    return const StudentStatusPill(label: 'Locked', background: Color(0xFFCFCFCF), foreground: Color(0xFF3A3A3A));
  }
  if (phase.documents.any((d) => d.status == RequirementDocStatus.rejected)) {
    return const StudentStatusPill(label: 'Re-Upload', background: Color(0xFFF6D9DB), foreground: Color(0xFF8C1C2A));
  }
  return const StudentStatusPill(label: 'Pending', background: Color(0xFFFCEBC4), foreground: Color(0xFFD9822B));
}

class PhaseCard extends StatelessWidget {
  final OjtRequirementPhase phase;
  final VoidCallback onTap;

  const PhaseCard({super.key, required this.phase, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final locked = phase.status == PhaseStatus.locked;
    return StudentCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: PhaseNumber(number: phase.order, locked: locked),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Text(phase.title, style: studentSerif(size: 24, weight: FontWeight.w600)),
                ),
              ),
              phaseStatusPill(phase),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  phase.description,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF2B2B2B)),
                ),
              ),
              Icon(locked ? Icons.lock_outline : Icons.chevron_right, color: const Color(0xFF3A3A3A)),
            ],
          ),
        ],
      ),
    );
  }
}
