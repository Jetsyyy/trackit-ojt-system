import 'package:flutter/material.dart';
import '../../../widgets/common/app_header.dart';
import '../../../widgets/student/student_ui.dart';

/// Documents hub (TrackIT student mockup): three large maroon cards.
/// Each card shows a photo on its right side, fading into the maroon, if
/// the image exists in assets/images (doc_hte.jpg, doc_requirements.jpg,
/// doc_weekly.jpg); otherwise a large faint icon stands in.
class DocumentsHubScreen extends StatelessWidget {
  final VoidCallback onOpenHteDirectory;
  final VoidCallback onOpenOjtRequirements;
  final VoidCallback onOpenWeeklySubmissions;

  /// Requirements with deadlines: OJT office ones (e.g. evaluation forms
  /// per period) and the instructor's Additional Requirements.
  final VoidCallback onOpenScheduledRequirements;

  const DocumentsHubScreen({
    super.key,
    required this.onOpenHteDirectory,
    required this.onOpenOjtRequirements,
    required this.onOpenWeeklySubmissions,
    required this.onOpenScheduledRequirements,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        const AppHeader(title: 'Documents', subtitle: 'Requirements and Submissions'),
        Padding(
          padding: const EdgeInsets.fromLTRB(26, 34, 26, 24),
          child: Column(
            children: [
              _HubCard(
                title: 'HTE Directory',
                image: 'assets/images/doc_hte.jpg',
                icon: Icons.location_city,
                onTap: onOpenHteDirectory,
              ),
              const SizedBox(height: 22),
              _HubCard(
                title: 'OJT Requirements',
                image: 'assets/images/doc_requirements.jpg',
                icon: Icons.folder_copy_outlined,
                onTap: onOpenOjtRequirements,
              ),
              const SizedBox(height: 22),
              _HubCard(
                title: 'Weekly Submissions',
                image: 'assets/images/doc_weekly.jpg',
                icon: Icons.calendar_month_outlined,
                onTap: onOpenWeeklySubmissions,
              ),
              const SizedBox(height: 22),
              _HubCard(
                title: 'Scheduled Requirements',
                image: 'assets/images/doc_requirements.jpg',
                icon: Icons.event_note_outlined,
                onTap: onOpenScheduledRequirements,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HubCard extends StatelessWidget {
  final String title;
  final String image;
  final IconData icon;
  final VoidCallback onTap;

  const _HubCard({required this.title, required this.image, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 108,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 8, offset: Offset(0, 4))],
      ),
      child: Material(
        color: StudentColors.maroon,
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            children: [
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                width: 190,
                child: ShaderMask(
                  // Fade the photo into the maroon from the left.
                  shaderCallback: (rect) => const LinearGradient(
                    colors: [Colors.transparent, Colors.white],
                    stops: [0.0, 0.7],
                  ).createShader(rect),
                  blendMode: BlendMode.dstIn,
                  child: Image.asset(
                    image,
                    fit: BoxFit.cover,
                    color: const Color(0x66000000),
                    colorBlendMode: BlendMode.darken,
                    errorBuilder: (context, error, stack) => Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 14),
                        child: Icon(icon, size: 84, color: Colors.white.withValues(alpha: 0.13)),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.white.withValues(alpha: 0.04), Colors.black.withValues(alpha: 0.12)],
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 18),
                  child: Text(title, style: studentSerif(size: 28, color: Colors.white, weight: FontWeight.w500)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
