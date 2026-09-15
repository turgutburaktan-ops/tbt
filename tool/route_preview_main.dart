// Local/emulator visual review entry point. Never used by the store build.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../lib/models/photo_spot.dart';
import '../lib/screens/route_create_screen.dart';
import '../lib/theme/app_theme.dart';

void main() => runApp(
  MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.dark,
    locale: const Locale('tr'),
    supportedLocales: const [Locale('tr')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    home: const RouteCreateScreen(
      initialStops: [
        PhotoSpot(
          id: 'harput-kalesi',
          name: 'Harput Kalesi',
          city: 'Elazığ',
          latitude: 38.7036,
          longitude: 39.2565,
          rating: 4.8,
          bestTime: '',
          angle: '',
          imageUrl: '',
          category: 'Tarihi yer',
        ),
        PhotoSpot(
          id: 'elazig-harput-ulu-camii',
          name: 'Harput Ulu Camii',
          city: 'Elazığ',
          latitude: 38.7052,
          longitude: 39.2528,
          rating: 4.8,
          bestTime: '',
          angle: '',
          imageUrl: '',
          category: 'Tarihi yer',
        ),
        PhotoSpot(
          id: 'elazig-alacali-camii',
          name: 'Alacalı Camii',
          city: 'Elazığ',
          latitude: 38.7067,
          longitude: 39.2510,
          rating: 4.7,
          bestTime: '',
          angle: '',
          imageUrl: '',
          category: 'Tarihi yer',
        ),
      ],
    ),
  ),
);
