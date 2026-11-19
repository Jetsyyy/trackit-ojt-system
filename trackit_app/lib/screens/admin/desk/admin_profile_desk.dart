import 'package:flutter/material.dart';
import '../../../models/admin_profile.dart';
import '../../../models/admin_session.dart';
import '../../../services/api_client.dart';
import '../../../utils/ph_time.dart';
import '../../../widgets/common/desk_ui.dart';

/// Admin My Profile (TrackIT admin mockup): header card, Account
/// Information, Account Security, Connected Sessions and Recent Account
/// Activity. Actions (edit, change password, terminate) come from
/// AdminProfileScreen, which owns the dialogs.
class AdminProfileDesk extends StatelessWidget {
  final AdminProfile admin;
  final List<AdminSession> sessions;
  final bool loadingSessions;
  final VoidCallback onEditProfile;
  final VoidCallback onChangePassword;
  final ValueChanged<AdminSession> onTerminate;
  final VoidCallback onViewAllSessions;

  const AdminProfileDesk({
    super.key,
    required this.admin,
    required this.sessions,
    required this.loadingSessions,
    required this.onEditProfile,
    required this.onChangePassword,
    required this.onTerminate,
    required this.onViewAllSessions,
  });

  static String _when(DateTime t) => formatPh(t, 'MMM d, yyyy · h:mm a');

  @override
  Widget build(BuildContext context) {
    final active = admin.status != 'inactive';
    final current = sessions.where((s) => s.current).firstOrNull;
    final lastLogin = sessions.length > 1 && current != null
        ? sessions.firstWhere((s) => !s.current, orElse: () => current).loginAt
        : (sessions.isEmpty ? null : sessions.first.loginAt);
    final open = sessions.where((s) => s.active).take(3).toList();
    // Recent activity from what the server records: sign-ins (with the
    // device) and the last password change.
    final activity = <(String, String, DateTime)>[
      for (final s in sessions.take(6)) ('Logged in', s.device, s.loginAt),
      if (admin.lastPasswordChange != null) ('Changed password', 'Security update', admin.lastPasswordChange!),
    ]..sort((a, b) => b.$3.compareTo(a.$3));

    return DeskPage(
      title: 'My Profile',
      children: [
        DeskCard(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 18),
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
                    child: CircleAvatar(
                      radius: 38,
                      backgroundColor: Colors.white,
                      foregroundImage: admin.avatarUrl != null
                          ? NetworkImage(ApiClient.resolveUrl(admin.avatarUrl!))
                          : const AssetImage('assets/images/ccst_seal.webp') as ImageProvider,
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
                        onTap: onEditProfile,
                        child: const Padding(
                          padding: EdgeInsets.all(5),
                          child: Icon(Icons.edit, size: 12, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(admin.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                    Text(admin.email, style: const TextStyle(fontSize: 13, color: Color(0xFF6B6B6B))),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                          decoration: BoxDecoration(color: const Color(0xFFE6E4FB), borderRadius: BorderRadius.circular(12)),
                          child: const Text(
                            'Administrator',
                            style: TextStyle(fontSize: 11, color: Color(0xFF5B4FCF), fontWeight: FontWeight.w500),
                          ),
                        ),
                        DeskStatusChip(label: active ? '● Active' : '● Inactive', tone: active ? DeskChipTone.green : DeskChipTone.red),
                      ],
                    ),
                  ],
                ),
              ),
              _Pill(label: 'Change Photo', onTap: onEditProfile, large: true),
            ],
          ),
        ),
        const SizedBox(height: 16),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: DeskCard(
                  title: 'Account Information',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _Subtitle('Your administrator account details.'),
                      _Row(icon: Icons.account_circle_outlined, label: 'Account Name', value: admin.name),
                      const _Row(
                        icon: Icons.apartment_outlined,
                        label: 'Department',
                        value: 'College of Computer Studies and Technology',
                      ),
                      _Row(
                        icon: Icons.alternate_email,
                        label: 'Email Address',
                        value: admin.email,
                        trailing: _Pill(label: 'Change Email', onTap: onEditProfile),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: DeskCard(
                  title: 'Account Security',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _Subtitle('Keep your account protected.'),
                      _Row(
                        icon: Icons.history,
                        label: 'Last Password Change',
                        value: admin.lastPasswordChange == null ? 'Never changed' : _when(admin.lastPasswordChange!),
                      ),
                      _Row(icon: Icons.schedule, label: 'Last Login', value: lastLogin == null ? '--' : _when(lastLogin)),
                      _Row(
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
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: DeskCard(
                  title: 'Connected Sessions',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _Subtitle('Devices currently signed in to your account.'),
                      if (loadingSessions)
                        const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()))
                      else if (open.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Text('No other sessions.', style: TextStyle(fontSize: 12, color: DeskColors.muted)),
                        ),
                      for (final s in open) _session(s),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: onViewAllSessions,
                          style: TextButton.styleFrom(foregroundColor: const Color(0xFF8C1C2A)),
                          child: const Text('View All Sessions →', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: DeskCard(
                  title: 'Recent Account Activity',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _Subtitle('Latest actions made on your account.'),
                      if (activity.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Text('No activity yet.', style: TextStyle(fontSize: 12, color: DeskColors.muted)),
                        ),
                      for (final a in activity.take(4))
                        Container(
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
                                    Text(a.$1, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                    Text(a.$2, style: const TextStyle(fontSize: 11, color: DeskColors.muted)),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(formatPh(a.$3, 'MMM d, yyyy'), style: const TextStyle(fontSize: 11, color: DeskColors.muted)),
                                  Text(formatPh(a.$3, 'h:mm a'), style: const TextStyle(fontSize: 11, color: DeskColors.muted)),
                                ],
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _session(AdminSession s) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFEDEDED)))),
      child: Row(
        children: [
          const DeskIconBox(icon: Icons.desktop_windows_outlined, size: 30),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(formatPh(s.loginAt, 'MMM d, yyyy    h:mm a'), style: const TextStyle(fontSize: 10.5, color: DeskColors.muted)),
                Row(
                  children: [
                    Text(s.device, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    if (s.current) ...[
                      const SizedBox(width: 8),
                      const DeskStatusChip(label: 'This device', tone: DeskChipTone.green),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (s.current)
            const Text('● Active', style: TextStyle(fontSize: 11, color: Color(0xFF1E9E45), fontWeight: FontWeight.w600))
          else
            OutlinedButton(
              onPressed: () => onTerminate(s),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFE53935),
                side: const BorderSide(color: Color(0xFFE53935)),
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: const StadiumBorder(),
              ),
              child: const Text('Terminate', style: TextStyle(fontSize: 11.5)),
            ),
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
        const SizedBox(height: 4),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final Widget? trailing;

  const _Row({required this.icon, required this.label, required this.value, this.valueColor, this.trailing});

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

class _Pill extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool large;

  const _Pill({required this.label, required this.onTap, this.large = false});

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
