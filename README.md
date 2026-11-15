# Loko Music - Flutter music streaming app

Loko Music streams full-length, legal music from the **Audius API** (https://docs.audius.co/api).
It can also use **Jamendo** (https://developer.jamendo.com/v3.0) as an optional second source for
Creative Commons tracks; it is off unless you supply a free client id.
Songs of **30 seconds or less are never shown** (previews, ringtones, short clips). Deezer and iTunes
preview support exists in the code but is switched off for that reason (see the API doc).
See `docs/MUSIC_APIS.md` for the API research and comparison (Internet Archive and JioSaavn were
checked and rejected).

## Run it
```bash
flutter create . --org com.pulse --project-name pulse_music   # generates android/ and ios/ (keeps lib/)
flutter pub get
# Apply platform_setup/AndroidManifest_additions.xml and Info_plist_additions.xml
flutter run --dart-define=AUDIUS_API_KEY=your_free_key
# Optional second source (non-commercial use only under Jamendo's free tier):
flutter run --dart-define=JAMENDO_CLIENT_ID=your_client_id
flutter test
# Live checks against the real Audius API (network required):
flutter test test/live_api_test.dart --dart-define=LIVE=true
```

Both keys are optional and passed at build time; none are stored in the source.

## Audius API usage
- Base URL: `https://api.audius.co/v1` (override with `--dart-define=AUDIUS_BASE_URL=...`;
  optional `AUDIUS_FALLBACK_URL` is tried if the first host fails).
- API key: free from https://api.audius.co/plans, passed at build time via `--dart-define`
  and sent as `api_key` with `app_name`. Never hardcoded. Do not ship an Audius bearer token in the app.
- Responses are `{ "data": ... }`; `core/network/audius_client.dart` unwraps them and adds retry,
  timeouts, caching and duplicate-request merging.
- Audio: `GET /tracks/{id}/stream` (redirects to the audio file).

Endpoints used (`data/repositories/audius_repository.dart`):

| Area | Endpoints |
|---|---|
| Tracks | `/tracks/trending` (time, genre), `/tracks/trending/underground`, `/tracks/search`, `/tracks/{id}/stream` |
| Users | `/users/search`, `/users/{id}`, `/users/{id}/tracks`, `/users/{id}/albums`, `/users/{id}/playlists` |
| Playlists/albums | `/playlists/trending`, `/playlists/search`, `/playlists/{id}`, `/playlists/{id}/tracks` |

Albums are playlists with `is_album: true`. `sort_method=relevant|popular|recent` on track search was
verified against the live API on 2026-11-14.

## Languages: Bangla, Hindi, English
Home and Explore have **Bangla / Hindi / English** cards that open a language page
(`features/languages/presentation/language_screen.dart`). Search has a language filter.

- Audius has no language field, so each section runs Audius searches and keeps results whose
  language is detected from title, tags and description (`core/utils/language_detect.dart`:
  Bengali/Devanagari script first, then keywords). It's a heuristic: romanized titles without
  keywords count as English.
- Sections are defined in `core/constants/languages.dart`:
  - Bangla: latest, popular, classic (Lalon, Baul, Nazrul, Rabindra Sangeet), artists, playlists
  - Hindi: latest, Bollywood, romantic, sad, artists, playlists
  - English: trending, popular, latest, artists, playlists
- No album sections: Audius search returns no albums for these languages (checked live).
- With Jamendo enabled, each language page adds a "Free … music · Jamendo" row (Jamendo's `lang`
  filter), and search merges Jamendo tracks with Audius, removing duplicates.
- Tracks carry `provider` and, for Jamendo, a direct `streamUrl`; the player uses it, and
  builds the Audius stream URL otherwise.

## Open in Spotify
Track menu > "Open in Spotify" opens a Spotify search for the title and artist
(`core/utils/spotify_link.dart`). It is only a link: no Spotify API, key or login, and no Spotify
audio inside Loko Music. All playback stays on Audius.

## Structure
```
lib/core        config, network (Dio client), theme, router, services (audio, Hive), utils
lib/data        models, Audius repository
lib/shared      Riverpod providers/controllers, reusable widgets, mini player
lib/features    screens: home, music_categories, tracks, artists, playlists, search,
                player, queue, library, settings, splash
```

## Notes
- Local-only (Hive): favorites, followed artists, playlists, recents, search history, queue, settings.
- No lyrics section (Audius has no lyrics data). No Audius login, so no remote follow/repost/favorite.
- Not compiled by the author (no Flutter SDK in the sandbox); expect small analyzer fixes.

## Branding
App name **Loko Music**.
- `assets/branding/logo.png`: master logo (square, transparent rounded corners). The launcher icons
  and native splash images are generated from it.
- `assets/branding/splash_screen.png`: full-screen artwork shown by the in-app splash
  (`features/splash/presentation/splash_view.dart`). Keep key content in the middle ~75% of the
  width; tall phones crop the sides.

After replacing the logo, regenerate:
```bash
flutter test tool/branding/generate_branding_test.dart   # icon + splash PNGs from logo.png
dart run flutter_launcher_icons                          # all icon sizes, adaptive icon
dart run flutter_native_splash:create                    # native splash, incl. Android 12
```
The Dart package and Android application id stay `pulse_music` / `com.example.pulse_music`.

## YouTube music videos
Language pages have a **Music videos · YouTube** row, and Search has a **Videos** tab. Videos play in
YouTube's official embedded player (`youtube_player_iframe`), **as video, in the foreground only**:
YouTube's terms forbid audio-only, background or lock-screen playback and downloads, so videos never
go through the app's audio player or queue, and the app's own music pauses when a video opens.

- API: YouTube Data API v3 `search.list` (`type=video`, `videoCategoryId=10`, `videoEmbeddable=true`,
  `regionCode=BD`, `relevanceLanguage=bn|hi|en`) plus `videos.list` for length and embeddability.
  Videos of 30 s or less are hidden, like everywhere else.
- Quota: 10,000 units/day free for the whole app; one search costs 100 (about 100 searches/day).
  Results are cached on the device for 6 hours, and Search only queries YouTube when the Videos
  tab is opened.
- Key: put it in `config/secrets.json` (git-ignored; template in `config/secrets.example.json`).
  `.vscode/launch.json` passes it with `--dart-define-from-file=config/secrets.json`; from the
  command line use the same flag. Without a key the YouTube features are hidden.
- Restrict the key in Google Cloud Console (APIs & Services → Credentials): limit it to the
  YouTube Data API v3 and to the Android app (package `com.example.pulse_music` + your signing
  SHA-1). A key inside an app can always be extracted, so restriction is what protects it.
