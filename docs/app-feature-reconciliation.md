# Android and iOS feature reconciliation — 2026-09-08

The 1.0.13/code20 candidate was built from main before older application changes were reconciled. Do not submit that candidate. The next Android candidate uses 1.0.13/code21.

## Restored from earlier work

- Username/email password login; Google/Apple entry buttons removed (035b56c, 9d5391c).
- Authenticated, rate-limited username callable and private admin broadcast queue with opt-in push.
- First-install introduction, language selection, and daily first-entry goals.
- Full-screen profile video playback, with current sound reuse and one-line caption controls preserved.
- Account freeze/unfreeze and immediate deletion flow (90addbd).
- Named administrator recovery UI and retained dashboard actions (6766ae7, 0b99da9).
- Stable admin timestamp serialization (978241e).
- Business onboarding checklist and performance summary (1a18336, 5f6e87b).
- iOS tracking permission metadata and previously configured production AdMob identifiers.
- Release readiness and live username authentication gates for both mobile release workflows.

## Preserved from current main

- Mixed-media continuous Explore feed, compact in-grid advertisement, and back-to-home behavior.
- Camera entry icon; removed floating XP and meetup overlays stay removed.
- One-line expandable captions, licensed music, original sound consent and reuse.
- Group member picker, message requests, group notifications and privacy controls.
- Business publication, coupon wallet, reservations/preorders and preparation confirmation/reminders.
- Shared published places catalog and incremental venue loading.

## Release procedure

Use the reconciled main source for both platforms. Build validation is separate from store submission. Android code20 remains an unsubmitted candidate; iOS store submission stays paused until the existing review concludes. Do not substitute an older release branch for main to recover a single feature; apply and review the specific change against the current source instead.
