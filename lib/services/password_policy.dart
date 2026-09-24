/// Shared registration and password-change requirements. Do not trim passwords.
class PasswordPolicy {
  static const hint = 'En az 10 karakter; büyük harf, küçük harf, rakam ve sembol';
  static const message = 'Şifre en az 10 karakter olmalı; büyük harf, küçük harf, rakam ve sembol içermeli.';
  static bool hasLength(String value) => value.length >= 10;
  static bool hasUpper(String value) => RegExp(r'[A-ZÇĞİÖŞÜ]').hasMatch(value);
  static bool hasLower(String value) => RegExp(r'[a-zçğıöşü]').hasMatch(value);
  static bool hasDigit(String value) => RegExp(r'\d').hasMatch(value);
  static bool hasSymbol(String value) => RegExp(r'[^A-Za-z0-9çÇğĞıİöÖşŞüÜ]').hasMatch(value);
  static bool accepts(String value) => hasLength(value) && hasUpper(value) && hasLower(value) && hasDigit(value) && hasSymbol(value);
}
