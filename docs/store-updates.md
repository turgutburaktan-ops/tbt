# Store updates

The app checks automatically after startup and on returning from an update. Ordinary prompts may be postponed for 24 hours per version. The installer must be Google Play (`com.android.vending`) or the App Store (`com.apple`); APK, TestFlight and simulator installs are excluded.

Android uses Play's device/account-specific availability and flexible download, with an explicit restart/install action. A downloaded update is recovered on resume. Critical updates prefer Play's immediate flow. Cancellation/failure leaves a retry action; no silent APK installation is attempted.

iOS looks up app 6808182194 in Apple's regional catalog (device region, Turkey fallback), verifies bundle ID and minimum iOS compatibility, then opens the fixed App Store listing. A device region can differ from the user's App Store region; verify distribution in all supported storefronts before raising the iOS minimum. App Store controls installation and automatic update timing.

## Critical releases

Server-only Firestore document: `app_config/update_policy`.

- `androidMinimumBuild`: integer version code; absent/0 means optional.
- `iosMinimumVersion`: dotted release version; absent/`0.0.0` means optional.

Write this document using the existing authorized Admin SDK/release tooling only. Clients have read-only access. Raise a minimum only after the compatible release is available in its store, and after testing with a lower store-installed version. Android's offered version and iOS's lookup version must reach the configured minimum before a mandatory prompt appears. An unavailable minimum never locks out users. To roll back mandatory enforcement, set the floor back to 0 / `0.0.0`.

Missing policy, network errors and store errors do not block startup. No minimum is raised by this change. Android closed-test users must be enrolled and see a greater version code under the same application ID and signing identity. Device installation/consent and iOS storefront behavior require store-device testing; widget tests cannot validate actual installation.
