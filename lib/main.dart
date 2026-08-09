import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'services/favorites_service.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();

  await FavoritesService.init();

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
      home: const HomeScreen(),
    );
  }
}
