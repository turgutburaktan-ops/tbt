import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppLocaleService {
  AppLocaleService._();

  static final instance = AppLocaleService._();
  final ValueNotifier<Locale> locale = ValueNotifier(const Locale('tr'));

  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString('app_language') ?? 'tr';
      locale.value = Locale(['tr', 'en', 'de', 'ar'].contains(code) ? code : 'tr');
    } catch (_) { /* Keep the app usable when local preferences are unavailable. */ }
  }

  Future<void> setLanguage(String code) async {
    if (!['tr', 'en', 'de', 'ar'].contains(code)) return;
    locale.value = Locale(code);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('app_language', code);
    } catch (_) { /* The selection still applies to this session. */ }
  }

  String languageName(String code) => switch (code) {
    'en' => 'English',
    'de' => 'Deutsch',
    'ar' => 'العربية',
    _ => 'Türkçe',
  };
}
