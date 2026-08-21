import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'screens/app_entry_gate.dart';
import 'screens/campus_home_screen.dart';
import 'screens/campus_profile_screen.dart';
import 'screens/chat_inbox_screen.dart';
import 'screens/communities_screen.dart';
import 'screens/notifications_screen.dart';
import 'services/deep_link_service.dart';
import 'services/favorites_service.dart';
import 'services/push_notification_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  Object? bootstrapError;
  try {
    await Firebase.initializeApp(
      options: AppFirebaseOptions.currentPlatform,
    ).timeout(const Duration(seconds: 15));
    await FavoritesService.initialize();
  } catch (error, stackTrace) {
    bootstrapError = error;
    debugPrint('Application bootstrap failed: $error');
    debugPrintStack(stackTrace: stackTrace);
  }

  runApp(
    bootstrapError == null
        ? const BestPhotoSpotApp()
        : BootstrapFailureApp(error: bootstrapError.toString()),
  );
}

class BootstrapFailureApp extends StatelessWidget {
  final String error;

  const BootstrapFailureApp({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Başlangıç bağlantısı kurulamadı. İnternet bağlantını kontrol edip uygulamayı yeniden aç.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white60, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    error,
                    maxLines: 5,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
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
    DeepLinkService.instance.start(_navigatorKey);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      PushNotificationService.instance.initialize(_navigatorKey);
    });
  }

  @override
  void dispose() {
    DeepLinkService.instance.dispose();
    PushNotificationService.instance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'En İyi Çekim Noktası',
      theme: AppTheme.dark,
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
        '/campus': (_) => const CampusHomeScreen(),
        '/campus-profile': (_) => const CampusProfileScreen(),
        '/communities': (_) => const CommunitiesScreen(),
      },
      home: const AppEntryGate(),
    );
  }
}
