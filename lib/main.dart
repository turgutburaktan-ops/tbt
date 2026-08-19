import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

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
  await Firebase.initializeApp();
  await FavoritesService.initialize();
  runApp(const BestPhotoSpotApp());
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
