# Security implementation progress — 30 September 2026

## Contact privacy

The candidate Firestore policy now denies email, phoneNumber and verifiedPhoneNumber writes on public users documents and allows owner/admin reads of server-written private_users records. Normal people pickers no longer use public email fields. Private-contact rules run in the primary emulator CI, including enumeration and write denial. The release-gated migration workflow Firebase Admin imports were corrected for a clean runner.

No production contact migration ran. Existing public contact values remain a live blocker until the approved compatibility gate, live-policy validation and atomic migration complete. F01 stays skipped for that unresolved legacy production data; candidate rules alone do not redact existing documents.

## Frozen accounts

The user-media path now requires an active owning profile. Freeze processing first marks owned content frozen and then archives/revokes Firebase download tokens under users/{uid}/. Server-only frozen_media manifests retain recovery metadata. Unfreeze restores tokens only after account activation, while holding the lifecycle lease; generation matching prevents granting an old URL access to a replacement file. Deletion cleans up these manifests. This does not revoke bytes already downloaded or cached by a recipient.

Post document and nested likes/comments/tags reads now deny frozen content. Public post queries add an explicit accountFrozen=false filter; new client-created posts include it. Matching indexes and a dry-run-by-default backfill are provided. F06 and dedicated feed/child-read rule tests exercise the candidate policy.

**Deployment ordering is required:** deploy/build the new query indexes and initializePostVisibility trigger, complete and verify the visibility backfill, deliver compatible clients, then enforce the new read/create policy. The trigger maintains the field for older server writers during the transition. Do not deploy the policy to old clients or launch the new filtered feed before backfilling older documents. The dry-run/apply tool reads post and owner in the same transaction and never thaws a frozen post or recreates a deleted document.

Read/query protection now also covers stories, social events, event memories, communities, reposts and routes, including nested route/event reads. Storage route/event reads check parent visibility. Client queries, root constructors, transition triggers and indexes were updated together. A late-upload finalization guard rechecks restricted accounts; private chat/business-claim tokens are permanently revoked and never restored during unfreeze. These are candidate changes, not production evidence. Still open: live rollout, external/cached media URL verification and validation of the asynchronous finalization window. The overall frozen-content gate remains pending.

## E2EE and publication

Key recovery/device transfer has not been implemented in this change. A safe design must handle stale backups, concurrent devices, ratchet rollback and revocation of the old device; copying the vault or clearing server identity checks would not satisfy this requirement. Real-device checks and independent review remain required.

No Functions/Rules/index deployment, data backfill, store upload or forced-update change occurred. Build 63 predates these changes and is not the final candidate for this code.

## Verified candidate evidence

GitHub Actions run https://github.com/turgutburaktan-ops/tbt/actions/runs/36677339230 verified commit `20b7c1e03d8b8ac124d549a7aac3f33507529657`:

- Client analysis, targeted Signal/attachment/update-policy tests and debug bundle succeeded.
- Backend: 155 unit tests passed.
- General Firestore/Storage emulator suite: 48 passed, zero failed, one skipped (F01 legacy production contact exposure, still unresolved).
- Private-photo backend emulator suite: 10 passed, zero failed.
- Production-evidence job deliberately skipped; this run performed no live deployment or migration.

The emulator caught a permissive unconstrained post query when the visibility helper used a default-false field lookup. The helper now requires explicit `accountFrozen == false`; filtered feeds succeed and unconstrained/frozen reads are denied by the verified tests. The staged rule patch is separate from the generic hardening deployment so earlier workflows do not silently activate incompatible post-read requirements.

## Expanded content protection and live preflight

The final expanded candidate passed https://github.com/turgutburaktan-ops/tbt/actions/runs/36683176192: 159 backend unit tests, 50 general emulator tests, and 10 private-photo emulator tests passed (219 total); the legacy production contact finding remains the one explicitly skipped test. Flutter analysis, targeted encryption tests and debug bundle also passed. No new store artifact was produced.

Read-only production preflight https://github.com/turgutburaktan-ops/tbt/actions/runs/36682968328 made no migration writes (`apply:false`). It found 224 records needing explicit visibility: 106 posts, 37 stories, one repost, 19 events, 60 routes and one community; no event memories and no invalid owners were reported. Use `tool/content_visibility_backfill.cjs` for all seven owner-bound collections, keeping dry-run default. The generalized initialization triggers must precede backfill, compatible clients and final strict policy enforcement.

The last 24-hour App Check metrics showed INVALID or MISSING results and no VALID series in this sample. This does not establish which requests came from real store devices; enforcement remains blocked. Callable verification-log access returned HTTP 403. Android alpha build 62 (1.0.34) was completed; iOS 1.0.34 was READY_FOR_SALE with valid build 62. Neither API proves successful installation/attestation on the user's physical device.

E2EE key recovery/device transfer is still not implemented; unchanged immutable-identity registration rejects a replacement device key. No claim of complete E2EE or release readiness is made. Database deletion protection remains unverified/blocked from the earlier permission failure; this preflight did not modify or recheck it. PITR was previously enabled.
