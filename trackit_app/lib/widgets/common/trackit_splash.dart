import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';

/// The TrackIT loading screen shown while the app starts and checks the
/// saved sign-in: the logo on maroon with a thin orange loading bar. The
/// website shows an identical HTML version (web/index.html) before the app
/// has downloaded, so the hand-over between the two is seamless.
class TrackitSplash extends StatefulWidget {
  const TrackitSplash({super.key});

  @override
  State<TrackitSplash> createState() => _TrackitSplashState();
}

class _TrackitSplashState extends State<TrackitSplash> with TickerProviderStateMixin {
  // Logo eases in once, then "breathes" gently.
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..forward();
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat(reverse: true);
  late final AnimationController _bar = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  )..repeat();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _intro.value = 1;
      _breath.stop();
    }
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
    final intro = CurvedAnimation(parent: _intro, curve: Curves.easeOutCubic);
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
          child: Stack(
            children: [
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FadeTransition(
                      opacity: intro,
                      child: AnimatedBuilder(
                        animation: Listenable.merge([_intro, _breath]),
                        builder: (context, child) {
                          final scale = (0.9 + 0.1 * intro.value) * (1 + 0.025 * Curves.easeInOut.transform(_breath.value));
                          return Transform.scale(scale: scale, child: child);
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
                      opacity: intro,
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
                  ],
                ),
              ),
              const Positioned(
                left: 16,
                right: 16,
                bottom: 22,
                child: Column(
                  children: [
                    Text(
                      'Dalubhasaan ng Lunsod ng San Pablo',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0x99FFFFFF), fontSize: 11.5, fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'College of Computer Studies and Technology',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0x73FFFFFF), fontSize: 10.5),
                    ),
                  ],
                ),
              ),
            ],
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
