# TBT security verification — 2026-09-28

Base: `0f7a67c2cfae977fd9f19808ebf523af578bfe92`, branch `codex/store-release62-security-20260927`. Work isolated from the existing dirty workspace. Gallery permission scope is unchanged, as requested.

## Confirmed corrections

- The periodic private-media sweep excluded `users/<uid>/chat/<thread>/<file>`. Include legacy photos and audio while preserving `chatMessageId`; public posts and avatars remain excluded.
- The one-shot deployment revocation skipped `private_chat/`. A shared revocation procedure now visits all private namespaces, seals each object, and verifies anonymous access plus every previous download token. No object data or token values are printed.
- Project hardening previously exited successfully even if recovery failed with HTTP 403. Success now requires readback of the enforced password minimum, point-in-time recovery, and deletion protection.
- The legacy chat emulator suite had an outdated single-namespace sweep fixture and mismatched cross-service project ID. Both are corrected; legitimate members as well as unauthorized readers are exercised.

## Local verification

- 129 backend/unit tests passed.
- 38 Firestore/Storage emulator tests passed; 2 pre-existing skipped checks concern public contact fields and frozen-content reads. These are **not** closed findings.
- The existing release gate exits with failure for the five pending protections below; no store submission is part of this change.

## Prior deployment evidence verified

- https://github.com/turgutburaktan-ops/tbt/actions/runs/36340889275 — account lifecycle verification and deployment succeeded; deployment log confirms active Firestore and Storage rules.
- https://github.com/turgutburaktan-ops/tbt/actions/runs/36341044925 — App Check client analysis and debug bundle succeeded. This is not production attestation evidence.
- https://github.com/turgutburaktan-ops/tbt/actions/runs/36308739337 — availability and rule tests succeeded, but the contact migration job was skipped.

## Remaining release blockers

| Protection | Verified state / dependency |
| --- | --- |
| Private contact migration | Not executed. Current rollout requires compatible clients available on both stores and actual Play installation verification. |
| Frozen-content reads | Publication/write restrictions exist; content and media read privacy is not implemented. Requires compatible query/data/media migration, not only hiding UI elements. |
| End-to-end encryption | Not implemented. Requires client key management and end-to-end device tests; server authorization is not E2EE. |
| App Check enforcement | Client startup corrected; no verified production-device attestation. Enabling enforcement without that evidence risks locking out supported clients. |
| Database recovery | Previous deployment identity received 403; permission resolution and verified readback remain required. |

The dedicated repair workflow verifies the patch before deploying only the existing media sweeper and revoking private-media tokens. Its result must be inspected before describing these changes as live. This document does not certify that all application vulnerabilities are closed.
