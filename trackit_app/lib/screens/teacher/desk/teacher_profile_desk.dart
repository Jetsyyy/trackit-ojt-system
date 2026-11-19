import 'package:flutter/material.dart';
import '../../../models/teacher_profile.dart';
import '../../../services/api_client.dart';
import '../../../utils/ph_time.dart';
import '../../../widgets/common/desk_ui.dart';

/// Desktop My Profile page (instructor mockup): header card, Account
/// Information, Help Center / Settings, Account Security and Recent
/// Account Activity. Actions come from TeacherProfileScreen.
class TeacherProfileDesk extends StatelessWidget {
  final TeacherProfile profile;
  final bool uploading;
  final VoidCallback onChangePhoto;
  final VoidCallback onChangeEmail;
  final VoidCallback onChangePassword;
  final VoidCallback onOpenHelpCenter;
  final VoidCallback onOpenSettings;
  final Future<void> Function() onRefresh;

  const TeacherProfileDesk({
    super.key,
    required this.profile,
    required this.uploading,
    required this.onChangePhoto,
    required this.onChangeEmail,
    required this.onChangePassword,
    required this.onOpenHelpCenter,
    required this.onOpenSettings,
    required this.onRefresh,
  });

  String get _sectionHandles {
    if (profile.sections.isEmpty) return 'No sections assigned yet';
    if (profile.programs.length == 1) {
      return '${profile.programs.first} - ${profile.sections.join(', ')}';
    }
    return '${profile.programs.join(' / ')} — ${profile.sections.join(', ')}';
  }

  static String _when(DateTime? t) => t == null ? '--' : formatPh(t, 'MMM d, yyyy · h:mm a');

  @override
  Widget build(BuildContext context) {
    final active = profile.status != 'inactive';
    return DeskPage(
      title: 'My Profile',
      onRefresh: onRefresh,
      children: [
        _header(active),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                children: [
                  DeskCard(
                    title: 'Account Information',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _Subtitle('Personal Details'),
                        _InfoRow(icon: Icons.school, label: 'Section Handles', value: _sectionHandles),
                        _InfoRow(
                          icon: Icons.alternate_email,
                          label: 'Email Address',
                          value: profile.email,
                          trailing: _PillButton(label: 'Change Email', onTap: onChangeEmail),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  DeskCard(
                    title: 'Help & Settings',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _Subtitle('Support and preferences'),
                        _LinkRow(
                          icon: Icons.help_outline,
                          title: 'Help Center',
                          subtitle: 'FAQs, Guides, & Support',
                          onTap: onOpenHelpCenter,
                        ),
                        _LinkRow(
                          icon: Icons.settings_outlined,
                          title: 'Settings',
                          subtitle: 'Account, Privacy & Preferences',
                          onTap: onOpenSettings,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                children: [
                  DeskCard(
                    title: 'Account Security',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _Subtitle('Keep your account protected.'),
                        _InfoRow(
                          icon: Icons.history,
                          label: 'Last Password Change',
                          value: profile.passwordChangedAt == null ? 'Never changed' : _when(profile.passwordChangedAt),
                        ),
                        _InfoRow(icon: Icons.schedule, label: 'Last Login', value: _when(profile.lastLoginAt)),
                        _InfoRow(
                          icon: Icons.done_all,
                          label: 'Account Status',
                          value: active ? 'Active' : 'Inactive',
                          valueColor: active ? const Color(0xFF1E9E45) : const Color(0xFFC62828),
                        ),
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: ElevatedButton(
                            onPressed: onChangePassword,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF8C1C2A),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                              shape: const StadiumBorder(),
                            ),
                            child: const Text('Change Password', style: TextStyle(fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  DeskCard(
                    title: 'Recent Account Activity',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _Subtitle('Latest actions made on your account.'),
                        if (profile.activity.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              'No activity recorded yet. Your next sign-in will appear here.',
                              style: TextStyle(fontSize: 12, color: DeskColors.muted),
                            ),
                          )
                        else
                          for (final a in profile.activity) _ActivityRow(activity: a),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _header(bool active) {
    return DeskCard(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF8C1C2A), width: 2),
                ),
                child: DeskAvatar(
                  name: profile.name,
                  imageUrl: profile.photoUrl == null ? null : ApiClient.resolveUrl(profile.photoUrl!),
                  radius: 42,
                ),
              ),
              Positioned(
                left: -2,
                top: 2,
                child: Material(
                  color: const Color(0xFF8C1C2A),
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: uploading ? null : onChangePhoto,
                    child: Padding(
                      padding: const EdgeInsets.all(5),
                      child: uploading
                          ? const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.edit, size: 12, color: Colors.white),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 22),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.name,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Color(0xFF1F1F1F)),
                ),
                Text(profile.email, style: const TextStyle(fontSize: 13.5, color: Color(0xFF6B6B6B))),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE6E4FB),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        profile.position.isEmpty ? 'Instructor' : profile.position,
                        style: const TextStyle(fontSize: 11, color: Color(0xFF5B4FCF), fontWeight: FontWeight.w500),
                      ),
                    ),
                    DeskStatusChip(
                      label: active ? '● Active' : '● Inactive',
                      tone: active ? DeskChipTone.green : DeskChipTone.red,
                    ),
                  ],
                ),
              ],
            ),
          ),
          _PillButton(label: 'Change Photo', onTap: uploading ? null : onChangePhoto, large: true),
        ],
      ),
    );
  }
}

class _Subtitle extends StatelessWidget {
  final String text;

  const _Subtitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Transform.translate(
          offset: const Offset(0, -10),
          child: Text(text, style: const TextStyle(fontSize: 11.5, color: DeskColors.muted)),
        ),
        const Divider(height: 1, color: Color(0xFFE5E5E5)),
        const SizedBox(height: 6),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final Widget? trailing;

  const _InfoRow({required this.icon, required this.label, required this.value, this.valueColor, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFEDEDED)))),
      child: Row(
        children: [
          DeskIconBox(icon: icon, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, color: DeskColors.muted)),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: valueColor ?? const Color(0xFF1F1F1F)),
                ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _LinkRow({required this.icon, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFEDEDED)))),
        child: Row(
          children: [
            DeskIconBox(icon: icon, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                  Text(subtitle, style: const TextStyle(fontSize: 11, color: DeskColors.muted)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFF6B6B6B)),
          ],
        ),
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  final AccountActivity activity;

  const _ActivityRow({required this.activity});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFEDEDED)))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 5, right: 12),
            decoration: const BoxDecoration(color: Color(0xFF8C1C2A), shape: BoxShape.circle),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(activity.action, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                if (activity.detail != null)
                  Text(activity.detail!, style: const TextStyle(fontSize: 11, color: DeskColors.muted)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(formatPh(activity.at, 'MMM d, yyyy'), style: const TextStyle(fontSize: 11, color: DeskColors.muted)),
              Text(formatPh(activity.at, 'h:mm a'), style: const TextStyle(fontSize: 11, color: DeskColors.muted)),
            ],
          ),
        ],
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool large;

  const _PillButton({required this.label, required this.onTap, this.large = false});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF8C1C2A),
        side: const BorderSide(color: Color(0xFF8C1C2A)),
        padding: EdgeInsets.symmetric(horizontal: large ? 22 : 14, vertical: large ? 14 : 10),
        shape: const StadiumBorder(),
      ),
      child: Text(label, style: TextStyle(fontSize: large ? 13 : 12)),
    );
  }
}
