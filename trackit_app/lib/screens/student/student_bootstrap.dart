import 'package:flutter/material.dart';
import '../../models/ojt_progress.dart';
import '../../models/student.dart';
import '../../models/student_profile.dart';
import '../../services/api_client.dart';
import '../../services/progress_service.dart';
import '../../services/student_profile_service.dart';
import '../../utils/app_colors.dart';
import 'student_shell.dart';

/// Fetches everything StudentShell needs in one shot right after login,
/// so the shell itself can stay a plain StatefulWidget instead of every
/// tab independently juggling "am I still loading the logged-in user".
class StudentBootstrap extends StatefulWidget {
  final ApiClient client;
  final VoidCallback onLoggedOut;

  const StudentBootstrap({
    super.key,
    required this.client,
    required this.onLoggedOut,
  });

  @override
  State<StudentBootstrap> createState() => _StudentBootstrapState();
}

class _StudentBootstrapState extends State<StudentBootstrap> {
  late Future<_BootstrapData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_BootstrapData> _load() async {
    final profileService = HttpStudentProfileService(widget.client);
    final progressService = HttpProgressService(widget.client);

    final results = await Future.wait([
      profileService.getProfile(),
      progressService.getProgress(),
    ]);

    final profile = results[0] as StudentProfile;
    return _BootstrapData(
      student: Student.fromProfile(profile),
      progress: results[1] as OjtProgress,
    );
  }

  void _retry() {
    setState(() => _future = _load());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_BootstrapData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            backgroundColor: AppColors.background,
            body: Center(
              child: CircularProgressIndicator(color: AppColors.primaryMaroon),
            ),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: AppColors.background,
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 40,
                      color: AppColors.statRedIcon,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Could not load your account.\n${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        OutlinedButton(
                          onPressed: widget.onLoggedOut,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primaryMaroon,
                            side: const BorderSide(
                              color: AppColors.primaryMaroon,
                            ),
                          ),
                          child: const Text('Back to Login'),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: _retry,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryMaroon,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final data = snapshot.data!;
        return StudentShell(
          client: widget.client,
          student: data.student,
          initialProgress: data.progress,
          onLoggedOut: widget.onLoggedOut,
        );
      },
    );
  }
}

class _BootstrapData {
  final Student student;
  final OjtProgress progress;

  const _BootstrapData({required this.student, required this.progress});
}
