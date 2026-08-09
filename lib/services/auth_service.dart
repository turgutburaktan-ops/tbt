import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  bool get isLoggedIn => _auth.currentUser != null;

  Future<UserCredential> register({
    required String email,
    required String password,
  }) async {
    try {
      final credential =
          await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      return credential;
    } on FirebaseAuthException catch (e) {
      throw Exception(
        _messageFromCode(e.code),
      );
    } catch (_) {
      throw Exception(
        'Hesap oluşturulurken bir hata oluştu.',
      );
    }
  }

  Future<UserCredential> login({
    required String email,
    required String password,
  }) async {
    try {
      final credential =
          await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      return credential;
    } on FirebaseAuthException catch (e) {
      throw Exception(
        _messageFromCode(e.code),
      );
    } catch (_) {
      throw Exception(
        'Giriş yapılırken bir hata oluştu.',
      );
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
  }

  Future<void> sendPasswordResetEmail(
    String email,
  ) async {
    try {
      await _auth.sendPasswordResetEmail(
        email: email.trim(),
      );
    } on FirebaseAuthException catch (e) {
      throw Exception(
        _messageFromCode(e.code),
      );
    }
  }

  Future<void> updateDisplayName(
    String name,
  ) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception(
        'Oturum açmış kullanıcı bulunamadı.',
      );
    }

    await user.updateDisplayName(
      name.trim(),
    );

    await user.reload();
  }

  Future<void> deleteAccount() async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception(
        'Oturum açmış kullanıcı bulunamadı.',
      );
    }

    await user.delete();
  }

  String _messageFromCode(
    String code,
  ) {
    switch (code) {
      case 'email-already-in-use':
        return 'Bu e-posta adresi zaten kullanılıyor.';

      case 'invalid-email':
        return 'Geçerli bir e-posta adresi girin.';

      case 'weak-password':
        return 'Şifre en az 6 karakter olmalı.';

      case 'user-not-found':
        return 'Bu e-posta ile kayıtlı kullanıcı bulunamadı.';

      case 'wrong-password':
        return 'Şifre hatalı.';

      case 'invalid-credential':
        return 'E-posta veya şifre hatalı.';

      case 'too-many-requests':
        return 'Çok fazla deneme yapıldı. Bir süre sonra tekrar deneyin.';

      case 'network-request-failed':
        return 'İnternet bağlantısını kontrol edin.';

      case 'user-disabled':
        return 'Bu kullanıcı hesabı devre dışı bırakılmış.';

      case 'requires-recent-login':
        return 'Bu işlem için yeniden giriş yapmanız gerekiyor.';

      default:
        return 'Firebase giriş hatası: $code';
    }
  }
}
