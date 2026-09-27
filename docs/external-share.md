# External sharing and direct group additions

External content enters a draft, never an automatic publication. Android receives SEND/SEND_MULTIPLE images, videos and text. The iOS Share Extension receives the same categories; its scene delegate forwards cold and warm launches. Incoming files are copied into application support before the originating application's grants expire; pending drafts survive sign-in and app restart. Closing the import flow discards the pending intake and removes its copied media.

An Instagram/X URL alone is published as a source card with a locally rendered PNG thumbnail, an explicit source URL, and the ordinary post actions. It is not treated as a native video. Only allowlisted HTTPS sources can become source buttons; no scraping, cookies, remote media downloads or account integration are used. Native media flows use the existing post/story editors. Multiple videos remain separate drafts; photo posts retain the existing 10-image limit.

Group info replaces the invite-generation action with a searchable multiselect screen. Existing members are excluded and followed users come first. `chatAction(addMembers)` rechecks administrator membership, 50-member capacity, existence/account status and bilateral block relationships inside a transaction. Duplicate submissions are idempotent. Existing invitation links remain compatible with older clients.

## iOS release prerequisites

`tool/configure_ios_share.py` runs after a regenerated iOS host and preserves Runner settings. Register `com.tbt.social.TBTShare` and App Group `group.com.tbt.social.share`. Both Runner and TBTShare provisioning profiles must include that App Group. The release workflow expects a renewed `IOS_PROVISIONING_PROFILE_BASE64` and `IOS_SHARE_PROVISIONING_PROFILE_BASE64`; it checks the bundle IDs and App Group before archiving. Do not upload a release until these profiles are configured. No App Store account capabilities or secrets have been changed by this source update.

## Verification

Full Build checks Dart analysis/tests, Android APK, unsigned iOS app with the extension, and Firestore-emulator group authorization regressions. The source URL tests reject lookalike hosts, credential-bearing URLs and nonstandard ports. Emulator cases cover non-admin additions, repeat additions, removed-user re-addition, missing targets and blocked group members.

Before store submission verify on devices: cold/warm shares from Instagram and X, gallery multi-image and video intake, signed-out intake followed by login, cancel without publication, source-card opening, group member search and subsequent messaging. Build success alone does not establish a device-level share-sheet pass. iOS sender apps may supply only a URL.
