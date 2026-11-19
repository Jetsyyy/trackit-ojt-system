import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../utils/app_colors.dart';

/// Shared look of the student app (TrackIT student mockups): serif
/// headings, a warm grey page with the CCST seal faintly in the
/// background, the maroon header with the bell, and white cards.

class StudentColors {
  static const Color page = Color(0xFFE8E5E4);
  static const Color maroon = Color(0xFF5C1219);
  static const Color heading = Color(0xFF6B1622);
  static const Color chip = Color(0xFFE6E2E1);
  static const Color muted = Color(0xFF7A7A7A);
  static const Color approved = Color(0xFF3F9A5B);
  static const Color pending = Color(0xFFE8843A);
  static const Color declined = Color(0xFF6E1423);
}

/// Serif display style used for page titles, names and phase titles.
TextStyle studentSerif({double size = 20, Color color = Colors.black, FontWeight weight = FontWeight.w700}) =>
    GoogleFonts.crimsonPro(fontSize: size, color: color, fontWeight: weight, height: 1.1);

/// Lets any student header show the bell (opens Notifications, with the
/// unread badge) without passing callbacks through every screen.
class StudentChrome extends InheritedWidget {
  final VoidCallback onOpenNotifications;
  final Listenable unreadListenable;
  final int Function() unreadCount;

  const StudentChrome({
    super.key,
    required this.onOpenNotifications,
    required this.unreadListenable,
    required this.unreadCount,
    required super.child,
  });

  static StudentChrome? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<StudentChrome>();

  @override
  bool updateShouldNotify(StudentChrome oldWidget) => false;
}

/// Page background: warm grey with the CCST seal very faintly behind the
/// content. Opaque, so pages never show through each other mid-transition.
class StudentBackdrop extends StatelessWidget {
  final Widget child;

  const StudentBackdrop({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: StudentColors.page,
      child: Stack(
        children: [
          Positioned(
            left: -40,
            right: -40,
            bottom: -60,
            child: IgnorePointer(
              child: Opacity(
                opacity: 0.13,
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

/// The maroon page header. With [showBack] it becomes the "< Return"
/// header used by inner pages (TrackIT logo above, page name below).
class StudentHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool showBack;
  final VoidCallback? onBack;

  const StudentHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.showBack = false,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final chrome = StudentChrome.maybeOf(context);
    return Container(
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        color: AppColors.accentOrange,
        boxShadow: [BoxShadow(color: Color(0x33000000), blurRadius: 8, offset: Offset(0, 3))],
      ),
      padding: const EdgeInsets.only(bottom: 5),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                'assets/images/campus_gate.webp',
                fit: BoxFit.cover,
                alignment: const Alignment(0, -0.2),
                errorBuilder: (context, error, stack) => const SizedBox.shrink(),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      StudentColors.maroon.withValues(alpha: 0.97),
                      StudentColors.maroon.withValues(alpha: 0.85),
                    ],
                  ),
                ),
              ),
            ),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(22, showBack ? 10 : 18, 14, 18),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (showBack) ...[
                            Image.asset(
                              'assets/images/trackit_logo_white.png',
                              height: 22,
                              alignment: Alignment.centerLeft,
                              semanticLabel: 'TrackIT',
                              errorBuilder: (context, error, stack) => const SizedBox.shrink(),
                            ),
                            InkWell(
                              onTap: onBack ?? () => Navigator.of(context).maybePop(),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 22),
                                  const SizedBox(width: 4),
                                  Text('Return', style: studentSerif(size: 34, color: Colors.white)),
                                ],
                              ),
                            ),
                          ] else
                            Text(title, style: studentSerif(size: 36, color: Colors.white)),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: const TextStyle(color: Colors.white, fontSize: 12.5),
                          ),
                        ],
                      ),
                    ),
                    if (chrome != null) _Bell(chrome: chrome),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bell extends StatelessWidget {
  final StudentChrome chrome;

  const _Bell({required this.chrome});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: chrome.unreadListenable,
      builder: (context, _) {
        final count = chrome.unreadCount();
        return IconButton(
          tooltip: 'Notifications',
          onPressed: chrome.onOpenNotifications,
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.notifications_none_rounded, color: Colors.white, size: 32),
              if (count > 0)
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    decoration: const BoxDecoration(color: AppColors.accentOrange, shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: Text(
                      count > 9 ? '9+' : '$count',
                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// White card with the soft drop shadow from the mockups.
class StudentCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final VoidCallback? onTap;

  const StudentCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color = Colors.white,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 6, offset: Offset(0, 3))],
      ),
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Small rounded status pill (Approved / Re-Upload / Pending / Locked).
class StudentStatusPill extends StatelessWidget {
  final String label;
  final Color background;
  final Color foreground;

  const StudentStatusPill({super.key, required this.label, required this.background, required this.foreground});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: foreground.withValues(alpha: 0.35)),
      ),
      child: Text(label, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: foreground)),
    );
  }
}

/// Maroon numbered circle used for phases.
class PhaseNumber extends StatelessWidget {
  final int number;
  final double size;
  final bool locked;

  const PhaseNumber({super.key, required this.number, this.size = 40, this.locked = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: locked ? const Color(0xFF3A3A3A) : StudentColors.maroon,
        shape: BoxShape.circle,
        boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 3, offset: Offset(0, 1))],
      ),
      child: locked
          ? Icon(Icons.lock, color: Colors.white, size: size * 0.42)
          : Text('$number', style: TextStyle(color: Colors.white, fontSize: size * 0.45, fontWeight: FontWeight.w600)),
    );
  }
}
