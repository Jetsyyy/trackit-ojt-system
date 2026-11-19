import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';

/// One sidebar entry: a page ([index]) or a group with sub-pages.
class SidebarEntry {
  final IconData icon;
  final String label;
  final int? index;
  final List<SidebarEntry> children;

  const SidebarEntry.page(this.icon, this.label, int this.index) : children = const [];
  const SidebarEntry.group(this.icon, this.label, this.children) : index = null;

  bool contains(int i) => index == i || children.any((c) => c.contains(i));
}

/// The TrackIT web sidebar (instructor/admin mockups): logo, WORKSPACE,
/// items with an orange bar on the selected one, expandable groups, and
/// the signed-in account with Log out at the bottom.
class TrackitSidebar extends StatefulWidget {
  final List<SidebarEntry> entries;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final String accountName;
  final String accountRole;
  final ImageProvider? accountImage;
  final VoidCallback onLogout;

  const TrackitSidebar({
    super.key,
    required this.entries,
    required this.selectedIndex,
    required this.onSelect,
    required this.accountName,
    required this.accountRole,
    required this.onLogout,
    this.accountImage,
  });

  @override
  State<TrackitSidebar> createState() => _TrackitSidebarState();
}

class _TrackitSidebarState extends State<TrackitSidebar> {
  final Set<String> _open = {};

  static const _divider = Divider(height: 1, thickness: 1, color: Color(0x33FFFFFF));

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      color: const Color(0xFF5C1219),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Image.asset('assets/images/trackit_logo_white.png', width: 130, semanticLabel: 'TrackIT'),
                  const Padding(
                    padding: EdgeInsets.only(left: 48),
                    child: Text(
                      'OJT TRACKING SYSTEM',
                      style: TextStyle(color: Colors.white70, fontSize: 7.5, fontWeight: FontWeight.w700, letterSpacing: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            const Padding(padding: EdgeInsets.symmetric(horizontal: 18), child: _divider),
            const Padding(
              padding: EdgeInsets.fromLTRB(22, 22, 22, 10),
              child: Text(
                'WORKSPACE',
                style: TextStyle(color: Colors.white60, fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 0.8),
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  for (final e in widget.entries) ..._entry(e),
                ],
              ),
            ),
            const Padding(padding: EdgeInsets.symmetric(horizontal: 18), child: _divider),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.white,
                    foregroundImage: widget.accountImage,
                    child: Text(
                      widget.accountName.isEmpty ? '?' : widget.accountName.trim()[0].toUpperCase(),
                      style: const TextStyle(color: AppColors.primaryMaroon, fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.accountName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                        Text(widget.accountRole, style: const TextStyle(color: Colors.white70, fontSize: 10.5)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
              child: OutlinedButton.icon(
                onPressed: widget.onLogout,
                icon: const Icon(Icons.logout, size: 17),
                label: const Text('Log out'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Color(0x55FFFFFF)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _entry(SidebarEntry e) {
    if (e.children.isEmpty) {
      return [
        _Item(
          icon: e.icon,
          label: e.label,
          selected: widget.selectedIndex == e.index,
          onTap: () => widget.onSelect(e.index!),
        ),
      ];
    }
    final open = _open.contains(e.label) || e.contains(widget.selectedIndex);
    return [
      _Item(
        icon: e.icon,
        label: e.label,
        selected: false,
        trailing: Icon(open ? Icons.expand_less : Icons.expand_more, size: 18, color: Colors.white70),
        onTap: () => setState(() {
          if (!_open.remove(e.label)) _open.add(e.label);
        }),
      ),
      if (open)
        for (final c in e.children)
          _Item(
            icon: null,
            label: c.label,
            selected: widget.selectedIndex == c.index,
            indent: true,
            onTap: () => widget.onSelect(c.index!),
          ),
    ];
  }
}

class _Item extends StatelessWidget {
  final IconData? icon;
  final String label;
  final bool selected;
  final bool indent;
  final Widget? trailing;
  final VoidCallback onTap;

  const _Item({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.indent = false,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 2, 18, 2),
      child: Row(
        children: [
          Container(
            width: 3,
            height: indent ? 34 : 38,
            decoration: BoxDecoration(
              color: selected ? AppColors.accentOrange : Colors.transparent,
              borderRadius: const BorderRadius.horizontal(right: Radius.circular(3)),
            ),
          ),
          SizedBox(width: indent ? 15 : 15),
          Expanded(
            child: Material(
              color: selected ? Colors.white.withValues(alpha: 0.12) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: onTap,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(indent ? 30 : 12, indent ? 8 : 10, 12, indent ? 8 : 10),
                  child: Row(
                    children: [
                      if (icon != null) ...[
                        Icon(icon, size: 20, color: selected ? Colors.white : Colors.white70),
                        const SizedBox(width: 14),
                      ],
                      Expanded(
                        child: Text(
                          label,
                          style: TextStyle(
                            color: selected ? Colors.white : Colors.white70,
                            fontSize: indent ? 12.5 : 13.5,
                            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ),
                      ?trailing,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
