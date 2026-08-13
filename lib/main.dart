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
      home: const _HomeWithMessagesShortcut(),
    );
  }
}

class _HomeWithMessagesShortcut extends StatelessWidget {
  const _HomeWithMessagesShortcut();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const HomeScreen(),
        Positioned(
          right: 16,
          bottom: 88,
          child: SafeArea(
            top: false,
            child: Material(
              color: Colors.transparent,
              child: FloatingActionButton.extended(
                heroTag: 'messages_fab',
                backgroundColor: const Color(0xFF171C24),
                foregroundColor: const Color(0xFFFFC107),
                elevation: 8,
                onPressed: () {
                  Navigator.of(context).pushNamed('/messages');
                },
                icon: const Icon(Icons.chat_bubble_outline_rounded, size: 22),
                label: const Text(
                  'Mesajlar',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
