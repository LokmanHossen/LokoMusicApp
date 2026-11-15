import 'package:flutter/material.dart';
import 'package:pulse_music/core/theme/app_theme.dart';

/// Opaque app background with a faint guitar silhouette, painted behind
/// every page. Scaffolds use a transparent background (see AppTheme), so
/// this shows through on all screens.
///
/// Each page gets its own copy (via [BackdropPageTransitionsBuilder]), so
/// pages stay opaque during route transitions and never show the page below.
class AppBackdrop extends StatelessWidget {
  const AppBackdrop({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ColoredBox(
      color: dark ? AppColors.bg : AppColors.bgLight,
      child: Stack(fit: StackFit.expand, children: [
        const _GuitarWatermark(),
        child,
      ]),
    );
  }
}

/// Large, tilted silhouette of the brand guitar, tinted and very faint.
/// Decorative only: ignores taps and is hidden from screen readers.
class _GuitarWatermark extends StatelessWidget {
  const _GuitarWatermark();

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.sizeOf(context);
    final side = size.width * 1.05;
    return Positioned(
      // Raise toward 0 (or positive) to move the guitar further left.
      right: -side * 0.05,
      bottom: size.height * 0.08,
      child: IgnorePointer(
        child: ExcludeSemantics(
          child: RepaintBoundary(
            child: Transform.rotate(
              angle: -0.35,
              child: Opacity(
                opacity: dark ? 0.12 : 0.07,
                child: ColorFiltered(
                  // Turns the colorful image into a one-color shadow shape.
                  colorFilter: ColorFilter.mode(dark ? const Color(0xFFD9364E) : Colors.black, BlendMode.srcIn),
                  child: Image.asset('assets/branding/guitar.png', width: side, height: side, filterQuality: FilterQuality.medium),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Wraps the platform's normal page transition and puts [AppBackdrop] behind
/// each page, so every screen pushed by the router gets the background.
class BackdropPageTransitionsBuilder extends PageTransitionsBuilder {
  const BackdropPageTransitionsBuilder(this.inner);
  final PageTransitionsBuilder inner;

  @override
  DelegatedTransitionBuilder? get delegatedTransition => inner.delegatedTransition;

  @override
  Duration get transitionDuration => inner.transitionDuration;

  @override
  Duration get reverseTransitionDuration => inner.reverseTransitionDuration;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) =>
      inner.buildTransitions(route, context, animation, secondaryAnimation, AppBackdrop(child: child));
}
