import 'package:flutter/material.dart';
import '../../utils/password_rules.dart';
import '../../widgets/common/password_guide.dart';
import '../../services/api_client.dart';
import '../../services/instructor_auth_service.dart';
import '../../services/session_role.dart';
import '../../utils/app_colors.dart';
import '../../widgets/auth/portal_layout.dart';

/// Instructor registration (System Revisions item 19).
///
/// With an Instructor Registration Code (INS-...) from the Admin, the
/// instructor enters their own details; the account then waits for the
/// Admin to approve it and assign the section(s). Sections are never
/// chosen here.
///
/// An activation code for an account the Admin already created
/// (FAC-...) still works: only a password is needed.
class InstructorRegisterScreen extends StatefulWidget {
  final InstructorAuthService instructorAuthService;
  final VoidCallback onRegistered;

  /// Pre-filled from an Admin invite link (?code=INS-...).
  final String? initialCode;

  const InstructorRegisterScreen({
    super.key,
    required this.instructorAuthService,
    required this.onRegistered,
    this.initialCode,
  });

  @override
  State<InstructorRegisterScreen> createState() =>
      _InstructorRegisterScreenState();
}

class _InstructorRegisterScreenState extends State<InstructorRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _codeController = TextEditingController(text: widget.initialCode ?? '');
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _numberController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _submitting = false;
  String? _errorMessage;

  // An INS- registration code (or no code yet) needs the instructor's
  // details. Any other code is the older activation code for an account
  // the Admin already created, where only a password is needed.
  bool get _needsDetails {
    final code = _codeController.text.trim();
    return code.isEmpty || InstructorAuthService.isRegistrationCode(code);
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _numberController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  String? _required(String? v, String label) =>
      _needsDetails && (v == null || v.trim().isEmpty) ? '$label is required' : null;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _errorMessage = null;
    });
    try {
      final details = _needsDetails;
      final result = await widget.instructorAuthService.register(
        activationCode: _codeController.text.trim(),
        password: _passwordController.text,
        name: details ? _nameController.text.trim() : null,
        email: details ? _emailController.text.trim() : null,
        phone: details ? _phoneController.text.trim() : null,
        instructorNumber: details ? _numberController.text.trim() : null,
      );
      if (!mounted) return;
      if (!result.isPending) {
        widget.onRegistered();
        return;
      }
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.hourglass_top, color: AppColors.statOrangeIcon, size: 36),
          title: const Text('Registration Sent'),
          content: Text(
            result.pendingMessage ??
                'The Admin will review your account and assign your section.',
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryMaroon,
                foregroundColor: Colors.white,
              ),
              child: const Text('Back to Login'),
            ),
          ],
        ),
      );
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (_) {
      setState(
        () => _errorMessage = 'Could not reach the server. Is it running?',
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final needsDetails = _needsDetails;
    return PortalLayout(
      portal: SessionRole.instructor,
      onBack: () => Navigator.of(context).maybePop(),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const PortalTitle(
              title: 'Register Account',
              subtitle: 'Create a new account to get started',
            ),
            if (_errorMessage != null) PortalMessage(message: _errorMessage!),
            PortalField(
              key: const ValueKey('name'),
              label: 'Name',
              hint: 'Enter your Full Name',
              icon: Icons.person_outline,
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              validator: (v) => _required(v, 'Full name'),
            ),
            PortalField(
              key: const ValueKey('email'),
              label: 'Email',
              hint: 'Enter your Email',
              icon: Icons.mail_outline,
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                if (!needsDetails) return null;
                final text = (v ?? '').trim();
                if (text.isEmpty) return 'Email is required';
                if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text)) {
                  return 'Enter a valid email';
                }
                return null;
              },
            ),
            PortalField(
              key: const ValueKey('phone'),
              label: 'Contact Number',
              hint: 'Enter your Contact Number',
              icon: Icons.phone_outlined,
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              validator: (v) => _required(v, 'Contact number'),
            ),
            PortalField(
              key: const ValueKey('instructorNumber'),
              label: 'Employee Number',
              hint: 'Enter your Instructor / Employee Number',
              icon: Icons.badge_outlined,
              controller: _numberController,
              textCapitalization: TextCapitalization.characters,
              validator: (v) => _required(v, 'Employee number'),
            ),
            PortalField(
              key: const ValueKey('password'),
              label: 'Password',
              hint: 'Enter your Password',
              icon: Icons.lock_outline,
              controller: _passwordController,
              isPassword: true,
              validator: newPasswordError,
            ),
            // Password guide: each rule ticks green while typing.
            PasswordGuide(controller: _passwordController),
            const SizedBox(height: 12),
            PortalField(
              key: const ValueKey('confirm'),
              label: 'Re-enter Password',
              hint: 'Re-enter your Password',
              icon: Icons.lock_outline,
              controller: _confirmController,
              isPassword: true,
              validator: (v) {
                if (v == null || v.isEmpty) return 'Re-enter your password';
                if (v != _passwordController.text) return 'Passwords do not match';
                return null;
              },
            ),
            PortalField(
              key: const ValueKey('code'),
              label: 'Activation Code',
              hint: 'Enter Activation Code',
              icon: Icons.key_outlined,
              controller: _codeController,
              highlighted: true,
              textCapitalization: TextCapitalization.characters,
              onChanged: (_) => setState(() {}),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Enter the code the Admin gave you'
                  : null,
            ),
            if (!needsDetails)
              const PortalMessage(
                error: false,
                icon: Icons.info_outline,
                message: 'This code activates an account the Admin already '
                    'created, so only a password is needed.',
              ),
            const SizedBox(height: 6),
            PortalPrimaryButton(
              label: 'Sign Up',
              loading: _submitting,
              onPressed: _submit,
            ),
            const SizedBox(height: 16),
            PortalLinkLine(
              text: 'Already have an account?',
              link: 'Sign in',
              onTap: () => Navigator.of(context).maybePop(),
            ),
          ],
        ),
      ),
    );
  }
}
