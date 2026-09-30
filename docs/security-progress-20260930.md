# Security implementation progress — 30 September 2026

## Contact privacy

The candidate Firestore policy now denies email, phoneNumber and verifiedPhoneNumber writes on public users documents and allows owner/admin reads of server-written private_users records. Normal people pickers no longer use public email fields. Private-contact rules run in the primary emulator CI, including enumeration and write denial. The release-gated migration workflow Firebase Admin imports were corrected for a clean runner.

No production contact migration ran. Existing public contact values remain a live blocker until the approved compatibility gate, live-policy validation and atomic migration complete. F01 stays skipped for that unresolved legacy production data; candidate rules alone do not redact existing documents.

## Frozen accounts

The user-media path now requires an active owning profile. Freeze processing first marks owned content frozen and then archives/revokes Firebase download tokens under users/{uid}/. Server-only frozen_media manifests retain recovery metadata. Unfreeze restores tokens only after account activation, while holding the lifecycle lease; generation matching prevents granting an old URL access to a replacement file. Deletion cleans up these manifests. This does not revoke bytes already downloaded or cached by a recipient.

Post document and nested likes/comments/tags reads now deny frozen content. Public post queries add an explicit accountFrozen=false filter; new client-created posts include it. Matching indexes and a dry-run-by-default backfill are provided. F06 and dedicated feed/child-read rule tests exercise the candidate policy.

**Deployment ordering is required:** deploy/build the new query indexes and initializePostVisibility trigger, complete and verify the visibility backfill, deliver compatible clients, then enforce the new read/create policy. The trigger maintains the field for older server writers during the transition. Do not deploy the policy to old clients or launch the new filtered feed before backfilling older documents. The dry-run/apply tool reads post and owner in the same transaction and never thaws a frozen post or recreates a deleted document.

Still open: equivalent read/query protection for stories, events, memories, communities and routes; token coverage for media outside users/{uid}/ and production URL/CDN verification; concurrent server-upload handling. The overall frozen-content gate remains pending.

## E2EE and publication

Key recovery/device transfer has not been implemented in this change. A safe design must handle stale backups, concurrent devices, ratchet rollback and revocation of the old device; copying the vault or clearing server identity checks would not satisfy this requirement. Real-device checks and independent review remain required.

No Functions/Rules/index deployment, data backfill, store upload or forced-update change occurred. Build 63 predates these changes and is not the final candidate for this code.
