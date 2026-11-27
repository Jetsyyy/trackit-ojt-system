import 'package:flutter/material.dart';
import '../../widgets/common/motion.dart';
import '../../models/admin_profile.dart';
import '../../services/api_client.dart';
import '../../utils/app_colors.dart';
import '../../widgets/common/desk_ui.dart';
import '../../widgets/common/trackit_sidebar.dart';
import 'admin_profile_screen.dart';
import 'admin_requirements_screen.dart';
import 'desk/admin_announcements_desk.dart';
import 'desk/admin_archive_desk.dart';
import 'desk/admin_dashboard_desk.dart';
import 'desk/admin_documents_desk.dart';
import 'desk/admin_faculty_desk.dart';
import 'desk/admin_hte_directory_desk.dart';

// Page indexes.
const _dashboard = 0;
const _hteDirectory = 1;
const _faculty = 2;
const _requirements = 3;
const _announcements = 4;
const _archive = 5;
const _profile = 6;

/// Sidebar layout from the TrackIT admin mockups. Management groups the HTE
/// Directory, Faculty and Documents (the Official Requirements list, which
/// only the Admin manages -- System Revisions item 15).
const _entries = [
  SidebarEntry.page(Icons.grid_view_outlined, 'Dashboard', _dashboard),
  SidebarEntry.group(Icons.business_center_outlined, 'Management', [
    SidebarEntry.page(Icons.apartment_outlined, 'HTE Directory', _hteDirectory),
    SidebarEntry.page(Icons.groups_outlined, 'Faculty', _faculty),
    SidebarEntry.page(Icons.description_outlined, 'Documents', _requirements),
  ]),
  SidebarEntry.page(Icons.campaign_outlined, 'Announcements', _announcements),
  SidebarEntry.page(Icons.inventory_2_outlined, 'Archive', _archive),
  SidebarEntry.page(Icons.person_outline, 'Profile', _profile),
];

const _titles = [
  'Dashboard',
  'HTE Directory',
  'Faculty',
  'Documents',
  'Announcements',
  'Archive',
  'Profile',
];

/// The Admin web shell: the TrackIT sidebar next to the page. On a narrow
/// window the sidebar becomes a Drawer.
class AdminShell extends StatefulWidget {
  final ApiClient client;
  final AdminProfile initialProfile;
  final VoidCallback onLoggedOut;

  const AdminShell({
    super.key,
    required this.client,
    required this.initialProfile,
    required this.onLoggedOut,
  });

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _index = _dashboard;
  late AdminProfile _admin = widget.initialProfile;

  void _updateAdmin(AdminProfile profile) => setState(() => _admin = profile);

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You will need to sign in again to use TrackIT.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryMaroon, foregroundColor: Colors.white),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (confirmed == true) widget.onLoggedOut();
  }

  Widget _sidebar({bool inDrawer = false}) {
    return TrackitSidebar(
      entries: _entries,
      selectedIndex: _index,
      onSelect: (i) {
        setState(() => _index = i);
        if (inDrawer) Navigator.of(context).pop();
      },
      accountName: _admin.name,
      accountRole: 'SIPP Coordinator',
      accountImage: _admin.avatarUrl != null
          ? NetworkImage(ApiClient.resolveUrl(_admin.avatarUrl!))
          : const AssetImage('assets/images/ccst_seal.webp') as ImageProvider,
      onLogout: () {
        if (inDrawer) Navigator.of(context).pop();
        _confirmLogout();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // The older Official Requirements list (narrow windows) keeps its layout,
    // padded onto the warm page background.
    Widget padded(Widget child) => DeskBackdrop(
          child: Padding(padding: const EdgeInsets.fromLTRB(28, 28, 28, 20), child: child),
        );
    final pages = [
      AdminDashboardDesk(
        client: widget.client,
        adminName: _admin.name,
        onOpenHteDirectory: () => setState(() => _index = _hteDirectory),
      ),
      AdminHteDirectoryDesk(client: widget.client),
      AdminFacultyDesk(client: widget.client),
      // Wide screens get the Documents page; narrow ones keep the list view.
      isDeskLayout(context)
          ? AdminDocumentsDesk(client: widget.client)
          : padded(AdminRequirementsScreen(client: widget.client)),
      AdminAnnouncementsDesk(client: widget.client),
      AdminArchiveDesk(client: widget.client, adminEmail: _admin.email),
      AdminProfileScreen(client: widget.client, admin: _admin, onProfileUpdated: _updateAdmin),
    ];
    final body = FadeIndexedStack(index: _index, children: pages);

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= kDeskBreakpoint) {
          return Scaffold(
            backgroundColor: DeskColors.page,
            body: Row(children: [_sidebar(), Expanded(child: body)]),
          );
        }
        return Scaffold(
          backgroundColor: DeskColors.page,
          appBar: AppBar(
            backgroundColor: const Color(0xFF5C1219),
            foregroundColor: Colors.white,
            title: Text(_titles[_index]),
          ),
          drawer: Drawer(child: _sidebar(inDrawer: true)),
          body: body,
        );
      },
    );
  }
}
