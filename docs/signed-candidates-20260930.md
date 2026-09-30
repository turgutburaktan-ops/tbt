# Signed candidates — 30 September 2026

Source commit: `75a16d0161a574db175daf4c67201f5384b4402a`.
Version: **1.0.35 (63)**.

- Native build: https://github.com/turgutburaktan-ops/tbt/actions/runs/36667243813
- Client/backend verification: https://github.com/turgutburaktan-ops/tbt/actions/runs/36667243742
- Backend: 146 unit tests, 41 general rules tests, and 10 private-photo tests passed. Two known security tests remain skipped.
- Client: encryption/update tests and debug bundle passed.

## Android

The signed AAB was built successfully (108.8 MB). All 104 selected regression tests passed. Upload certificate, JAR signature, and compiled branding checks passed. Candidate analysis reported 845 nonfatal issues; this is not a clean lint result.

Artifact: https://github.com/turgutburaktan-ops/tbt/actions/runs/36667243813/artifacts/11076498675

Artifact ZIP SHA-256: `3c5da631d97f42568e1e7ae3463574171916dca0f4fde986ffd541507cf4c33c`.
This is the archive digest, not the enclosed AAB digest. The AAB digest is in the enclosed `release-info.txt`. The artifact expires on 14 October 2026.

## iOS

Signing certificate/profile preparation, 98 regression tests, signed IPA build, exported branding/version verification, and artifact upload all passed.

Artifact: https://github.com/turgutburaktan-ops/tbt/actions/runs/36667243813/artifacts/11076867923

IPA size: 67.2 MB. Artifact ZIP size: 65,615,114 bytes. ZIP SHA-256: `0920c1bea1f296c878e475ce258dac0e5e3db0517c9e2094b15962aa5564e3c7`. The artifact expires on 14 October 2026.

This is an App Store distribution IPA, not proof of installation or execution on a real device.

## Publication remains blocked

No Play/App Store upload or forced-update policy change was performed. These are candidate builds only. Existing submission workflows and the security release gate remain unchanged.

The gate still reports private-contact migration, frozen-content read/media access, E2EE recovery/device verification/review, App Check device evidence, and database recovery as unresolved. The deployment identity lacks `datastore.databases.update`, as recorded in the previous read-only production diagnosis.

The candidate iOS workflow leaves the encryption-export declaration unset pending review for the new E2EE implementation; it does not reuse the older unverified non-exempt-encryption declaration. A successful build does not resolve export compliance, device compatibility, or the security gate.
