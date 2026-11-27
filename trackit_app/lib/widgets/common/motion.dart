import 'package:flutter/material.dart';

/// Small, shared motion effects so TrackIT feels smooth without getting in
/// the way. Every effect is short (under ~0.5 s) and is skipped when the
/// device asks for reduced motion.

bool _reduceMotion(BuildContext context) => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

/// Page transition for every pushed screen: a quick fade with a slight rise.
class FadeRisePageTransitionsBuilder extends PageTransitionsBuilder {
  const FadeRisePageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.035), end: Offset.zero).animate(curved),
        child: child,
      ),
    );
  }
}

/// The app's page transitions on every platform.
const fadeRisePageTransitions = PageTransitionsTheme(
  builders: {
    TargetPlatform.android: FadeRisePageTransitionsBuilder(),
    TargetPlatform.iOS: FadeRisePageTransitionsBuilder(),
    TargetPlatform.windows: FadeRisePageTransitionsBuilder(),
    TargetPlatform.macOS: FadeRisePageTransitionsBuilder(),
    TargetPlatform.linux: FadeRisePageTransitionsBuilder(),
    TargetPlatform.fuchsia: FadeRisePageTransitionsBuilder(),
  },
);

/// An [IndexedStack] (every tab stays alive) that fades and lifts the tab
/// in whenever [index] changes.
class FadeIndexedStack extends StatefulWidget {
  final int index;
  final List<Widget> children;

  const FadeIndexedStack({super.key, required this.index, required this.children});

  @override
  State<FadeIndexedStack> createState() => _FadeIndexedStackState();
}

class _FadeIndexedStackState extends State<FadeIndexedStack> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
    value: 1,
  );
  late final Animation<double> _curve = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);

  @override
  void didUpdateWidget(FadeIndexedStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index && !_reduceMotion(context)) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _curve,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.015), end: Offset.zero).animate(_curve),
        child: IndexedStack(index: widget.index, children: widget.children),
      ),
    );
  }
}

/// Fades and slides [child] up into place once, when it first appears.
/// Give neighbouring items increasing [order] values for a staggered,
/// one-after-another entrance.
class EntranceFade extends StatefulWidget {
  final Widget child;
  final int order;

  const EntranceFade({super.key, required this.child, this.order = 0});

  @override
  State<EntranceFade> createState() => _EntranceFadeState();
}

class _EntranceFadeState extends State<EntranceFade> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );
  late final Animation<double> _curve = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_reduceMotion(context)) {
        _controller.value = 1;
        return;
      }
      // Cap the delay so long lists don't keep the user waiting.
      final delay = Duration(milliseconds: 60 * widget.order.clamp(0, 8));
      Future.delayed(delay, () {
        if (mounted) _controller.forward();
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _curve,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero).animate(_curve),
        child: widget.child,
      ),
    );
  }
}

/// Gives a tappable card a gentle lift on hover (desktop/web) and a slight
/// press-in when tapped.
class HoverLift extends StatefulWidget {
  final Widget child;
  const HoverLift({super.key, required this.child});

  @override
  State<HoverLift> createState() => _HoverLiftState();
}

class _HoverLiftState extends State<HoverLift> {
  bool _hover = false;
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final scale = _down ? 0.985 : 1.0;
    final dy = _hover && !_down ? -2.0 : 0.0;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() {
        _hover = false;
        _down = false;
      }),
      child: Listener(
        onPointerDown: (_) => setState(() => _down = true),
        onPointerUp: (_) => setState(() => _down = false),
        onPointerCancel: (_) => setState(() => _down = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          transform: Matrix4.translationValues(0, dy, 0)..scale(scale, scale),
          transformAlignment: Alignment.center,
          child: widget.child,
        ),
      ),
    );
  }
}

/// Wraps each item in an [EntranceFade] with increasing order, so the items
/// appear one after another. An item that changes type (e.g. a loading
/// spinner replaced by the real content) animates in again.
List<Widget> staggered(List<Widget> items, {int startOrder = 0}) => [
  for (var i = 0; i < items.length; i++)
    EntranceFade(
      key: ValueKey('stagger-$i-${items[i].runtimeType}'),
      order: startOrder + i,
      child: items[i],
    ),
];

/// A [Column] whose children enter one after another (see [staggered]).
class StaggeredColumn extends StatelessWidget {
  final List<Widget> children;
  final CrossAxisAlignment crossAxisAlignment;
  final MainAxisAlignment mainAxisAlignment;
  final MainAxisSize mainAxisSize;

  const StaggeredColumn({
    super.key,
    required this.children,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.mainAxisSize = MainAxisSize.max,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: crossAxisAlignment,
    mainAxisAlignment: mainAxisAlignment,
    mainAxisSize: mainAxisSize,
    children: staggered(children),
  );
}
