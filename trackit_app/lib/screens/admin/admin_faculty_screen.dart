import 'package:flutter/material.dart';
import '../../models/admin_instructor.dart';
import '../../services/admin_instructors_service.dart';
import '../../services/api_client.dart';
import '../../utils/app_colors.dart';
import '../../widgets/common/empty_state_view.dart';
import '../../widgets/common/skeleton_list_tile.dart';
import 'admin_instructor_detail_panel.dart';

// Same breakpoint as the Sections/Students overview -- the two tabs
// should feel like the same screen, not two differently-tuned layouts.
const _wideBreakpoint = 720.0;

/// The Faculty/Instructors side of the Admin Overview -- same list+detail
/// structure and visual style as the Sections (Students) overview it
/// sits alongside.
class AdminFacultyScreen extends StatefulWidget {
  final ApiClient client;

  /// The Academic Year selector lives in the shared header above both
  /// tabs -- this just reacts to it, the same way
  /// AdminClassManagementDetailPanel reacts to a selected section
  /// changing.
  final String? academicYear;

  const AdminFacultyScreen({super.key, required this.client, required this.academicYear});

  @override
  State<AdminFacultyScreen> createState() => _AdminFacultyScreenState();
}

class _AdminFacultyScreenState extends State<AdminFacultyScreen> {
  late final AdminInstructorsService _service = HttpAdminInstructorsService(
    widget.client,
  );
  List<AdminInstructorSummary> _instructors = [];
  bool _loading = true;
  String? _error;
  String _query = '';
  int? _selectedInstructorId;
  bool _narrowShowDetail = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final instructors = await _service.getInstructors();
      if (!mounted) return;
      setState(() {
        _instructors = instructors;
        _loading = false;
        final stillPresent = instructors.any((i) => i.id == _selectedInstructorId);
        if (!stillPresent) {
          _selectedInstructorId = instructors.isNotEmpty ? instructors.first.id : null;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  List<AdminInstructorSummary> get _filtered {
    if (_query.isEmpty) return _instructors;
    final q = _query.toLowerCase();
    return _instructors
        .where(
          (i) =>
              i.name.toLowerCase().contains(q) ||
              i.instructorNumber.toLowerCase().contains(q),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= _wideBreakpoint;
        if (_loading) return const SkeletonList();
        if (_error != null) {
          return EmptyStateView(
            icon: Icons.error_outline,
            title: 'Could not load instructors',
            message: _error!,
            actionLabel: 'Retry',
            onAction: _load,
          );
        }
        return _buildContent(isWide);
      },
    );
  }

  Widget _buildContent(bool isWide) {
    if (isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(width: 320, child: _buildListPanel(narrow: false)),
          const SizedBox(width: 16),
          Expanded(child: _buildDetailPanel()),
        ],
      );
    }

    if (_narrowShowDetail && _selectedInstructorId != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => _narrowShowDetail = false),
              icon: const Icon(Icons.arrow_back, size: 16),
              label: const Text('Back to Faculty'),
              style: TextButton.styleFrom(foregroundColor: AppColors.primaryMaroon),
            ),
          ),
          const SizedBox(height: 4),
          Expanded(child: _buildDetailPanel()),
        ],
      );
    }

    return _buildListPanel(narrow: true);
  }

  Widget _buildListPanel({required bool narrow}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Faculty List',
            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: 'Search instructor...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    filled: true,
                    fillColor: AppColors.background,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _filtered.isEmpty
                ? EmptyStateView(
                    icon: Icons.badge_outlined,
                    title: _instructors.isEmpty ? 'No instructors yet' : 'No matching instructors',
                    message: _instructors.isEmpty
                        ? 'Approved instructors appear here. Generate a registration code in the Registration Codes tab.'
                        : 'Try a different search.',
                  )
                : ListView.separated(
                    itemCount: _filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final i = _filtered[index];
                      return _InstructorListTile(
                        summary: i,
                        selected: i.id == _selectedInstructorId,
                        onTap: () => setState(() {
                          _selectedInstructorId = i.id;
                          if (narrow) _narrowShowDetail = true;
                        }),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailPanel() {
    if (_selectedInstructorId == null) {
      return Container(
        decoration: BoxDecoration(
          color: AppColors.cardWhite,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: EmptyStateView(
            icon: Icons.badge_outlined,
            title: 'Select an instructor',
            message: 'Choose an instructor on the left to view their information.',
          ),
        ),
      );
    }
    return AdminInstructorDetailPanel(
      key: ValueKey('$_selectedInstructorId-${widget.academicYear}'),
      instructorId: _selectedInstructorId!,
      academicYear: widget.academicYear,
      instructorsService: _service,
      onChanged: _load,
    );
  }
}

class _InstructorListTile extends StatelessWidget {
  final AdminInstructorSummary summary;
  final bool selected;
  final VoidCallback onTap;

  const _InstructorListTile({required this.summary, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primaryMaroon : AppColors.background,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: selected ? Colors.white.withValues(alpha: 0.2) : AppColors.cardWhite,
                backgroundImage: summary.avatarUrl != null
                    ? NetworkImage(ApiClient.resolveUrl(summary.avatarUrl!))
                    : null,
                child: summary.avatarUrl == null
                    ? Icon(
                        Icons.person_outline,
                        size: 18,
                        color: selected ? Colors.white : AppColors.primaryMaroon,
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      summary.name,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: selected ? Colors.white : AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Instructor ID: ${summary.instructorNumber}',
                      style: TextStyle(
                        fontSize: 11,
                        color: selected ? Colors.white70 : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: summary.isActive
                      ? (selected ? Colors.white.withValues(alpha: 0.2) : AppColors.successGreenBg)
                      : (selected ? Colors.white.withValues(alpha: 0.2) : AppColors.statRedBg),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  summary.isActive ? 'Active' : 'Inactive',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: selected
                        ? Colors.white
                        : (summary.isActive ? AppColors.successGreenText : AppColors.statRedIcon),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
