# Security implementation progress — 30 September 2026

## Live release repair — 30 September, 09:51 UTC

This section supersedes the earlier pre-deployment observations below. The owner explicitly requested release 64 with disclosed open work; `release64_accepted_risks.json` pins that acceptance to the unchanged security checklist. Default security gates remain strict, and release 64 does not report pending controls as verified.

- Firebase CLI was blocked on an unrelated Extensions read. Scoped official Cloud Functions deployment succeeded after explicitly providing the existing Firebase runtime configuration. No IAM roles were expanded.
- All seven content initialization triggers were deployed. All 60 visibility indexes reached READY. Run 36695614771 then migrated 224 records (106 posts, 37 stories, 1 repost, 19 events, 60 routes, 1 community) and read-only completion verification found zero incompatible records.
- Run 36695743272 deployed 14 selected callable endpoints, including admin health, E2EE registration/key claim/message send, private media and lifecycle endpoints. Every endpoint was ACTIVE and rejected unauthenticated HTTP requests with UNAUTHENTICATED.
- Run 36696296021 passed all three E2EE rules tests and deployed compatibility-only changes to the existing live Firestore and Storage rules. Unrelated rules and old-client feed queries were preserved. Firestore ruleset: `99664fc6-968a-424d-b45f-4550238570dc`; Storage: `5772605b-75c0-4741-9c96-eb32f87b739e`.
- Both signed Android and iOS 1.0.36 (64) artifacts passed verification in run 36694846452. Run 36696663036 was superseded before upload so that Android would not wait for iOS. In run 36697339213, Android job 109828811744 uploaded, checksum-verified, committed and read back build 64 on the existing alpha closed-testing track. This is not proof of public production distribution. Apple upload succeeded, and build `d64c3229-c5bb-4cae-b336-3bfd48509e0a` became VALID and APP_STORE_ELIGIBLE. The original submission encountered the documentation API error described below; corrective run 36698025984 succeeded and read back WAITING_FOR_REVIEW for iOS 1.0.36 (64), review `280284fb-6249-4dee-b773-e497c3d4d674`, version `9530bd19-8f4b-474e-a4cb-269a31337af2`. Release is configured AFTER_APPROVAL.
- Apple read-only inspection confirmed Turkey available, France unavailable, automatic new-territory availability disabled, and no existing encryption declarations. The app implements standard algorithms outside the OS. Apple rejected document creation for proprietary=false, thirdParty=true, France=false because this combination does not require a declaration. Apple documentation specifies the French declaration only when distributed in France and permits usesNonExemptEncryption=false for encryption exempt from documentation requirements. Submission now checks France remains unavailable before setting that documentation exemption; this does not disable encryption or claim the app uses no encryption. Sources: https://developer.apple.com/help/app-store-connect/reference/app-information/export-compliance-documentation-for-encryption and https://developer.apple.com/help/app-store-connect/manage-app-information/determine-and-upload-app-encryption-documentation .
- Run 36698126140 successfully armed and read back `androidMinimumBuild:64` and `iosMinimumVersion:1.0.36`. The existing client checks Play availability per device and Apple availability per country before making an update mandatory, so this does not force an unavailable build. Android alpha submission and iOS App Review submission are confirmed; neither is a claim that version 64 is publicly available everywhere. Contacts, complete frozen-read enforcement, App Check device evidence, key recovery/device transfer and deletion protection remain open as documented below.


## Historical candidate observations (before the live repair above)

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


Final release evidence:
- Android submission: https://github.com/turgutburaktan-ops/tbt/actions/runs/36697339213 (Android job succeeded; original iOS declaration step was superseded).
- Successful iOS App Review submission: https://github.com/turgutburaktan-ops/tbt/actions/runs/36698025984 .
- Verified conditional mandatory-update policy: https://github.com/turgutburaktan-ops/tbt/actions/runs/36698126140 .
- Gate checks: default invocation and release 65 remain blocked; explicit approved release 64 succeeds without marking any pending security check verified.
