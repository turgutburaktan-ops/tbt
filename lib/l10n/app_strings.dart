import 'package:flutter/widgets.dart';

class AppStrings {
  final String code;
  const AppStrings(this.code);

  static AppStrings of(BuildContext context) => AppStrings(Localizations.localeOf(context).languageCode);

  String text(String key) => (_values[code] ?? _values['en']!)[key] ?? _values['en']![key] ?? key;

  static const _values = <String, Map<String, String>>{
    'tr': {'home':'Ana Sayfa','places':'Mekanlar','plan':'Planla','nearby':'Çevrende','profile':'Profil','discover':'Keşfet','forYou':'Sana Özel','following':'Takip','welcome':'TBT’ye hoş geldin','welcomeBody':'Keşfet, paylaş ve topluluğa katıl.','identifier':'Kullanıcı adı veya e-posta','password':'Şifre','login':'Giriş Yap'},
    'en': {'home':'Home','places':'Places','plan':'Plan','nearby':'Nearby','profile':'Profile','discover':'Discover','forYou':'For You','following':'Following','welcome':'Welcome to TBT','welcomeBody':'Discover, share and join the community.','identifier':'Username or email','password':'Password','login':'Sign In'},
    'de': {'home':'Start','places':'Orte','plan':'Planen','nearby':'In der Nähe','profile':'Profil','discover':'Entdecken','forYou':'Für dich','following':'Gefolgt','welcome':'Willkommen bei TBT','welcomeBody':'Entdecken, teilen und der Community beitreten.','identifier':'Benutzername oder E-Mail','password':'Passwort','login':'Anmelden'},
    'ar': {'home':'الرئيسية','places':'الأماكن','plan':'خطط','nearby':'بالقرب','profile':'الملف','discover':'استكشف','forYou':'لك','following':'المتابَعون','welcome':'مرحباً بك في TBT','welcomeBody':'اكتشف وشارك وانضم إلى المجتمع.','identifier':'اسم المستخدم أو البريد','password':'كلمة المرور','login':'تسجيل الدخول'},
  };
}
