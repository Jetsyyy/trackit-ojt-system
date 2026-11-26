import 'package:flutter/material.dart';
import '../../services/admin_auth_service.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/instructor_auth_service.dart';
import '../../services/session_role.dart';
import '../../services/staff_auth_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_portal.dart';
import '../../widgets/auth/portal_layout.dart';
import '../teacher/instructor_register_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  final AuthService authService;
  final InstructorAuthService instructorAuthService;
  final AdminAuthService adminAuthService;
  final ValueChanged<SessionRole> onLoggedIn;

  const LoginScreen({
    super.key,
    required this.authService,
    required this.instructorAuthService,
    required this.adminAuthService,
    required this.onLoggedIn,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _roleStore = SessionRoleStore();
  late final _staffAuth = StaffAuthService(
    client: widget.adminAuthService.client,
    adminAuth: widget.adminAuthService,
    instructorAuth: widget.instructorAuthService,
  );
  bool _submitting = false;
  bool _rememberMe = false;
  String? _errorMessage;
  // The Student portal signs in students only; the Staff portal (/staff)
  // signs in Instructors (default) and the Admin.
  SessionRole _role = rolesFor(currentPortal).first;

  @override
  void initState() {
    super.initState();
    // An Admin invite link (.../staff?code=INS-XXXX-XXXX) opens instructor
    // sign-up with the code filled in.
    final code = Uri.base.queryParameters['code']?.trim();
    if (currentPortal == AppPortal.staff && code != null && code.toUpperCase().startsWith('INS-')) {
      _role = SessionRole.instructor;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openRegister(initialCode: code.toUpperCase());
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _switchPortal(SessionRole role) {
    if (role == _role || !rolesFor(currentPortal).contains(role)) return;
    setState(() {
      _role = role;
      _errorMessage = null;
    });
    _formKey.currentState?.reset();
  }

  /// Student Forgot Password (System Revision 4): send a reset request to
  /// the student's instructor, who gives them a temporary password.
  Future<void> _studentForgotPassword() async {
    final email = TextEditingController(text: _emailController.text.trim());
    String? message;
    String? error;
    bool sending = false;
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          icon: const Icon(Icons.lock_reset, color: AppColors.primaryMaroon, size: 32),
          title: const Text('Forgot your password?'),
          content: SizedBox(
            width: 380,
            child: message != null
                ? Text(message!)
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Enter the email you registered with. Your OJT instructor will reset your password '
                        'and give you a temporary one; you\'ll set your own after signing in.',
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: email,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.mail_outline)),
                      ),
                      if (error != null) ...[
                        const SizedBox(height: 8),
                        Text(error!, style: const TextStyle(color: AppColors.statRedIcon)),
                      ],
                    ],
                  ),
          ),
          actions: message != null
              ? [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(foregroundColor: AppColors.primaryMaroon),
                    child: const Text('OK'),
                  ),
                ]
              : [
                  TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: AppColors.primaryMaroon),
                    onPressed: sending
                        ? null
                        : () async {
                            final value = email.text.trim();
                            if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value)) {
                              setDialog(() => error = 'Enter a valid email.');
                              return;
                            }
                            setDialog(() {
                              sending = true;
                              error = null;
                            });
                            try {
                              final reply = await widget.authService.requestPasswordReset(value);
                              setDialog(() => message = reply);
                            } on ApiException catch (e) {
                              setDialog(() {
                                sending = false;
                                error = e.message;
                              });
                            } catch (_) {
                              setDialog(() {
                                sending = false;
                                error = 'Could not reach the server. Try again.';
                              });
                            }
                          },
                    child: sending
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Send request'),
                  ),
                ],
        ),
      ),
    );
    email.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _errorMessage = null;
    });
    try {
      // Staff portal: one form; the server says whether this is an Admin
      // or an Instructor account (System Revision 7).
      if (currentPortal == AppPortal.staff) {
        final role = await _staffAuth.login(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
        await _roleStore.setRemember(_rememberMe);
        if (!mounted) return;
        widget.onLoggedIn(role);
        return;
      }
      switch (_role) {
        case SessionRole.student:
          await widget.authService.login(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );
          break;
        case SessionRole.instructor:
          await widget.instructorAuthService.login(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );
          break;
        case SessionRole.admin:
          await widget.adminAuthService.login(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );
          break;
      }
      await _roleStore.setRemember(_rememberMe);
      if (!mounted) return;
      widget.onLoggedIn(_role);
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

  Future<void> _registered(SessionRole role) async {
    await _roleStore.setRemember(true);
    widget.onLoggedIn(role);
  }

  void _openRegister({String? initialCode}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _role == SessionRole.student
            ? RegisterScreen(
                authService: widget.authService,
                onRegistered: () => _registered(SessionRole.student),
              )
            : InstructorRegisterScreen(
                instructorAuthService: widget.instructorAuthService,
                onRegistered: () => _registered(SessionRole.instructor),
                initialCode: initialCode,
              ),
      ),
    );
  }

  // There's no self-service reset by email yet, so say who can help.
  void _forgotPassword() {
    if (currentPortal == AppPortal.student) {
      _studentForgotPassword();
      return;
    }
    final who = switch (_role) {
      SessionRole.student => 'your OJT instructor',
      SessionRole.instructor => 'the OJT coordinator (Admin)',
      SessionRole.admin => 'your system administrator',
    };
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.lock_reset, color: AppColors.primaryMaroon, size: 32),
        title: const Text('Forgot your password?'),
        content: Text(
          'Please contact $who to reset your password.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(foregroundColor: AppColors.primaryMaroon),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = _role == SessionRole.admin;
    return PortalLayout(
      portal: _role,
      onPortalChanged: _switchPortal,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const PortalTitle(
              title: 'Welcome Back!',
              subtitle: 'Sign in to manage OJT records and documentation.',
            ),
            if (_errorMessage != null) PortalMessage(message: _errorMessage!),
            PortalField(
              key: const ValueKey('login-email'),
              label: 'Email',
              hint: isAdmin || _role == SessionRole.instructor
                  ? 'Enter your university email'
                  : 'Enter your email',
              icon: Icons.mail_outline,
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Email is required' : null,
            ),
            PortalField(
              key: const ValueKey('login-password'),
              label: 'Password',
              hint: 'Enter your password',
              icon: Icons.lock_outline,
              controller: _passwordController,
              isPassword: true,
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Password is required' : null,
              onSubmitted: (_) => _submit(),
            ),
            Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: Checkbox(
                    value: _rememberMe,
                    activeColor: AppColors.primaryMaroon,
                    side: const BorderSide(color: Color(0xFFBDBDBD)),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    onChanged: (v) => setState(() => _rememberMe = v ?? false),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => setState(() => _rememberMe = !_rememberMe),
                  child: const Text(
                    'Remember me',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ),
                const Spacer(),
                InkWell(
                  onTap: _forgotPassword,
                  borderRadius: BorderRadius.circular(4),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      'Forgot password?',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryMaroon,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            PortalPrimaryButton(
              label: 'Sign in',
              loading: _submitting,
              onPressed: _submit,
            ),
            const SizedBox(height: 18),
            if (isAdmin) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F4F2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.primaryMaroon.withValues(alpha: 0.7)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.lock_outline, size: 16, color: AppColors.primaryMaroon),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'For authorized PLSP administrators only. Keep your '
                        'credentials secure and sign out after use.',
                        style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const PortalLinkLine(
                text: 'Need access?',
                link: 'Contact your system administrator',
              ),
            ] else
              PortalLinkLine(
                text: "Don't have an account?",
                link: 'Register',
                onTap: () => _openRegister(),
              ),
          ],
        ),
      ),
    );
  }
}
