# Music API research: Bangla, Hindi and English

Checked against official docs and live requests on 2026-11-14.

## Summary

| API | Full-length audio | Bangla | Hindi | English | Auth | Used in Pulse |
|---|---|---|---|---|---|---|
| **Audius** | Yes (`/tracks/{id}/stream`, 302 to `audio/mpeg`) | Yes, by search | Yes, by search | Yes | None (optional API key) | **Primary source** |
| **Jamendo** | Yes (`audio` field, verified 272 s file) | Unverified | Unverified | Yes | Free `client_id` | **Optional second source** |
| Deezer | No, 30-second `preview` only | Metadata only | Metadata only | Metadata only | None for search | No |
| Internet Archive | Yes | 5 openly licensed items | 31 openly licensed items | Large | None | No |
| JioSaavn | No public or permitted API | | | | | No |

## Audius

- Docs: https://docs.audius.co/ (REST base `https://api.audius.co/v1`)
- Auth: none needed. `app_name` is required. An optional free API key (https://api.audius.co/plans) raises limits. Pass it with `--dart-define=AUDIUS_API_KEY=...`.
- Playback: `GET /tracks/{id}/stream` returns a 302 redirect to a full-length `audio/mpeg` file. Verified live.
- Search: `/tracks/search` with `query`, `genre`, `sort_method=relevant|popular|recent` (all three verified), `limit`, `offset`. Also `/users/search` and `/playlists/search`.
- Metadata: title, artist, artwork (150/480/1000 px), duration, genre, mood, `tags`, `release_date`, play count.
- Language: **there is no language field or filter.** Pulse finds languages by search terms and checks each result's title, tags and description (see "How languages are detected" below).

Live coverage, counting up to 50 results per query:

| Query | Tracks |
|---|---|
| bangla, bengali, baul, lalon, hindi, bollywood, "romantic hindi", "sad hindi", "bollywood romantic", "english songs" | 50 each (the cap) |
| "bangla old" | 46 |
| "bollywood sad" | 18 |
| nazrul | 11 |
| "rabindra sangeet" | 4 |
| adhunik | 1 |

| Query | Playlists | Albums |
|---|---|---|
| bangla | 11 | 0 |
| hindi | 47 | 0 |
| bollywood | 50 | 0 |
| english | 48 | 0 |

- **Limitations:**
  - Search finds no albums for any of these languages, so Pulse has no "Bangla, Hindi or English Albums" sections.
  - `/users/search` is fuzzy ("bangla" also matched "Yin Yang Bangers"), so artist sections come from the artists of language-matched tracks.
  - The catalog is mostly independent artists. Some uploads are clearly re-uploads of label songs, and Audius, not Pulse, is responsible for moderating those.
- **Licensing:** artists upload and license their own music to Audius. Free for commercial and non-commercial apps under the Audius API terms.

## Jamendo

- Docs: https://developer.jamendo.com/v3.0/tracks. Register for a free `client_id` at https://devportal.jamendo.com/.
- Auth: `client_id` query parameter. Without it the API answers `code 5, Invalid Client Id`.
- Playback: the `audio` field is a full-length stream (`audioformat=mp32` gives VBR, good quality). The docs' sample URL returned a 3.29 MB `audio/mpeg` file, which matches its 272 s duration.
- Search: `search` (free text over track, album, artist and tags), `namesearch`, `tags`, `order`, `limit` (max 200), `offset`.
- **Language:** `lang` filters by lyrics language with 2-letter codes. Pulse sends `bn`, `hi` and `en`. Coverage for `bn` and `hi` could not be checked without a `client_id`. Jamendo is mostly European independent music, so expect few Bangla or Hindi results.
- Metadata: name, artist, album, album image, duration, release date, CC license URL.
- **Licensing:** all music is Creative Commons. API use is free for **non-commercial** apps. Commercial use needs a Jamendo licensing agreement.
- **Status in Pulse:** this is wired in from the documented response shape, and it turns on only when `JAMENDO_CLIENT_ID` is set. It has not been run against the live API with a key.

## Rejected

- **Deezer** (https://developers.deezer.com/api): search works without a key and finds Hindi film songs, but `preview` is a 30-second clip. It has no full-length streaming, so it fails the "genuinely playable" requirement.
- **Internet Archive** (https://archive.org/developers/): full-length audio, but only 5 Bengali and 31 Hindi audio items carry Creative Commons or public-domain licenses. Most other items are user uploads with unclear rights. Too thin and too risky.
- **JioSaavn, Gaana, Spotify:** no public, permitted, free full-streaming API. Unofficial wrappers scrape commercial services and break their terms.

## How languages are detected

Audius has no language field, so Pulse classifies each item from its title, tags, description and genre (`lib/core/utils/language_detect.dart`):

1. **Bengali script** (U+0980 to U+09FF) means Bangla. **Devanagari** (U+0900 to U+097F) means Hindi.
2. **Keywords**, matched as whole words:
   - Bangla: bangla, bengali, bangladesh, kolkata, rabindra, nazrul, baul, lalon, adhunik
   - Hindi: hindi, bollywood, hindustani, bhajan, ghazal, filmi
3. **English:** Latin script with no Bangla or Hindi signal.

This is a heuristic. A Bangla song with a romanized title and no keywords is classed as English. Jamendo results take the language that was requested with `lang`.

## Licensing and streaming limits

- Every song Pulse plays is a full-length, legal stream from Audius, or from Jamendo when configured.
- Mainstream Bollywood and major-label Bangla songs are not available through any free, legal API. They need a licensing deal with the labels.
