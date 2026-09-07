import 'dart:async';
import 'dart:ui';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'firebase_options.dart';
import 'screens/admin_business_premium_screen.dart';
import 'screens/admin_business_preview_screen.dart';
import 'screens/admin_businesses_v2_screen.dart';
import 'screens/admin_dashboard_screen.dart';
import 'screens/admin_insights_screen.dart';
import 'screens/admin_operations_screen.dart';
import 'screens/admin_portal_screen.dart';
import 'screens/admin_spot_submissions_screen.dart';
import 'screens/admin_published_spots_screen.dart';
import 'screens/app_entry_gate.dart';
import 'screens/install_onboarding_gate.dart';
import 'screens/business_web_portal_screen.dart';
import 'screens/campus_home_screen.dart';
import 'screens/campus_profile_screen.dart';
import 'screens/chat_inbox_screen.dart';
import 'screens/communities_screen.dart';
import 'screens/global_search_screen.dart';
import 'screens/moderation_center_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/rewards_hub_screen.dart';
import 'screens/safety_privacy_center_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/story_archive_screen.dart';
import 'services/app_observability_service.dart';
import 'services/app_locale_service.dart';
import 'services/deep_link_service.dart';
import 'services/favorites_service.dart';
import 'services/push_notification_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    if (kDebugMode) debugPrint('Flutter error: ${details.exceptionAsString()}');
    if (Firebase.apps.isNotEmpty) {
      unawaited(
        AppObservabilityService.instance.recordError(
          details.exception,
          details.stack ?? StackTrace.current,
          context: 'flutter_error',
        ),
      );
    }
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    if (kDebugMode) {
      debugPrint('Unhandled platform error: $error');
      debugPrintStack(stackTrace: stack);
    }
    if (Firebase.apps.isNotEmpty) {
      unawaited(
        AppObservabilityService.instance.recordError(
          error,
          stack,
          context: 'platform_error',
        ),
      );
    }
    return true;
  };

  await runZonedGuarded(
    () async {
      Object? bootstrapError;
      try {
        await Firebase.initializeApp(
          options: AppFirebaseOptions.currentPlatform,
        ).timeout(const Duration(seconds: 15));
      } catch (error, stackTrace) {
        bootstrapError = error;
        if (kDebugMode) {
          debugPrint('Firebase bootstrap failed: $error');
          debugPrintStack(stackTrace: stackTrace);
        }
      }
      await AppLocaleService.instance.initialize();

      runApp(
        bootstrapError == null
            ? const BestPhotoSpotApp()
            : BootstrapFailureApp(
                debugError: kDebugMode ? bootstrapError.toString() : null,
              ),
      );

      // The first frame must never wait for optional native services. A
      // missing/unsupported SDK configuration should degrade one feature,
      // not terminate the whole app on the Android launch screen.
      if (bootstrapError == null) {
        unawaited(_initializeDeferredBootstrapServices());
      }
    },
    (error, stack) {
      if (kDebugMode) {
        debugPrint('Uncaught zone error: $error');
        debugPrintStack(stackTrace: stack);
      }
      if (Firebase.apps.isNotEmpty) {
        unawaited(
          AppObservabilityService.instance.recordError(
            error,
            stack,
            context: 'zone_error',
          ),
        );
      }
    },
  );
}

Future<void> _initializeDeferredBootstrapServices() async {
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS)) {
    try {
      await MobileAds.instance.initialize().timeout(const Duration(seconds: 8));
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('Ads initialization skipped: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    }
  }

  try {
    await FirebaseAppCheck.instance
        .activate(
          providerAndroid: kDebugMode
              ? const AndroidDebugProvider()
              : const AndroidPlayIntegrityProvider(),
          providerApple: kDebugMode
              ? const AppleDebugProvider()
              : const AppleAppAttestWithDeviceCheckFallbackProvider(),
        )
        .timeout(const Duration(seconds: 8));
  } catch (error, stackTrace) {
    if (kDebugMode) {
      debugPrint('App Check activation skipped: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  try {
    await FavoritesService.initialize().timeout(const Duration(seconds: 4));
  } catch (error, stackTrace) {
    if (kDebugMode) {
      debugPrint('Favorites initialization skipped: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  try {
    await AppObservabilityService.instance.initialize().timeout(
      const Duration(seconds: 4),
    );
  } catch (error, stackTrace) {
    if (kDebugMode) {
      debugPrint('Observability initialization skipped: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }
}

class BootstrapFailureApp extends StatelessWidget {
  final String? debugError;
  const BootstrapFailureApp({super.key, this.debugError});

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.dark,
    home: Scaffold(
      backgroundColor: const Color(0xFF090A0C),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  size: 54,
                  color: Colors.white70,
                ),
                const SizedBox(height: 18),
                const Text(
                  'Uygulama başlatılamadı',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Başlangıç bağlantısı kurulamadı. İnternet bağlantını kontrol edip uygulamayı yeniden aç.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white60, height: 1.4),
                ),
                if (debugError != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    debugError!,
                    maxLines: 5,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class BestPhotoSpotApp extends StatefulWidget {
  const BestPhotoSpotApp({super.key});

  @override
  State<BestPhotoSpotApp> createState() => _BestPhotoSpotAppState();
}

class _BestPhotoSpotAppState extends State<BestPhotoSpotApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    try {
      DeepLinkService.instance.start(_navigatorKey);
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('Deep link startup skipped: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_initializePostFrameServices());
    });
  }

  Future<void> _initializePostFrameServices() async {
    try {
      await PushNotificationService.instance.initialize(_navigatorKey).timeout(
        const Duration(seconds: 8),
      );
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('Push initialization skipped: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    }
    try {
      await AppObservabilityService.instance
          .logEvent('app_open')
          .timeout(const Duration(seconds: 3));
    } catch (_) {}
  }

  @override
  void dispose() {
    DeepLinkService.instance.dispose();
    PushNotificationService.instance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<Locale>(
    valueListenable: AppLocaleService.instance.locale,
    builder: (context, locale, _) => MaterialApp(
    navigatorKey: _navigatorKey,
    debugShowCheckedModeBanner: false,
    title: 'En İyi Çekim Noktası',
    theme: AppTheme.dark,
    locale: locale,
    supportedLocales: const [Locale('tr'), Locale('en'), Locale('de'), Locale('ar')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    builder: (context, child) {
      final media = MediaQuery.of(context);
      final currentScale = media.textScaler.scale(1.0);
      final clampedScale = currentScale.clamp(0.90, 1.25).toDouble();
      return MediaQuery(
        data: media.copyWith(textScaler: TextScaler.linear(clampedScale)),
        child: child ?? const SizedBox.shrink(),
      );
    },
    routes: {
      '/messages': (_) => const ChatInboxScreen(),
      '/notifications': (_) => const NotificationsScreen(),
      '/rewards': (_) => const RewardsHubScreen(),
      '/settings': (_) => const SettingsScreen(),
      '/story-archive': (_) => const StoryArchiveScreen(),
      '/business': (_) => const BusinessWebPortalScreen(),
      '/business-claim': (_) => const BusinessWebPortalScreen(),
      '/admin': (_) => const AdminPortalScreen(),
      '/admin-dashboard': (_) => const AdminDashboardScreen(),
      '/admin-users': (_) => const AdminUsersScreen(),
      '/admin-businesses': (_) => const AdminBusinessesV2Screen(),
      '/admin-business-premium': (_) => const AdminBusinessPremiumScreen(),
      '/admin-business-preview': (_) => const AdminBusinessPreviewScreen(),
      '/admin-growth': (_) => const AdminGrowthScreen(),
      '/admin-preview': (_) => const AdminRolePreviewScreen(),
      '/admin-insights': (_) => const AdminInsightsScreen(),
      '/admin-spot-submissions': (_) => const AdminSpotSubmissionsScreen(),
      '/admin-published-spots': (_) => const AdminPublishedSpotsScreen(),
      '/moderation': (_) => const ModerationCenterScreen(),
      '/safety-privacy': (_) => const SafetyPrivacyCenterScreen(),
      '/search': (_) => const GlobalSearchScreen(),
      '/campus': (_) => const CampusHomeScreen(),
      '/campus-profile': (_) => const CampusProfileScreen(),
      '/communities': (_) => const CommunitiesScreen(),
    },
    home: const InstallOnboardingGate(child: AppEntryGate()),
    ),
  );
}
