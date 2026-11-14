import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Full-screen artwork shown while storage, the audio service and the API
/// client initialise (at least 1.6 s, see `Bootstrap` in main.dart).
///
/// The artwork is `assets/branding/splash_screen.png`. Swap that file to
/// change it; keep the important content in the middle ~75% of the width,
/// since tall phones crop the sides.
class SplashView extends StatelessWidget {
  const SplashView({super.key});

  static const image = AssetImage('assets/branding/splash_screen.png');

  /// Matches the artwork's edges and the native splash color, so there is
  /// no visible jump between the system splash and this screen.
  static const background = Color(0xFF06065F);

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: background,
        body: SizedBox.expand(
          child: Image(
            image: image,
            fit: BoxFit.cover,
            alignment: Alignment.center,
            semanticLabel: 'Loko Music',
            frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
              if (wasSynchronouslyLoaded) return child;
              return AnimatedOpacity(
                opacity: frame == null ? 0 : 1,
                duration: const Duration(milliseconds: 300),
                child: child,
              );
            },
          ),
        ),
      ),
    );
  }
}
