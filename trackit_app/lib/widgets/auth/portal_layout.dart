import 'package:flutter/material.dart';
import '../../utils/app_portal.dart';
import '../../services/session_role.dart';
import '../../utils/app_colors.dart';

/// Shared look of the login and register screens (the TrackIT portal
/// design): on a wide screen a maroon campus panel on the left with a
/// curved edge and the form on the right; on a phone the panel becomes a
/// rounded header above the form.

const double _desktopBreakpoint = 900;
const Color _panelMaroon = Color(0xFF5C1219);
const Color _fieldBorder = Color(0xFFDDDDDD);

String portalLabel(SessionRole role) {
  switch (role) {
    case SessionRole.student:
      return 'STUDENT PORTAL';
    case SessionRole.instructor:
      return 'INSTRUCTOR PORTAL';
    case SessionRole.admin:
      return 'ADMIN PORTAL';
  }
}

IconData _portalIcon(SessionRole role) {
  switch (role) {
    case SessionRole.student:
      return Icons.school_outlined;
    case SessionRole.instructor:
      return Icons.co_present_outlined;
    case SessionRole.admin:
      return Icons.admin_panel_settings_outlined;
  }
}

class PortalLayout extends StatelessWidget {
  final SessionRole portal;

  /// When set, the portal label becomes a menu to switch portals (login
  /// screen). Register screens leave it null.
  final ValueChanged<SessionRole>? onPortalChanged;

  /// Shows a back arrow (register screens).
  final VoidCallback? onBack;
  final Widget child;

  const PortalLayout({
    super.key,
    required this.portal,
    required this.child,
    this.onPortalChanged,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= _desktopBreakpoint) {
            return _DesktopLayout(
              portal: portal,
              onPortalChanged: onPortalChanged,
              onBack: onBack,
              child: child,
            );
          }
          return _MobileLayout(
            portal: portal,
            onPortalChanged: onPortalChanged,
            onBack: onBack,
            child: child,
          );
        },
      ),
    );
  }
}

class _DesktopLayout extends StatelessWidget {
  final SessionRole portal;
  final ValueChanged<SessionRole>? onPortalChanged;
  final VoidCallback? onBack;
  final Widget child;

  const _DesktopLayout({
    required this.portal,
    required this.onPortalChanged,
    required this.onBack,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final panelWidth = constraints.maxWidth * 0.5;
        return Stack(
          children: [
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: panelWidth,
              child: ClipPath(
                clipper: _CurvedEdgeClipper(),
                child: _CampusPanel(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(40, 32, panelWidth * 0.18, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _SchoolHeader(sealSize: 56, titleSize: 15),
                        Expanded(
                          child: Center(
                            child: _Brand(logoWidth: (panelWidth * 0.62).clamp(240.0, 400.0)),
                          ),
                        ),
                        _PortalSwitcher(
                          portal: portal,
                          onChanged: onPortalChanged,
                          pill: false,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: panelWidth,
              right: 0,
              top: 0,
              bottom: 0,
              child: SafeArea(
                child: Column(
                  children: [
                    if (onBack != null)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: IconButton(
                            tooltip: 'Back to sign in',
                            onPressed: onBack,
                            icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
                          ),
                        ),
                      ),
                    Expanded(
                      child: Center(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 380),
                            child: child,
                          ),
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.only(bottom: 20),
                      child: _PortalFooter(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MobileLayout extends StatelessWidget {
  final SessionRole portal;
  final ValueChanged<SessionRole>? onPortalChanged;
  final VoidCallback? onBack;
  final Widget child;

  const _MobileLayout({
    required this.portal,
    required this.onPortalChanged,
    required this.onBack,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: MediaQuery.sizeOf(context).height),
        child: IntrinsicHeight(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(36)),
                child: _CampusPanel(
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              if (onBack != null)
                                IconButton(
                                  tooltip: 'Back to sign in',
                                  onPressed: onBack,
                                  visualDensity: VisualDensity.compact,
                                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                                ),
                              const Expanded(child: _SchoolHeader(sealSize: 34, titleSize: 12.5)),
                            ],
                          ),
                          const SizedBox(height: 18),
                          const _Brand(logoWidth: 170),
                          const SizedBox(height: 14),
                          _PortalSwitcher(portal: portal, onChanged: onPortalChanged, pill: true),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 28, 28, 16),
                child: child,
              ),
              const Spacer(),
              const Padding(
                padding: EdgeInsets.only(top: 12, bottom: 20),
                child: _PortalFooter(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The campus photo under a maroon tint, lighter towards the bottom so the
/// building shows through like in the design.
class _CampusPanel extends StatelessWidget {
  final Widget child;

  const _CampusPanel({required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.passthrough,
      children: [
        Positioned.fill(
          child: Image.asset(
            'assets/images/campus_gate.webp',
            fit: BoxFit.cover,
            alignment: const Alignment(-0.2, 0.4),
            errorBuilder: (context, error, stack) => const ColoredBox(color: _panelMaroon),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  _panelMaroon.withValues(alpha: 0.99),
                  _panelMaroon.withValues(alpha: 0.93),
                  _panelMaroon.withValues(alpha: 0.72),
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _SchoolHeader extends StatelessWidget {
  final double sealSize;
  final double titleSize;

  const _SchoolHeader({required this.sealSize, required this.titleSize});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: sealSize,
          height: sealSize,
          padding: EdgeInsets.all(sealSize * 0.06),
          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
          child: Image.asset('assets/images/dlsp_seal.png'),
        ),
        SizedBox(width: sealSize * 0.25),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Dalubhasaan ng Lunsod ng San Pablo',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: titleSize,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'College of Computer Studies and Technology',
                style: TextStyle(color: Colors.white70, fontSize: titleSize * 0.72),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Brand extends StatelessWidget {
  final double logoWidth;

  const _Brand({required this.logoWidth});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/images/trackit_logo_white.png',
          width: logoWidth,
          semanticLabel: 'TrackIT',
        ),
        SizedBox(height: logoWidth * 0.02),
        Text(
          'OJT TRACKING SYSTEM',
          style: TextStyle(
            color: Colors.white,
            fontSize: logoWidth * 0.082,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
          ),
        ),
      ],
    );
  }
}

class _PortalSwitcher extends StatelessWidget {
  final SessionRole portal;
  final bool pill;

  const _PortalSwitcher({required this.portal, required ValueChanged<SessionRole>? onChanged, required this.pill})
      : _onChanged = onChanged;

  final ValueChanged<SessionRole>? _onChanged;

  // Only this portal's roles are offered; the Student portal has just one,
  // so its label is plain text, not a menu.
  ValueChanged<SessionRole>? get onChanged =>
      rolesFor(currentPortal).length > 1 ? _onChanged : null;

  @override
  Widget build(BuildContext context) {
    final label = pill
        ? Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              border: Border.all(color: Colors.white54),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_portalIcon(portal), size: 15, color: AppColors.accentOrange),
                const SizedBox(width: 6),
                Text(
                  portalLabel(portal),
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                ),
                if (onChanged != null) ...[
                  const SizedBox(width: 2),
                  const Icon(Icons.arrow_drop_down, size: 18, color: Colors.white70),
                ],
              ],
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                portalLabel(portal),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  decoration: TextDecoration.underline,
                  decorationColor: Colors.white,
                  decorationThickness: 1.5,
                ),
              ),
              if (onChanged != null) ...[
                const SizedBox(width: 4),
                const Icon(Icons.arrow_drop_down, color: Colors.white70),
              ],
            ],
          );

    if (onChanged == null) return label;
    return PopupMenuButton<SessionRole>(
      tooltip: 'Switch portal',
      onSelected: onChanged,
      position: pill ? PopupMenuPosition.under : PopupMenuPosition.over,
      itemBuilder: (context) => [
        for (final role in rolesFor(currentPortal))
          PopupMenuItem(
            value: role,
            child: Row(
              children: [
                Icon(_portalIcon(role), size: 18, color: AppColors.primaryMaroon),
                const SizedBox(width: 10),
                Text(
                  portalLabel(role),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: role == portal ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
      ],
      child: label,
    );
  }
}

class _PortalFooter extends StatelessWidget {
  const _PortalFooter();

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(fontSize: 11, color: AppColors.textSecondary);
    return const Column(
      children: [
        Text('© 2026 PLSP · TrackIT', style: style),
        SizedBox(height: 6),
        Text('Privacy policy   ·   Help & support', style: style),
      ],
    );
  }
}

/// Left panel's right edge: dips inward through the middle and comes back
/// out at the bottom, like the design's curve.
class _CurvedEdgeClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    return Path()
      ..moveTo(0, 0)
      ..lineTo(w, 0)
      ..cubicTo(w * 0.84, h * 0.30, w * 0.84, h * 0.72, w * 0.97, h)
      ..lineTo(0, h)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

// ---------------- Form pieces ----------------

class PortalTitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const PortalTitle({super.key, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= _desktopBreakpoint;
    return Column(
      crossAxisAlignment: wide ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Text(
          title,
          textAlign: wide ? TextAlign.start : TextAlign.center,
          style: TextStyle(
            fontSize: wide ? 38 : 22,
            height: 1.1,
            fontWeight: FontWeight.w800,
            color: AppColors.primaryMaroon,
            letterSpacing: -0.5,
          ),
        ),
        SizedBox(height: wide ? 12 : 6),
        Text(
          subtitle,
          textAlign: wide ? TextAlign.start : TextAlign.center,
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        SizedBox(height: wide ? 28 : 20),
      ],
    );
  }
}

class PortalField extends StatefulWidget {
  final String label;
  final String hint;
  final IconData icon;
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final bool isPassword;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final Widget? trailing;

  /// The design's activation code field is outlined in maroon.
  final bool highlighted;

  const PortalField({
    super.key,
    required this.label,
    required this.hint,
    required this.icon,
    required this.controller,
    this.validator,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.isPassword = false,
    this.onChanged,
    this.onSubmitted,
    this.trailing,
    this.highlighted = false,
  });

  @override
  State<PortalField> createState() => _PortalFieldState();
}

class _PortalFieldState extends State<PortalField> {
  bool _obscure = true;

  OutlineInputBorder _border(Color color, [double width = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: color, width: width),
      );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.label,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: widget.controller,
            validator: widget.validator,
            keyboardType: widget.keyboardType,
            textCapitalization: widget.textCapitalization,
            obscureText: widget.isPassword && _obscure,
            onChanged: widget.onChanged,
            onFieldSubmitted: widget.onSubmitted,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            style: const TextStyle(fontSize: 13.5, color: AppColors.textPrimary),
            decoration: InputDecoration(
              isDense: true,
              hintText: widget.hint,
              hintStyle: TextStyle(
                fontSize: 13,
                color: widget.highlighted ? AppColors.primaryMaroon : const Color(0xFF9A9A9A),
              ),
              prefixIcon: widget.highlighted
                  ? null
                  : Icon(widget.icon, size: 18, color: const Color(0xFF8A8A8A)),
              suffixIcon: widget.trailing ??
                  (widget.isPassword
                      ? IconButton(
                          tooltip: _obscure ? 'Show password' : 'Hide password',
                          icon: Icon(
                            _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            size: 19,
                            color: const Color(0xFF6A6A6A),
                          ),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        )
                      : null),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
              enabledBorder: _border(widget.highlighted ? AppColors.primaryMaroon : _fieldBorder),
              focusedBorder: _border(AppColors.primaryMaroon, 1.4),
              errorBorder: _border(AppColors.statRedIcon),
              focusedErrorBorder: _border(AppColors.statRedIcon, 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class PortalPrimaryButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback? onPressed;

  const PortalPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryMaroon,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.primaryMaroon.withValues(alpha: 0.7),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward, size: 17),
                ],
              ),
      ),
    );
  }
}

class PortalMessage extends StatelessWidget {
  final String message;
  final bool error;
  final IconData? icon;

  const PortalMessage({super.key, required this.message, this.error = true, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: error ? AppColors.statRedBg : AppColors.successGreenBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon ?? (error ? Icons.error_outline : Icons.check_circle),
            size: 18,
            color: error ? AppColors.statRedIcon : AppColors.successGreenText,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: error ? AppColors.statRedIcon : AppColors.successGreenText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Don't have an account? Register" style line.
class PortalLinkLine extends StatelessWidget {
  final String text;
  final String link;
  final VoidCallback? onTap;

  const PortalLinkLine({super.key, required this.text, required this.link, this.onTap});

  @override
  Widget build(BuildContext context) {
    final linkText = Text(
      link,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: AppColors.primaryMaroon,
      ),
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('$text ', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        if (onTap == null)
          linkText
        else
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(4),
            child: Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: linkText),
          ),
      ],
    );
  }
}
