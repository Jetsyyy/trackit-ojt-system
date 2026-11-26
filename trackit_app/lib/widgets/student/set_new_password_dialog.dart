import 'package:flutter/material.dart';
import '../../services/api_client.dart';
import '../../utils/app_colors.dart';
import '../../utils/password_rules.dart';
import '../common/password_guide.dart';

/// Shown right after a student signs in with the temporary password their
/// instructor gave them (Forgot Password, System Revision 4): they must set
/// their own password before using TrackIT. It can't be dismissed; Log out
/// is the only other way out. Returns true once the password is saved.
class SetNewPasswordDialog extends StatefulWidget {
  final Future<void> Function({required String currentPassword, required String newPassword}) save;
  final VoidCallback onLogout;

  const SetNewPasswordDialog({super.key, required this.save, required this.onLogout});

  @override
  State<SetNewPasswordDialog> createState() => _SetNewPasswordDialogState();
}

class _SetNewPasswordDialogState extends State<SetNewPasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
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
      // No current password: the server allows this only right after an
      // instructor reset.
      await widget.save(currentPassword: '', newPassword: _new.text);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e is ApiException ? e.message : 'Could not save your new password.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AlertDialog(
        icon: const Icon(Icons.lock_reset, color: AppColors.primaryMaroon, size: 32),
        title: const Text('Set a new password'),
        content: SizedBox(
          width: 380,
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Your instructor reset your password. Choose your own new password to continue.',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  if (_error != null) ...[
                    Text(_error!, style: const TextStyle(color: AppColors.statRedIcon)),
                    const SizedBox(height: 8),
                  ],
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
          TextButton(onPressed: _saving ? null : widget.onLogout, child: const Text('Log out')),
          FilledButton(
            onPressed: _saving ? null : _submit,
            style: FilledButton.styleFrom(backgroundColor: AppColors.primaryMaroon),
            child: _saving
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Save password'),
          ),
        ],
      ),
    );
  }
}
