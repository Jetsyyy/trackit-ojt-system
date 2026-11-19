import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';
import '../../widgets/common/app_header.dart';

/// The Document (OJT Management) tab's hub -- weekly DTR & AR review and
/// Official Requirements review. The requirement list and its template
/// files are managed by the Admin (System Revisions item 15).
class TeacherDocumentsHubScreen extends StatelessWidget {
  final VoidCallback onOpenOfficialRequirements;
  final VoidCallback onOpenWeeklyReports;

  const TeacherDocumentsHubScreen({
    super.key,
    required this.onOpenOfficialRequirements,
    required this.onOpenWeeklyReports,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      bottom: false,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AppHeader(
              title: 'Document',
              subtitle: 'OJT Management',
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionLabel('OJT Hours'),
                  const SizedBox(height: 10),
                  _HubCard(
                    children: [
                      _HubTile(
                        icon: Icons.fact_check_outlined,
                        title: 'Weekly DTR & AR Review',
                        subtitle: 'Approve weekly hours or return with remarks',
                        onTap: onOpenWeeklyReports,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const _SectionLabel('Documents'),
                  const SizedBox(height: 10),
                  _HubCard(
                    children: [
                      _HubTile(
                        icon: Icons.folder_shared_outlined,
                        title: 'Official Requirements',
                        subtitle: 'Review submissions by student',
                        onTap: onOpenOfficialRequirements,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;

  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
      ),
    );
  }
}

class _HubCard extends StatelessWidget {
  final List<Widget> children;

  const _HubCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }
}

class _HubTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _HubTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // _HubCard paints an opaque background behind this tile, which would
    // otherwise hide ListTile's ink splash (it paints on the nearest
    // Material ancestor, underneath that background) -- a transparent
    // Material here gives the splash its own paint layer on top of it.
    return Material(
      color: Colors.transparent,
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Icon(icon, color: AppColors.primaryMaroon, size: 20),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
            fontSize: 13,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
        ),
        trailing: const Icon(
          Icons.chevron_right,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}
