import 'package:flutter/material.dart';
import '../../../services/api_client.dart';
import '../../../utils/password_rules.dart';
import '../../../widgets/common/password_guide.dart';
import '../../../utils/app_colors.dart';
import '../../../widgets/common/back_nav_header.dart';
import '../../../widgets/common/settings_section_header.dart';
import '../../../widgets/common/settings_tile.dart';

class SettingsScreen extends StatefulWidget {
  /// Only the student side wires these to real screens (Edit Profile,
  /// Login History) -- this screen is shared with the Teacher module
  /// (see TeacherProfileTabNavigator), where they stay null and fall
  /// back to the "coming soon" stub like every other tile here.
  final VoidCallback? onOpenEditProfile;
  final VoidCallback? onOpenLoginHistory;

  /// Student side only: saves a new password. Null keeps the stub.
  final Future<void> Function({required String currentPassword, required String newPassword})? changePassword;

  const SettingsScreen({
    super.key,
    this.onOpenEditProfile,
    this.onOpenLoginHistory,
    this.changePassword,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _pushEnabled = true;
  bool _emailEnabled = true;
  bool _documentUpdates = true;
  bool _weeklyReminders = true;
  bool _reportUpdates = true;
  bool _systemAnnouncements = true;
  bool _profilePublic = false;

  void _stub(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature is coming soon.')),
    );
  }

  Future<void> _openChangePassword() async {
    final save = widget.changePassword;
    if (save == null) return _stub('Change Password');
    final changed = await showDialog<bool>(
      context: context,
      builder: (context) => _ChangePasswordDialog(save: save),
    );
    if (changed == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password changed.')));
    }
  }

  void _confirmDeleteAccount() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'Deleting your account requires admin approval and cannot be '
          'undone once processed. Are you sure you want to request this?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _stub('Account deletion requests');
            },
            child: const Text(
              'Request Deletion',
              style: TextStyle(color: AppColors.statRedIcon),
            ),
          ),
        ],
      ),
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
            const BackNavHeader(subtitle: 'Settings'),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SettingsSectionHeader(title: 'Account'),
                  _Group(
                    children: [
                      SettingsTile(
                        icon: Icons.edit_outlined,
                        title: 'Edit Profile',
                        onTap: widget.onOpenEditProfile ?? () => _stub('Edit Profile'),
                      ),
                      SettingsTile(
                        icon: Icons.photo_camera_outlined,
                        title: 'Change Profile Picture',
                        onTap: widget.onOpenEditProfile ??
                            () => _stub('Profile picture upload'),
                      ),
                      SettingsTile(
                        icon: Icons.lock_outline,
                        title: 'Change Password',
                        onTap: _openChangePassword,
                      ),
                      SettingsTile(
                        icon: Icons.alternate_email,
                        title: 'Change Email',
                        onTap: () => _stub('Change Email'),
                      ),
                      SettingsTile(
                        icon: Icons.phone_outlined,
                        title: 'Change Mobile Number',
                        onTap: () => _stub('Change Mobile Number'),
                      ),
                    ],
                  ),
                  const SettingsSectionHeader(title: 'Security'),
                  _Group(
                    children: [
                      SettingsTile(
                        icon: Icons.history,
                        title: 'Login History',
                        onTap: widget.onOpenLoginHistory ?? () => _stub('Login History'),
                      ),
                    ],
                  ),
                  const SettingsSectionHeader(title: 'Notifications'),
                  _Group(
                    children: [
                      SettingsTile(
                        icon: Icons.notifications_active_outlined,
                        title: 'Push Notifications',
                        trailing: Switch(
                          value: _pushEnabled,
                          activeThumbColor: AppColors.primaryMaroon,
                          onChanged: (v) => setState(() => _pushEnabled = v),
                        ),
                      ),
                      SettingsTile(
                        icon: Icons.mail_outline,
                        title: 'Email Notifications',
                        trailing: Switch(
                          value: _emailEnabled,
                          activeThumbColor: AppColors.primaryMaroon,
                          onChanged: (v) => setState(() => _emailEnabled = v),
                        ),
                      ),
                      SettingsTile(
                        icon: Icons.description_outlined,
                        title: 'Document Updates',
                        trailing: Switch(
                          value: _documentUpdates,
                          activeThumbColor: AppColors.primaryMaroon,
                          onChanged: (v) =>
                              setState(() => _documentUpdates = v),
                        ),
                      ),
                      SettingsTile(
                        icon: Icons.event_available_outlined,
                        title: 'Weekly Submission Reminders',
                        trailing: Switch(
                          value: _weeklyReminders,
                          activeThumbColor: AppColors.primaryMaroon,
                          onChanged: (v) =>
                              setState(() => _weeklyReminders = v),
                        ),
                      ),
                      SettingsTile(
                        icon: Icons.assignment_outlined,
                        title: 'Report Updates',
                        trailing: Switch(
                          value: _reportUpdates,
                          activeThumbColor: AppColors.primaryMaroon,
                          onChanged: (v) => setState(() => _reportUpdates = v),
                        ),
                      ),
                      SettingsTile(
                        icon: Icons.campaign_outlined,
                        title: 'System Announcements',
                        trailing: Switch(
                          value: _systemAnnouncements,
                          activeThumbColor: AppColors.primaryMaroon,
                          onChanged: (v) =>
                              setState(() => _systemAnnouncements = v),
                        ),
                      ),
                    ],
                  ),
                  const SettingsSectionHeader(title: 'Privacy'),
                  _Group(
                    children: [
                      SettingsTile(
                        icon: Icons.visibility_outlined,
                        title: 'Profile Visibility',
                        trailing: Switch(
                          value: _profilePublic,
                          activeThumbColor: AppColors.primaryMaroon,
                          onChanged: (v) => setState(() => _profilePublic = v),
                        ),
                      ),
                    ],
                  ),
                  const SettingsSectionHeader(title: 'Application'),
                  _Group(
                    children: [
                      const SettingsTile(
                        icon: Icons.info_outline,
                        title: 'App Version',
                        trailing: Text(
                          '0.1.0',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                  const SettingsSectionHeader(title: 'Support'),
                  _Group(
                    children: [
                      SettingsTile(
                        icon: Icons.help_outline,
                        title: 'Help Center',
                        onTap: () => Navigator.of(context).pop(),
                      ),
                      SettingsTile(
                        icon: Icons.feedback_outlined,
                        title: 'Send Feedback',
                        onTap: () => _stub('Send Feedback'),
                      ),
                      SettingsTile(
                        icon: Icons.admin_panel_settings_outlined,
                        title: 'Contact Administrator',
                        onTap: () => _stub('Contact Administrator'),
                      ),
                      SettingsTile(
                        icon: Icons.bug_report_outlined,
                        title: 'Report Bug',
                        onTap: () => _stub('Report Bug'),
                      ),
                    ],
                  ),
                  const SettingsSectionHeader(title: 'Account Actions'),
                  _Group(
                    children: [
                      SettingsTile(
                        icon: Icons.logout,
                        title: 'Logout',
                        iconColor: AppColors.statRedIcon,
                        titleColor: AppColors.statRedIcon,
                        onTap: () => _stub('Logout'),
                      ),
                      SettingsTile(
                        icon: Icons.delete_outline,
                        title: 'Delete Account',
                        subtitle: 'Admin approval required',
                        iconColor: AppColors.statRedIcon,
                        titleColor: AppColors.statRedIcon,
                        onTap: _confirmDeleteAccount,
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

class _Group extends StatelessWidget {
  final List<Widget> children;

  const _Group({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1) const Divider(height: 1),
          ],
        ],
      ),
    );
  }
}

/// Current password, new password (with the live password guide) and
/// confirmation.
class _ChangePasswordDialog extends StatefulWidget {
  final Future<void> Function({required String currentPassword, required String newPassword}) save;

  const _ChangePasswordDialog({required this.save});

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.save(currentPassword: _current.text, newPassword: _new.text);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e is ApiException ? e.message : 'Could not change the password.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Change Password'),
      content: SizedBox(
        width: 360,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_error != null) ...[
                  Text(_error!, style: const TextStyle(color: AppColors.statRedIcon)),
                  const SizedBox(height: 8),
                ],
                TextFormField(
                  controller: _current,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Current Password'),
                  validator: (v) => (v == null || v.isEmpty) ? 'Enter your current password' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _new,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'New Password'),
                  validator: newPasswordError,
                ),
                PasswordGuide(controller: _new),
                const SizedBox(height: 4),
                TextFormField(
                  controller: _confirm,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Confirm New Password'),
                  validator: (v) => v != _new.text ? 'Passwords do not match' : null,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.of(context).pop(false), child: const Text('Cancel')),
        FilledButton(
          onPressed: _saving ? null : _submit,
          style: FilledButton.styleFrom(backgroundColor: AppColors.primaryMaroon),
          child: _saving
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Save'),
        ),
      ],
    );
  }
}
