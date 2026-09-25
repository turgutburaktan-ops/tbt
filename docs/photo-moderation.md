# Post-publication photo moderation

## Scope and policy

New image posts in `posts`, including public event-memory mirrors, are visible immediately. Google Vision SafeSearch runs after the Firestore create. Existing posts are not retrospectively scanned. Profile pictures, stories, private event memories, route covers/albums and video frames are not covered by this photo-post trigger.

`adult=VERY_LIKELY` automatically hides a post, except likely medical imagery goes to review. Adult POSSIBLE/LIKELY or racy LIKELY/VERY_LIKELY goes to human review while remaining visible. Racy alone never hides or counts a strike. A service error stays pending and retries; it is never treated as a successful clean scan or a violation.

Only a named, verified admin may confirm a strike. One document ID counts once even across retries, multiple decisions and restoration. At five confirmed distinct posts, an account enters `pending`; closing requires a separate admin decision with a reason. Accepted post appeals remove strikes and invalidate stale fifth-strike approval. Closure revokes Firebase Auth sessions, disables Auth and denies signed-in Firestore/Storage writes. It archives public posts and revokes their media URLs. Data is retained for review; there is no automatic permanent deletion. Reopening is an explicit admin decision and does not restore confirmed violations.

## Storage and consistency

`photo_moderation` contains scan results and decisions; `photo_moderation_accounts` holds strike totals and closure status; both are server-write-only. Owners can read their decisions, admin can review all. Original post/event-memory documents are stored in server-only `photo_moderation_archive`. Media is retained with `moderationBlocked` metadata, public download tokens revoked, and Storage reads/updates denied. Restoration generates fresh media URLs. Already downloaded device/browser copies cannot be recalled.

Photo files are immutable after creation; a moderation record prevents deletion/recreation from bypassing a completed scan. Firestore validates that a client photo URL references its own Storage path. Per-post and per-account leases serialize changes. Scheduled retries recover interrupted scans/hiding/closure. Closure and restore work is paginated.

## User and admin flows

- Admin: existing Moderation screen → photo inspection icon. Separate filters for scans/errors, reviews, confirmed/dismissed cases, photo appeals and account decisions.
- User: Settings → Paylaşım denetimi → reasoned appeal.
- Disabled account: closure notification includes a private, single-use appeal code; Login → Hesap itirazı accepts it without account access. Admin reviews it in account decisions and may reopen the account. Do not share this bearer code.

## Deployment and verification

`.github/workflows/photo_moderation.yml` gates deployment on Flutter analysis/bundle and Firestore/Auth/Storage emulator tests. It checks/enables Vision, runs a real benign-image request, adds only the moderation indexes, and deploys the explicit moderation functions plus reviewed rules. No existing functions or indexes are deleted. The final admin-only runtime diagnostic scans an existing ready-route photo without publishing a test post.

Changing the code does not submit a new Play/App Store binary. Admin/user screen changes require the next app build. The server trigger works with the existing image-post payload and requires no pre-upload delay.
