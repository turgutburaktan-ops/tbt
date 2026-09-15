Runtime startup fix notes:
- Android Firebase is initialized with explicit FirebaseOptions matching project en-iyi-cekim-noktasi.
- Android applicationId used by CI is aligned with registered package com.example.tbt.
- INTERNET permission is present in the production manifest.
- Startup failures render an in-app diagnostic screen instead of leaving the native Flutter splash indefinitely.
