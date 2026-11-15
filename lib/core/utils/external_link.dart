import 'package:flutter/foundation.dart';
import 'package:pulse_music/core/utils/ui.dart';
import 'package:pulse_music/data/models/models.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens a preview track's own page (Apple Music or Deezer), where the full
/// song can be played. The provider's app opens if installed, else the browser.
Future<void> openFullSong(Track track) async {
  final url = track.externalUrl;
  final name = MusicProviders.label(track.provider);
  if (url == null) {
    toast("Couldn't open $name.");
    return;
  }
  try {
    final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    if (!ok) toast("Couldn't open $name.");
  } catch (e) {
    debugPrint('openFullSong failed: $e');
    toast("Couldn't open $name.");
  }
}
