// Builds the launcher-icon and native-splash images from the master logo
// assets/branding/logo.png (square, transparent rounded corners).
// After replacing the logo, re-run:
//   flutter test tool/branding/generate_branding_test.dart
//   dart run flutter_launcher_icons
//   dart run flutter_native_splash:create
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

/// Dark navy behind the logo (adaptive-icon background, splash backgrounds).
const navy = Color(0xFF06065F);

Future<ui.Image> _load(String path) async {
  final codec = await ui.instantiateImageCodec(File(path).readAsBytesSync());
  return (await codec.getNextFrame()).image;
}

Future<void> _render(String path, int size, void Function(Canvas c, Rect box) paint) async {
  final recorder = ui.PictureRecorder();
  final box = Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble());
  paint(Canvas(recorder, box), box);
  final image = await recorder.endRecording().toImage(size, size);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  File(path).writeAsBytesSync(bytes!.buffer.asUint8List());
}

void main() {
  test('generate branding images from logo.png', () async {
    const dir = 'assets/branding';
    final logo = await _load('$dir/logo.png');
    final src = Rect.fromLTWH(0, 0, logo.width.toDouble(), logo.height.toDouble());
    final paint = Paint()
      ..filterQuality = FilterQuality.high
      ..isAntiAlias = true;

    /// Draws the logo centered at [scale] of the canvas.
    void drawLogo(Canvas c, Rect box, double scale) =>
        c.drawImageRect(logo, src, Rect.fromCenter(center: box.center, width: box.width * scale, height: box.height * scale), paint);

    // Legacy icon (Android < 8): the logo as-is; its corners are already rounded.
    await _render('$dir/icon.png', 1024, (c, b) => drawLogo(c, b, 1));

    // Adaptive icon (Android 8+): launchers show only the middle 2/3 and mask
    // it to a circle/squircle. flutter_launcher_icons adds a 16% inset, so a
    // full-size foreground ends up at ~68%, just covering the visible area:
    // the logo's own rounded corners never show and the title text stays inside
    // the circle.
    await _render('$dir/icon_background.png', 1024, (c, b) => c.drawRect(b, Paint()..color = navy));
    await _render('$dir/icon_foreground.png', 1024, (c, b) => drawLogo(c, b, 1));

    // Native splash, Android < 12: logo centered on the navy background.
    await _render('$dir/splash.png', 600, (c, b) => drawLogo(c, b, 1));

    // Android 12+: the system masks this 1152px image to a 768px circle;
    // 0.56 keeps the whole logo inside it.
    await _render('$dir/splash_android12.png', 1152, (c, b) => drawLogo(c, b, 0.56));

    expect(File('$dir/icon.png').existsSync(), isTrue);
  });
}
