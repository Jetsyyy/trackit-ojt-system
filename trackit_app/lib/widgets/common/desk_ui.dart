import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';

/// Shared building blocks for the wide-screen (laptop/desktop) layouts
/// that follow the TrackIT instructor mockups: warm grey page, white
/// rounded cards with a soft shadow, light-pink tiles with a thin border,
/// pink icon boxes, pill tabs and small status chips.

/// Width at which the instructor app switches to its desktop layout --
/// the same breakpoint TeacherShell uses for its side menu.
const double kDeskBreakpoint = 900;

bool isDeskLayout(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= kDeskBreakpoint;

class DeskColors {
  static const Color page = Color(0xFFF4F0EF);
  static const Color tile = Color(0xFFFFF8F7);
  static const Color tileBorder = Color(0xFFE3D5D3);
  static const Color tileSelected = Color(0xFFD9D4D3);
  static const Color iconBox = Color(0xFFF5DADA);
  static const Color maroon = Color(0xFF5C1219);
  static const Color heading = Color(0xFF3A0D14);
  static const Color muted = Color(0xFF8A8A8A);
  static const Color pinkBadge = Color(0xFFF6D6D9);
  static const Color yellowChip = Color(0xFFFCE7B8);
  static const Color yellowText = Color(0xFFB7791F);
}

String phGreeting() {
  final hour = DateTime.now().toUtc().add(const Duration(hours: 8)).hour;
  if (hour < 12) return 'Good morning';
  if (hour < 18) return 'Good afternoon';
  return 'Good evening';
}

/// "5m ago", "2 hours ago", "3 days ago".
String timeAgo(DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours} hour${diff.inHours == 1 ? '' : 's'} ago';
  if (diff.inDays < 30) return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
  final months = diff.inDays ~/ 30;
  return '$months month${months == 1 ? '' : 's'} ago';
}

/// A scrollable desktop page: big maroon title, optional subtitle, then
/// [children].
class DeskPage extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> children;
  final Widget? trailing;
  final Future<void> Function()? onRefresh;

  const DeskPage({
    super.key,
    required this.title,
    required this.children,
    this.subtitle,
    this.trailing,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    // Phones (the Admin shell's drawer layout) get tighter padding and the
    // header's trailing control under the title instead of beside it.
    final narrow = MediaQuery.sizeOf(context).width < 600;
    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: narrow ? 22 : 26,
            fontWeight: FontWeight.w800,
            color: DeskColors.heading,
            letterSpacing: -0.3,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF6B6B6B)),
          ),
        ],
      ],
    );
    final list = ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: narrow ? const EdgeInsets.fromLTRB(16, 20, 16, 24) : const EdgeInsets.fromLTRB(28, 36, 28, 28),
      children: [
        if (narrow) ...[
          heading,
          if (trailing != null) ...[const SizedBox(height: 12), Align(alignment: Alignment.centerLeft, child: trailing)],
        ] else
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [Expanded(child: heading), ?trailing],
          ),
        SizedBox(height: narrow ? 16 : 20),
        ...children,
      ],
    );
    return DeskBackdrop(
      child: onRefresh == null
          ? list
          : RefreshIndicator(color: AppColors.primaryMaroon, onRefresh: onRefresh!, child: list),
    );
  }
}

/// Warm grey page with the CCST seal very faintly in the corner (same
/// watermark as the student app).
class DeskBackdrop extends StatelessWidget {
  final Widget child;

  const DeskBackdrop({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: DeskColors.page,
      child: Stack(
        children: [
          Positioned(
            right: -90,
            bottom: -110,
            width: 640,
            height: 640,
            child: IgnorePointer(
              child: Opacity(
                opacity: 0.08,
                child: Image.asset(
                  'assets/images/ccst_seal.webp',
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stack) => const SizedBox.shrink(),
                ),
              ),
            ),
          ),
          Positioned.fill(child: child),
        ],
      ),
    );
  }
}

/// White rounded card with a soft shadow; [title] row optional.
class DeskCard extends StatelessWidget {
  final String? title;
  final IconData? titleIcon;
  final Widget? trailing;
  final Widget child;
  final EdgeInsetsGeometry padding;

  const DeskCard({
    super.key,
    required this.child,
    this.title,
    this.titleIcon,
    this.trailing,
    this.padding = const EdgeInsets.all(18),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Color(0x14000000), blurRadius: 10, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) ...[
            Row(
              children: [
                if (titleIcon != null) ...[
                  Icon(titleIcon, size: 22, color: DeskColors.heading),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    title!,
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                      color: DeskColors.heading,
                    ),
                  ),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: 14),
          ],
          child,
        ],
      ),
    );
  }
}

/// Light-pink bordered tile used for list rows inside cards.
class DeskTile extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final bool selected;
  final EdgeInsetsGeometry padding;
  final bool raised;

  const DeskTile({
    super.key,
    required this.child,
    this.onTap,
    this.selected = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    this.raised = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        boxShadow: raised
            ? const [BoxShadow(color: Color(0x22000000), blurRadius: 4, offset: Offset(0, 2))]
            : null,
      ),
      child: Material(
        color: selected ? DeskColors.tileSelected : DeskColors.tile,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: DeskColors.tileBorder),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

class DeskIconBox extends StatelessWidget {
  final IconData icon;
  final double size;

  const DeskIconBox({super.key, required this.icon, this.size = 34});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: DeskColors.iconBox, borderRadius: BorderRadius.circular(6)),
      alignment: Alignment.center,
      child: Icon(icon, size: size * 0.58, color: DeskColors.maroon),
    );
  }
}

class DeskCountBadge extends StatelessWidget {
  final int count;

  const DeskCountBadge({super.key, required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 22),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(color: DeskColors.pinkBadge, borderRadius: BorderRadius.circular(12)),
      child: Text(
        '$count',
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: DeskColors.maroon),
      ),
    );
  }
}

/// Small yellow "View All" / "7 Reports" pill.
class DeskPill extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const DeskPill({super.key, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: DeskColors.yellowChip,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          child: Text(
            label,
            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: DeskColors.yellowText),
          ),
        ),
      ),
    );
  }
}

enum DeskChipTone { green, yellow, grey, red, blue }

/// Rounded status chip: Completed / In Progress / Pending / Submitted...
class DeskStatusChip extends StatelessWidget {
  final String label;
  final DeskChipTone tone;

  const DeskStatusChip({super.key, required this.label, required this.tone});

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      DeskChipTone.green => (const Color(0xFFD5F5DD), const Color(0xFF1E8E3E)),
      DeskChipTone.yellow => (const Color(0xFFFDF0C4), const Color(0xFFB7791F)),
      DeskChipTone.grey => (const Color(0xFFE6E6E6), const Color(0xFF8A8A8A)),
      DeskChipTone.red => (const Color(0xFFFADADD), const Color(0xFFB3261E)),
      DeskChipTone.blue => (const Color(0xFFDCEBFF), const Color(0xFF2E6FD8)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: fg)),
    );
  }
}

/// Pill-shaped segmented tabs (section switcher, Official/Additional...).
class DeskSegmentedTabs extends StatelessWidget {
  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final double height;
  final double radius;

  const DeskSegmentedTabs({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onChanged,
    this.height = 44,
    this.radius = 22,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius + 4),
        border: Border.all(color: const Color(0xFFD6D6D6)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: Material(
                color: i == selectedIndex ? DeskColors.maroon : Colors.transparent,
                borderRadius: BorderRadius.circular(radius),
                child: InkWell(
                  borderRadius: BorderRadius.circular(radius),
                  onTap: () => onChanged(i),
                  child: SizedBox(
                    height: height - 8,
                    child: Center(
                      child: Text(
                        labels[i],
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: i == selectedIndex ? Colors.white : const Color(0xFF6B6B6B),
                        ),
                      ),
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

/// Circle avatar from a network photo, or initials on maroon.
class DeskAvatar extends StatelessWidget {
  final String name;
  final String? imageUrl;
  final double radius;

  const DeskAvatar({super.key, required this.name, this.imageUrl, this.radius = 18});

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    return (parts.first[0] + (parts.length > 1 ? parts.last[0] : '')).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: DeskColors.iconBox,
      foregroundImage: imageUrl != null && imageUrl!.isNotEmpty ? NetworkImage(imageUrl!) : null,
      child: Text(
        _initials,
        style: TextStyle(fontSize: radius * 0.7, fontWeight: FontWeight.w700, color: DeskColors.maroon),
      ),
    );
  }
}

/// Thin maroon progress bar with a grey track.
class DeskProgressBar extends StatelessWidget {
  final double value;
  final double height;

  const DeskProgressBar({super.key, required this.value, this.height = 6});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: LinearProgressIndicator(
        value: value.clamp(0.0, 1.0),
        minHeight: height,
        backgroundColor: const Color(0xFFE0E0E0),
        valueColor: const AlwaysStoppedAnimation(DeskColors.maroon),
      ),
    );
  }
}

/// "Showing 1 to 4 of 183 Companies   ‹ 1 2 3 4 ›" footer (admin mockups).
/// [page] is zero-based.
class DeskPager extends StatelessWidget {
  final int page;
  final int pageSize;
  final int total;
  final String noun;
  final ValueChanged<int> onChanged;

  const DeskPager({
    super.key,
    required this.page,
    required this.pageSize,
    required this.total,
    required this.noun,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final pages = total == 0 ? 1 : (total / pageSize).ceil();
    final from = total == 0 ? 0 : page * pageSize + 1;
    final to = (page * pageSize + pageSize).clamp(0, total);
    var start = (page - 2).clamp(0, (pages - 4).clamp(0, pages));
    final end = (start + 4).clamp(0, pages);
    Widget box(Widget child, {VoidCallback? onTap, bool selected = false}) => Padding(
          padding: const EdgeInsets.only(left: 5),
          child: Material(
            color: selected ? DeskColors.maroon : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(5),
              side: BorderSide(color: selected ? DeskColors.maroon : const Color(0xFFDDDDDD)),
            ),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(5),
              child: SizedBox(width: 26, height: 26, child: Center(child: child)),
            ),
          ),
        );
    return Row(
      children: [
        Expanded(
          child: Text(
            'Showing $from to $to of $total $noun',
            style: const TextStyle(fontSize: 11, color: DeskColors.muted),
          ),
        ),
        box(const Icon(Icons.chevron_left, size: 16), onTap: page > 0 ? () => onChanged(page - 1) : null),
        for (var i = start; i < end; i++)
          box(
            Text(
              '${i + 1}',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: i == page ? Colors.white : const Color(0xFF333333),
              ),
            ),
            onTap: () => onChanged(i),
            selected: i == page,
          ),
        box(const Icon(Icons.chevron_right, size: 16), onTap: page < pages - 1 ? () => onChanged(page + 1) : null),
      ],
    );
  }
}

/// Outlined filter button that opens a dropdown panel (admin mockups:
/// Location / Sections / Sort by).
class DeskFilterButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? prefix;
  final bool active;
  final MenuController controller;
  final List<Widget> menuChildren;

  const DeskFilterButton({
    super.key,
    required this.icon,
    required this.label,
    required this.controller,
    required this.menuChildren,
    this.prefix,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      controller: controller,
      alignmentOffset: const Offset(0, 4),
      style: MenuStyle(
        backgroundColor: const WidgetStatePropertyAll(Colors.white),
        shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
        padding: const WidgetStatePropertyAll(EdgeInsets.all(10)),
      ),
      menuChildren: menuChildren,
      builder: (context, c, _) => InkWell(
        onTap: () => c.isOpen ? c.close() : c.open(),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: active || c.isOpen ? const Color(0xFFFBEFF0) : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: active || c.isOpen ? DeskColors.maroon : const Color(0xFFD6D6D6)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: const Color(0xFF333333)),
              const SizedBox(width: 6),
              if (prefix != null) ...[
                Text(prefix!, style: const TextStyle(fontSize: 10.5, color: DeskColors.muted)),
                const SizedBox(width: 4),
              ],
              Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1F1F1F))),
              const SizedBox(width: 6),
              Icon(c.isOpen ? Icons.expand_less : Icons.expand_more, size: 16, color: const Color(0xFF555555)),
            ],
          ),
        ),
      ),
    );
  }
}
