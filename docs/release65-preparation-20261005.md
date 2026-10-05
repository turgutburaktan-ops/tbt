# Release 65 store submission — completed 2026-10-05

User explicitly approved the five disclosed open checks for release65 at 14:59 Europe/Istanbul. Recorded in tool/release65_accepted_risks.json. The default security gate and release66 still fail; no security check was marked verified.

Submission source: ab605d5d924b4c90f84b6da17309eb068beb24f1. Workflow 37306646546 completed successfully using signed artifacts from 37301788819.

- Android job 111751925167: versionCode65 uploaded, checksum verified, alpha edit committed and read back as 65 (1.0.37), completed; review submitted at 12:02:56 UTC. This is closed testing, not production rollout.
- iOS job 111751925268: upload succeeded; build 9983a93e-d23f-4005-8761-87b7490fc54e VALID; truthful encryption documentation exemption rechecked against unavailable France; submitted at 12:11:18 UTC, WAITING_FOR_REVIEW.
- Apple review: f2764add-2359-4acc-b161-8b967b82b007; version: ef20ec52-ca5c-42fb-a91b-3fff4cf4ce92; releaseType AFTER_APPROVAL.
- Existing mandatory-update policy was not changed during this submission.

The preparation history below predates this approval and submission.

---

# Requested update 1.0.37 (65)

Request: “Tamam bunları güncelleme yap” on 2026-10-05, following the screen-recording review.

## Completed

- Current stores inspected in run 37301659582 (job 111735561779): Android alpha 64 completed, production track has no release; Apple 1.0.36 READY_FOR_SALE/READY_FOR_DISTRIBUTION, build 64 VALID. Turkey available, France unavailable, automatic new-territory availability false.
- Signed native build source: 690bd183a850b39b5223966a9f26b7e51ebcb513, run 37301788819.
- Android job 111735970643: success, 121 tests passed, signed AAB verified, launcher identity verified.
- iOS job 111735970806: regression tests, signed IPA, version/branding verification and artifact upload passed.
- Android artifact: tbt-play-release-1.0.37-code65, ID 11342910509; archive SHA256 36911fb6834e71dd2f984d5722585e865a1617c366dc2d14738db0fdbb5bd4d7.
- iOS artifact: tbt-ios-ipa-1.0.37-build65, ID 11343257378; archive SHA256 8946bcdb8a53eb3871a7c2e151d181450c21cce7b351352a1b27ae131749c3e7.
- Artifacts retained until 2026-10-19. Archive digests above are not raw AAB/IPA digests.
- Manual store_release65 workflow and platform submit scripts prepared. It requires the exact successful signed source and unchanged security gate before any store upload.

Included: original-byte Reels prefetch/cover handling, common route wizard from place detail, bounded pending feed card layout, reserved admin header space. Video quality is unchanged.

## Remaining publishing decision

`node tool/security_release_gate.cjs --release=65` exits 1. Existing `release64_accepted_risks.json` explicitly applies only to 64; it was not extended. Five security checks still lack complete verified evidence: private contacts, full frozen-content read enforcement, E2EE device/recovery/independent verification, App Check enforcement, database deletion protection. Some readiness reasons predate the successful September 30 backend rollout; see security-progress-20260930.md for completed work and remaining limits. Do not claim the old snapshot proves those deployments never happened.

No release65 upload/submission, production rollout, or mandatory-update policy mutation has occurred. Next action requires resolving the gate or explicit risk acceptance for release65; then use exact verified artifacts. Do not rebuild or waive identity/readback checks unnecessarily.
