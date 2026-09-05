import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppLocaleService {
  AppLocaleService._();

  static final instance = AppLocaleService._();
  final ValueNotifier<Locale> locale = ValueNotifier(const Locale('tr'));

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    locale.value = Locale(prefs.getString('app_language') ?? 'tr');
  }

  Future<void> setLanguage(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_language', code);
    locale.value = Locale(code);
  }

  String languageName(String code) => switch (code) {
    'en' => 'English',
    'de' => 'Deutsch',
    'ar' => 'العربية',
    _ => 'Türkçe',
  };
}
