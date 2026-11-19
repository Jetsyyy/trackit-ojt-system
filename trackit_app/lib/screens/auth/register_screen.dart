import 'dart:async';

import 'package:flutter/material.dart';
import '../../models/class_lookup_result.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/session_role.dart';
import '../../utils/app_colors.dart';
import '../../widgets/auth/portal_layout.dart';

class RegisterScreen extends StatefulWidget {
  final AuthService authService;
  final VoidCallback onRegistered;

  const RegisterScreen({
    super.key,
    required this.authService,
    required this.onRegistered,
  });

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _studentIdController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _codeController = TextEditingController();
  bool _submitting = false;
  String? _errorMessage;

  Timer? _lookupDebounce;
  bool _lookingUpCode = false;
  ClassLookupResult? _lookupResult;
  String? _lookupError;

  @override
  void dispose() {
    _lookupDebounce?.cancel();
    _nameController.dispose();
    _studentIdController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _onCodeChanged(String value) {
    _lookupDebounce?.cancel();
    setState(() {
      _lookupResult = null;
      _lookupError = null;
    });
    final code = value.trim();
    if (code.length < 6) return;
    _lookupDebounce = Timer(const Duration(milliseconds: 500), () => _lookupCode(code));
  }

  Future<void> _lookupCode(String code) async {
    setState(() => _lookingUpCode = true);
    try {
      final result = await widget.authService.lookupClass(code);
      if (!mounted || _codeController.text.trim() != code) return;
      setState(() {
        _lookupResult = result;
        _lookupError = null;
      });
    } on ApiException catch (e) {
      if (!mounted || _codeController.text.trim() != code) return;
      setState(() {
        _lookupResult = null;
        _lookupError = e.message;
      });
    } catch (_) {
      // Network hiccup -- stay quiet here, the real validation happens
      // again on submit anyway.
    } finally {
      if (mounted) setState(() => _lookingUpCode = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _errorMessage = null;
    });
    try {
      final result = await widget.authService.register(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        activationCode: _codeController.text.trim(),
        phone: _phoneController.text.trim(),
        studentNumber: _studentIdController.text.trim().toUpperCase(),
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
            '${result.pendingMessage ?? 'Your instructor needs to approve your account.'}'
            '${_lookupResult != null ? '\n\nSection: ${_lookupResult!.program} - ${_lookupResult!.section}' : ''}',
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
    return PortalLayout(
      portal: SessionRole.student,
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
              label: 'Name',
              hint: 'Enter your Full Name',
              icon: Icons.person_outline,
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Name is required' : null,
            ),
            PortalField(
              label: 'Student ID',
              hint: 'Enter your Student ID (e.g. 26-10865)',
              icon: Icons.badge_outlined,
              controller: _studentIdController,
              textCapitalization: TextCapitalization.characters,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Student ID is required' : null,
            ),
            PortalField(
              label: 'Email',
              hint: 'Enter your Email',
              icon: Icons.mail_outline,
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Email is required';
                if (!v.contains('@')) return 'Enter a valid email';
                return null;
              },
            ),
            PortalField(
              label: 'Contact Number',
              hint: 'Enter your Contact Number',
              icon: Icons.phone_outlined,
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              validator: (v) {
                final text = (v ?? '').trim();
                if (text.isEmpty) return 'Contact number is required';
                if (!RegExp(r'^[0-9+\-\s()]{7,20}$').hasMatch(text)) {
                  return 'Enter a valid contact number';
                }
                return null;
              },
            ),
            PortalField(
              label: 'Password',
              hint: 'Enter your password',
              icon: Icons.lock_outline,
              controller: _passwordController,
              isPassword: true,
              validator: (v) {
                if (v == null || v.isEmpty) return 'Password is required';
                if (v.length < 8) return 'Must be at least 8 characters';
                return null;
              },
            ),
            PortalField(
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
              label: 'Activation Code',
              hint: 'Enter Activation Code',
              icon: Icons.key_outlined,
              controller: _codeController,
              highlighted: true,
              textCapitalization: TextCapitalization.characters,
              onChanged: _onCodeChanged,
              trailing: _lookingUpCode
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : null,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? "Ask your OJT instructor for your section's code"
                  : null,
            ),
            if (_lookupResult != null)
              PortalMessage(
                error: false,
                message: "You're joining ${_lookupResult!.program} - "
                    '${_lookupResult!.section} (${_lookupResult!.academicYear}) '
                    'under ${_lookupResult!.instructorName}.',
              ),
            if (_lookupError != null) PortalMessage(message: _lookupError!),
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
