# TBT music v1

The Flutter camera editors use `StoryMusicPicker` and `StoryMusicSelection`. Photo/video Stories store the selection atomically with the Story and archive. Video posts call `preparePostMusic` before creating the post. Existing upload preparation is unchanged; the music service copies the encoded video stream and mixes only audio.

## Catalog and permissions

`music_tracks/{id}` is provider-neutral. A selectable track requires `active`, all three rights flags, `audioStoragePath` under `music/`, `audioUrl`, and measured `durationMs`. Keep IDs stable when replacing providers. No external paid provider is enabled. Do not import automatically from search results or assume a developer trial grants UGC distribution rights.

Eight starter tracks are pinned by SHA-256 in `tool/editorial/starter-music.json`. The author's catalog and track page state CC BY 4.0. Their source, artist, license, and modification notice are retained in the sound detail page. The publisher script is idempotent and rejects changed source bytes. Turkish-language tracks are not fabricated.

Independent artists upload a file to their own submission directory, supply a license/source URL and three explicit grants, and enter the pending review queue. Only the named administrator can call `approveMusicSubmission`. Approval normalizes audio into the trusted catalog and measures its duration. The administrator must inspect the supplied rights evidence before approving; checkboxes alone do not verify ownership.

Original sounds are generated only for videos whose owner explicitly opts into reuse (`originalSoundConsent`). A trigger extracts up to 60 seconds, names it `Orijinal Ses — @username`, and links the source post and profile. Silent videos do not generate tracks. Users may report rights issues from the sound detail page. Deleting the source disables the original sound; disabling a track restores the retained original video on posts that used it. Cached players may need to reload to see the restoration. Story playback checks the active track before loading audio.

## Server boundaries

- Authenticated callers can process only `users/{uid}/posts/{postId}.mp4`.
- Audio comes from a trusted Storage path, never an arbitrary URL; FFmpeg input formats and protocols are restricted.
- Clip start, duration (up to 60 seconds), volume, track rights and original source availability are checked before processing and rechecked afterward.
- Per-user processing starts are limited to once every 30 seconds; per-instance concurrency is one.
- `music_renders` is server-only; Firestore post rules require an approved render owned by the uploader for a music post.
- Usage counts represent cumulative creations, not current views/listens or a fabricated trend score. `soundTrackId` connects both an original source and derived video posts to the sound page.

## Verification and release

`Check TBT Music` analyzes changed Flutter files, runs existing feed/caption regression tests, tests selection validation, compares encoded video SHA-256 after an actual FFmpeg mix with/without original audio, and checks Firestore rules against an emulator (including forged and disabled music).

The `[music-update]` commit marker limits Functions deployment to six music functions. Firestore rules deploy through their existing workflow. `Publish TBT Starter Music` seeds only the reviewed catalog. Mobile UI requires the next Android build; the iOS store submission remains deferred until its current review completes. No new major-label catalog or provider subscription is purchased by this change.
