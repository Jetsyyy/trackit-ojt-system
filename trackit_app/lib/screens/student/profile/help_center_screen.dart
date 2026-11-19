import 'package:flutter/material.dart';
import '../../../utils/app_colors.dart';
import '../../../widgets/common/back_nav_header.dart';
import '../../../widgets/common/settings_tile.dart';

class HelpCenterScreen extends StatelessWidget {
  const HelpCenterScreen({super.key});

  static const _faqs = [
    (
      'How do I activate my TRACKIT account?',
      'Use the activation code given by your department. Only students on '
          'the DCSE master list can activate an account.',
    ),
    (
      'How are my OJT hours counted?',
      'Every week, open the Weekly tab and upload a photo or scan of that '
          'week\'s DTR and your Accomplishment Report, then enter the total '
          'hours on the DTR. The hours are added to your credited total only '
          'after your instructor approves that week.',
    ),
    (
      'How do I submit OJT requirements?',
      'Go to Document > OJT Requirements. Complete each phase in order -- '
          'later phases unlock once the current one is fully submitted and '
          'approved.',
    ),
    (
      'Can I apply to a company through the app?',
      'No. The HTE Directory is for reference only -- you apply to '
          'companies directly. TRACKIT does not process internship '
          'applications.',
    ),
    (
      'What if my instructor returns a week?',
      'Open that week in the Weekly tab to read your instructor\'s remarks, '
          'fix the files or hours, and resubmit. Approved weeks are locked.',
    ),
  ];

  void _showContentDialog(BuildContext context, String title, String body) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(child: Text(body)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature is coming soon.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      bottom: false,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const BackNavHeader(subtitle: 'Help Center'),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: const Text(
                'Frequently Asked Questions',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.cardWhite,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  children: [
                    for (final faq in _faqs)
                      ExpansionTile(
                        title: Text(
                          faq.$1,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        childrenPadding: const EdgeInsets.fromLTRB(
                          16,
                          0,
                          16,
                          16,
                        ),
                        expandedAlignment: Alignment.topLeft,
                        children: [
                          Text(
                            faq.$2,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: AppColors.cardWhite,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  children: [
                    SettingsTile(
                      icon: Icons.menu_book_outlined,
                      title: 'User Guide',
                      onTap: () => _showContentDialog(
                        context,
                        'User Guide',
                        'TRACKIT walks you through OJT in four steps: '
                            '1) Activate your account with your department '
                            'code. 2) Complete each OJT Requirements phase in '
                            'order. 3) Confirm your company details and OJT '
                            'start date. 4) Every week, upload your DTR and '
                            'Accomplishment Report in the Weekly tab.',
                      ),
                    ),
                    const Divider(height: 1),
                    SettingsTile(
                      icon: Icons.support_agent_outlined,
                      title: 'Contact Support',
                      onTap: () =>
                          _showComingSoon(context, 'Contact Support'),
                    ),
                    const Divider(height: 1),
                    SettingsTile(
                      icon: Icons.bug_report_outlined,
                      title: 'Report a Bug',
                      onTap: () => _showComingSoon(context, 'Report a Bug'),
                    ),
                    const Divider(height: 1),
                    SettingsTile(
                      icon: Icons.info_outline,
                      title: 'About TrackIT',
                      onTap: () => _showContentDialog(
                        context,
                        'About TRACKIT',
                        'TRACKIT is a centralized OJT tracking and '
                            'documentation system built for the Department '
                            'of Computing Sciences and Engineering (DCSE) '
                            'at Dalubhasaan ng Lungsod ng San Pablo.',
                      ),
                    ),
                    const Divider(height: 1),
                    SettingsTile(
                      icon: Icons.privacy_tip_outlined,
                      title: 'Privacy Policy',
                      onTap: () => _showContentDialog(
                        context,
                        'Privacy Policy',
                        'TRACKIT collects only the information needed for '
                            'OJT monitoring and documentation -- weekly DTRs '
                            'and accomplishment reports, and submitted '
                            'requirements. '
                            'Data is used solely by DCSE for OJT purposes '
                            'and is not shared with third parties.',
                      ),
                    ),
                    const Divider(height: 1),
                    SettingsTile(
                      icon: Icons.gavel_outlined,
                      title: 'Terms & Conditions',
                      onTap: () => _showContentDialog(
                        context,
                        'Terms & Conditions',
                        'TRACKIT is exclusive to DCSE students, instructors, '
                            'and administrators. Only students on the '
                            'department\'s master list may activate an '
                            'account. The HTE Directory is provided for '
                            'reference only; TRACKIT does not process '
                            'internship applications on your behalf.',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
