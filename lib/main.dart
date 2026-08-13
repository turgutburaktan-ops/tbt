import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'screens/chat_inbox_screen.dart';
import 'screens/home_screen.dart';
import 'services/favorites_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();
  await FavoritesService.initialize();

  runApp(const BestPhotoSpotApp());
}

class BestPhotoSpotApp extends StatelessWidget {
  const BestPhotoSpotApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'En İyi Çekim Noktası',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF080B10),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFFC107),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      routes: {
        '/messages': (_) => const ChatInboxScreen(),
      },
      home: const HomeScreen(),
    );
  }
}
