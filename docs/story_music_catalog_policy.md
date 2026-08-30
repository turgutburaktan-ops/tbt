# TBT Story Music Catalog Policy

TBT must not add a track to `music_tracks` merely because a page labels it "free" or "royalty-free". Every track must have track-level provenance and a license that permits the intended TBT Story use.

## Allowed sources / licenses

Preferred: creator-owned tracks with a direct written grant to TBT, or CC0/public-domain-dedicated tracks where the uploader/rightsholder provenance is recorded.

Conditionally allowed: CC BY tracks when commercial use and adaptation/synchronisation are permitted and TBT can display the required attribution. Store the exact attribution text and license URL.

Do not ingest CC BY-NC, CC BY-NC-SA, CC BY-NC-ND, or other non-commercial licenses. Do not ingest NoDerivatives licenses for Story synchronisation/clipping. Do not bulk-import Mixkit or Pixabay tracks into TBT's selectable music library without separate permission that clearly permits making the tracks available to TBT users as a music catalog. Their standard licenses allow many creative-project uses but restrict standalone redistribution / stock-library style availability.

## Required Firestore fields

Each `music_tracks/{trackId}` document must contain:

- `title`, `artist`, `durationMs`, `category`, `active`
- `audioUrl` (TBT-controlled playback object; never a scraped preview URL)
- `artworkUrl` when licensed for this use
- `licenseType` (for example `CC0-1.0`, `CC-BY-4.0`, `DIRECT-TBT`)
- `licenseUrl`
- `sourceUrl`
- `sourceName`
- `attributionRequired`
- `attributionText`
- `commercialUseAllowed: true`
- `derivativesAllowed: true`
- `catalogDistributionAllowed: true`
- `verifiedAt`
- `rightsNote`

`active` may only be true when the three permission booleans above are true and the evidence has been reviewed.

## Import workflow

1. Select a candidate track.
2. Open the track page and verify the track-specific license/rightsholder, not only the host site's generic marketing text.
3. Confirm commercial use, Story synchronisation/clipping, and permission to expose the audio inside TBT's user-selectable catalog.
4. Save a durable record of the source/license and the review date.
5. Upload the approved audio to TBT-controlled storage.
6. Create `music_tracks` metadata with `active: false`.
7. Review metadata and playback, then activate it.
8. If rights are revoked or become uncertain, set `active: false`; existing Story metadata may remain but playback must fail closed.

## Current source decision

- Free Music Archive can be used only track-by-track when the exact Creative Commons license qualifies. CC0 and CC BY are candidates; NC and ND variants are excluded for this feature.
- Pixabay is useful for music embedded into larger creative works, but its standard license prohibits standalone distribution. Do not mirror its catalog into TBT without additional permission.
- Mixkit permits many social/video project uses but its terms restrict making items available to third parties / stock-library style use. Do not mirror its music library into TBT without additional permission.
