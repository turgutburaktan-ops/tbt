# Private chat media rollout

Gallery permission changes are explicitly excluded by the owner (2026-09-26).
Do not change photo picker behavior, Android media permissions, or iOS photo-library permissions as part of this work.

Normal direct/group chat photos and voice messages now use authenticated Firebase Storage reads. New messages store a gs:// object identifier, never a permanent token download URL. Legacy HTTP URLs are parsed as object identifiers; the client does not fetch them anonymously. Public profile/feed media and existing event/route media flows are unchanged.

Uploads enter private_chat/{threadId}/{uid}/{messageId}/. finalizeChatMedia removes the reserved Firebase download token and marks the object sealed before the application creates the message. A five-minute scheduled sweep also strips tokens from abandoned uploads, processing a bounded page of 100 objects per invocation with a persisted cursor. Normal app uploads are synchronously sealed by the callable before message creation; the sweep is a fallback. The Storage event trigger required a new Pub/Sub publisher IAM binding unavailable to the deployment account, so the scheduled fallback avoids granting additional privileges. Storage reads require a sealed object, current thread membership, matching sender, and a message that has not been deleted. The Storage evaluator uses two Firestore documents. Client metadata updates and overwrites are denied. Firebase's reserved download tokens are not exposed in Storage rule metadata; server-side removal is essential.

The migration patches the current live policy, preserves unrelated policies, checks that the live ruleset did not change during testing, and only then publishes. It excludes users/{uid}/chat from the prior public users wildcard, attaches legacy message IDs, removes legacy tokens without deleting media, and verifies anonymous requests (including every old token) fail. Do not restore the previous broad public users rule.

The app uses in-memory images and app-private temporary audio files. Audio files are deleted when playback widgets close or accounts change; leftovers from terminated processes are cleaned before the next private audio playback. Previously downloaded external copies cannot be revoked. This is access control, not end-to-end encryption: privileged backend access still exposes stored media.

The corrected client must be included in the next Android/iOS release. Old client versions cannot upload to the retired public chat path. Token-based media rendering in old versions may stop working after revocation. This branch includes the previously validated single-view/replay photo and camera/menu fixes; it must not be replaced by the older main branch.

Validation pipeline: .github/workflows/chat_media_security.yml. Tests include outsider/anonymous/removed-member denial, deleted messages, owner-scoped uploads, immutable metadata, finalizer auth/path checks, token-removal retries, and the prior one-view/replay guarantees. Production deployment is gated on these tests plus Flutter analysis, tests, and a debug application bundle.
