import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';

/// The TrackIT loading screen shown while the app starts and checks the
/// saved sign-in. It plays in two beats: the logo pops in, then the school
/// name slides up from the bottom into place under it; a thin orange bar
/// keeps sweeping meanwhile.
///
/// The website shows an identical HTML version (web/index.html) that plays
/// the same animation while the app downloads, so there [playIntro] is
/// false and this appears already in its final pose underneath: the swap
/// between the two can't be seen and nothing plays twice.
class TrackitSplash extends StatefulWidget {
  final bool playIntro;

  const TrackitSplash({super.key, this.playIntro = true});

  /// How long the intro takes, so callers can keep the splash up for it.
  static const introDuration = Duration(milliseconds: 1700);

  @override
  State<TrackitSplash> createState() => _TrackitSplashState();
}

class _TrackitSplashState extends State<TrackitSplash> with TickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: TrackitSplash.introDuration,
  );
  // After the intro the logo "breathes" gently.
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );
  late final AnimationController _bar = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  )..repeat();

  // Beat 1: the logo pops in with a small overshoot.
  late final Animation<double> _logoScale = Tween(begin: 0.55, end: 1.0).animate(
    CurvedAnimation(parent: _intro, curve: const Interval(0, 0.38, curve: Curves.easeOutBack)),
  );
  late final Animation<double> _logoFade = CurvedAnimation(parent: _intro, curve: const Interval(0, 0.2));
  // Loading bar and "OJT TRACKING SYSTEM" fade in just after.
  late final Animation<double> _tagFade = CurvedAnimation(
    parent: _intro,
    curve: const Interval(0.25, 0.55, curve: Curves.easeOut),
  );
  // Beat 2: the school name rises from the bottom into the middle.
  late final Animation<Offset> _schoolRise = Tween(begin: const Offset(0, 7), end: Offset.zero).animate(
    CurvedAnimation(parent: _intro, curve: const Interval(0.52, 1, curve: Curves.easeOutCubic)),
  );
  late final Animation<double> _schoolFade = CurvedAnimation(
    parent: _intro,
    curve: const Interval(0.52, 0.85, curve: Curves.easeOut),
  );

  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (!widget.playIntro || reduceMotion) {
      _intro.value = 1;
      return;
    }
    _intro.forward().then((_) {
      if (mounted) _breath.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _intro.dispose();
    _breath.dispose();
    _bar.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final logoWidth = width < 500 ? 210.0 : 250.0;
    return Scaffold(
      backgroundColor: AppColors.primaryMaroonDark,
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.15),
            radius: 1.1,
            colors: [Color(0xFF8A1E30), AppColors.primaryMaroon, AppColors.primaryMaroonDark],
            stops: [0, 0.45, 1],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FadeTransition(
                    opacity: _logoFade,
                    child: AnimatedBuilder(
                      animation: Listenable.merge([_logoScale, _breath]),
                      builder: (context, child) {
                        final breath = 1 + 0.025 * Curves.easeInOut.transform(_breath.value);
                        return Transform.scale(scale: _logoScale.value * breath, child: child);
                      },
                      child: Image.asset(
                        'assets/images/trackit_logo_white.png',
                        width: logoWidth,
                        semanticLabel: 'TrackIT',
                      ),
                    ),
                  ),
                  const SizedBox(height: 26),
                  FadeTransition(
                    opacity: _tagFade,
                    child: Column(
                      children: [
                        _LoadingBar(animation: _bar),
                        const SizedBox(height: 16),
                        const Text(
                          'OJT TRACKING SYSTEM',
                          style: TextStyle(
                            color: Color(0xCCFFFFFF),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                  FadeTransition(
                    opacity: _schoolFade,
                    child: SlideTransition(
                      position: _schoolRise,
                      child: const Column(
                        children: [
                          Text(
                            'Dalubhasaan ng Lunsod ng San Pablo',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Color(0xE6FFFFFF), fontSize: 13.5, fontWeight: FontWeight.w700),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'College of Computer Studies and Technology',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Color(0xA6FFFFFF), fontSize: 11.5),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A slim track with an orange segment sweeping across it.
class _LoadingBar extends StatelessWidget {
  final Animation<double> animation;
  const _LoadingBar({required this.animation});

  @override
  Widget build(BuildContext context) {
    const trackWidth = 132.0;
    const segment = 46.0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: Container(
        width: trackWidth,
        height: 3,
        color: const Color(0x33FFFFFF),
        child: AnimatedBuilder(
          animation: animation,
          builder: (context, _) {
            final t = Curves.easeInOut.transform(animation.value);
            return Stack(
              children: [
                Positioned(
                  left: -segment + t * (trackWidth + segment),
                  top: 0,
                  bottom: 0,
                  width: segment,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.accentOrange,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
