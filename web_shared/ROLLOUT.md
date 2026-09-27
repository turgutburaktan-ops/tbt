# Shared travel-place source

Web, Android and iOS read `en-iyi-cekim-noktasi / photo_spots`.
The collection was empty when checked on 2026-09-07. **Do not release these
readers before the frozen catalog has been audited, imported and verified.**
No catalog records or hosting configuration are changed by this branch.

## Contract

- Document ID is the canonical place ID on every platform.
- Query: `status == published`, `coordinateVerified == true`, ordered by
  document ID. Fetch in 500-document pages, without a 2000-result cap.
- Additionally reject missing `imageVerified == true`, empty name/city,
  invalid/out-of-Turkey coordinates and non-HTTPS images.
- Use identical global normalized-name and <=18m duplicate exclusion, in ID
  order, tested against the same fixtures on web and Dart.
- Preserve `imageUrl`; the web adapter derives remote 500px Commons previews.
- A successful empty response clears the list. No bundled/demo fallback may
  resurrect removed places. Failed reads keep only the last complete in-memory
  remote list, if one exists, and are retried after expiry (five minutes).
- Client flags are not source evidence: the publisher must validate district,
  province, coordinates, P18 identity, free license and >=1600x900 dimensions
  before setting the publication flags. This change does not certify 4486 rows.

## Website integration

The live custom JS SPA is not the Flutter web build or `hosting/index.html`.
Obtain its actual publishing checkout; do not deploy a partial mirrored site
or substitute another hosting project. In a complete staged copy, run:

```
python tool/patch_shared_spot_web.py /path/to/staged/public
node --check /path/to/staged/public/app.js
node --test web_shared/spot-catalog.test.mjs
```

The guarded patch replaces the hardcoded five-place array, loads the shared
source before gezi/search/plan pages, escapes remote strings, refreshes the
service-worker cache key, and adds `spot-catalog.mjs`. Smart gezi routes also
use that catalog instead of unaudited Overpass attractions. Business venue,
auth, admin and social modules remain untouched. Reapply to the latest source
if the website changed; an anchor mismatch must be reviewed, never forced.

## Release gate

1. Complete the frozen catalog audit. Import approved records, preserving IDs
   and image URLs. Verify actual accepted count; never assume 4486.
2. In staging, compare ID sets and Pertek's Tunceli/Pertek metadata across both
   readers. Check search beyond row 2000, direct detail links, city route
   selection, empty results, photo previews and removal after refresh.
3. Publish the complete web release through its verified host. Deliver the
   matching Flutter Android/iOS build. Existing installed builds keep their
   older bundled merge behavior until updated.
4. Verify the real site and installed apps, then report the live count.

The 10000-place discovery automation remains stopped. No crawlers, bulk
photo downloads, Firebase writes, or deployments run from the check workflow.
