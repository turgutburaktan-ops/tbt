# TBT screen recording review — 2026-10-05

Evidence: user upload `1000443110.mp4`, 201.17 seconds, 1080×2340, no audio track. Times below are approximate. The recording does not expose the installed build number. Observations are not physical-device verification of the changes.

| Time | Finding | Action / limit |
| --- | --- | --- |
| 00:15–00:39 | Reels repeatedly shows a black loading screen during transitions. | Original-byte prefetch and cover placeholders already exist in the Sep 30 source. Included in the regression run; this recording does not establish that the device contains that patch. No bitrate/resolution change. Device comparison after installing a new package remains necessary. |
| 00:51 onward | Floating Admin entry covers Mekânlar and Çevrende headings. | Reserve a separate 44 px strip for the admin entry. Ordinary users retain the full viewport. Backend authorization unchanged. |
| 01:00–01:06 | Harput detail opens the old route planner, whose known initial stop is hidden behind catalog loading. | Point this entry to RouteCreateScreen with Harput as the initial stop, matching the route wizard used by place-list selections. |
| 01:15–02:01 | Many business cards have empty photo placeholders. | Code consumes venue.imageUrl; OSM/business records may lack a usable photo. No guessed photos or remote records changed. Coverage/data check remains open. |
| 02:19–02:22 | Meeting-point map opens around the selected route; user returns without choosing a point. | Not sufficient evidence of save failure. Initial route coordinates are passed correctly. No speculative map behavior change. |
| 02:52–03:00 | Profile post feed shows a column of tiny spinners before cards expand. | Use a card-sized loading placeholder while the server resolves visibility. Keeps lazy list from eagerly starting all pending cards. Server visibility checks and live invalidation retained. |
| 03:10–03:13 | Another profile initially has zero counts and loading content. | A transient state is visible; recording alone does not establish incorrect final counts. No guessed count fix. |

## Verification

Remote source commit: c8aae9083f68743d4eeff6727fdb8eca12f1b25c.
Workflow: Verify October video review fixes, run 37300330827.
Result: SUCCESS. Targeted Flutter analysis passed; 25 tests passed. Job 111731258476. This is automated verification, not a physical-device or store-release check.

Regression scope: bounded lazy feed loading, route wizard and selection modes, ready-route events, original-byte Reels cache and video controller lifecycle.

Not shown / not verified by this recording: successful event publication, chat send/receive, album upload/download, camera capture, push delivery, iOS behavior. No store submission or production deployment performed as part of this review.
