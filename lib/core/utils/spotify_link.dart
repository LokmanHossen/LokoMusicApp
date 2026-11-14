import 'package:flutter/foundation.dart';
import 'package:pulse_music/core/utils/ui.dart';
import 'package:pulse_music/data/models/models.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens a Spotify search for the track. No Spotify API, account or key is
/// used: this is only a link. The Spotify app opens if installed, otherwise
/// the web player opens in the browser.
Uri spotifySearchUri(Track track) =>
    Uri.https('open.spotify.com', '/search/${track.title} ${track.artist.name}');

Future<void> openInSpotify(Track track) async {
  try {
    final ok = await launchUrl(spotifySearchUri(track), mode: LaunchMode.externalApplication);
    if (!ok) toast("Couldn't open Spotify.");
  } catch (e) {
    debugPrint('openInSpotify failed: $e');
    toast("Couldn't open Spotify.");
  }
}
