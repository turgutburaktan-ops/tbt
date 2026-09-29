# Release readiness — 29 September 2026

The user explicitly approved pushing the fixes to `turgutburaktan-ops/tbt`, remote builds/tests, and applying Firebase password and database recovery protections. These operations were retried after that approval. No store submission or forced-update policy change was made.

## Executed work

- All 60 changed files were uploaded to the isolated `codex/release-readiness-20260929` branch through the authenticated GitHub connector. The uploaded tree matched local tree `3c291872cf0c4ef3add9ed88003aa848b4dd110e` exactly.
- Initial verification: https://github.com/turgutburaktan-ops/tbt/actions/runs/36588543132
- Corrected clean CI installation (ffmpeg install scripts are required by the media tests): https://github.com/turgutburaktan-ops/tbt/actions/runs/36588825581
- Flutter analysis, Signal/attachment/update-policy tests, and debug bundle build passed in the initial client job. Analysis reported 120 existing issues; this is not a clean lint result or an APK/IPA/device test.
- Corrected backend job: 143 unit tests passed; 41 rules/emulator tests passed with 2 skipped; 10 private-photo emulator tests passed.

## Production readback

- Password policy: `ENFORCE`, minimum length 10, verified by readback.
- Database recovery: HTTP 403 from the existing deployment identity. Recovery and deletion protection could not be verified. No IAM privileges were granted or bypassed.
- Android alpha: build 62 / 1.0.34, `completed`; this does not prove installation on a particular tester device.
- iOS: 1.0.34 `READY_FOR_SALE`, build 62 `VALID`.
- Those store artifacts predate the new profile album/admin-health/E2EE changes. Do not resubmit different bytes under build 62.
- App Check providers are registered. Last-24-hour aggregate metrics did not provide a valid-attestation series; callable verification-log access returned 403. Enforcement remains unchanged (`UNENFORCED`). Aggregate traffic cannot prove readiness for every supported device.

## Remaining blockers

The release gate remains in place. Private contact migration, frozen-content read protection, real-device E2EE verification/key recovery, and App Check compatibility/enforcement remain unresolved. The two skipped emulator tests are the contact and frozen-content findings, not successful checks.

The Firebase deployment identity needs authorized database-configuration access to finish recovery setup. Real-device evidence and the remaining implementation/migration work are still required before store submission and mandatory updates. No pending or blocked check was marked verified merely because this workflow ran.
