import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();
  bool get isLoggedIn => _auth.currentUser != null;

  Future<UserCredential> register({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw Exception(_messageFromCode(e.code));
    } catch (_) {
      throw Exception('Hesap oluşturulurken bir hata oluştu.');
    }
  }

  Future<UserCredential> login({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw Exception(_messageFromCode(e.code));
    } catch (_) {
      throw Exception('Giriş yapılırken bir hata oluştu.');
    }
  }

  Future<UserCredential?> signInWithGoogle() async {
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) return null;
      final authentication = await account.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: authentication.accessToken,
        idToken: authentication.idToken,
      );
      return await _auth.signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      throw Exception(_messageFromCode(e.code));
    } catch (_) {
      throw Exception('Google ile giriş tamamlanamadı.');
    }
  }

  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required void Function(String verificationId) codeSent,
    required void Function(String message) failed,
    void Function(UserCredential credential)? autoVerified,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: (credential) async {
        try {
          final result = await _auth.signInWithCredential(credential);
          autoVerified?.call(result);
        } on FirebaseAuthException catch (e) {
          failed(_messageFromCode(e.code));
        }
      },
      verificationFailed: (e) => failed(_messageFromCode(e.code)),
      codeSent: (verificationId, _) => codeSent(verificationId),
      codeAutoRetrievalTimeout: (_) {},
      timeout: const Duration(seconds: 60),
    );
  }

  Future<UserCredential> confirmPhoneCode({
    required String verificationId,
    required String smsCode,
  }) async {
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode.trim(),
      );
      return await _auth.signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      throw Exception(_messageFromCode(e.code));
    }
  }

  Future<void> logout() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw Exception(_messageFromCode(e.code));
    }
  }

  Future<void> updateDisplayName(String name) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Oturum açmış kullanıcı bulunamadı.');
    await user.updateDisplayName(name.trim());
    await user.reload();
  }

  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Oturum açmış kullanıcı bulunamadı.');
    await user.delete();
  }

  String _messageFromCode(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'Bu e-posta adresi zaten kullanılıyor.';
      case 'invalid-email':
        return 'Geçerli bir e-posta adresi girin.';
      case 'weak-password':
        return 'Daha güçlü bir şifre belirleyin.';
      case 'user-not-found':
        return 'Bu e-posta ile kayıtlı kullanıcı bulunamadı.';
      case 'wrong-password':
        return 'Şifre hatalı.';
      case 'invalid-credential':
        return 'Giriş bilgileri hatalı.';
      case 'invalid-verification-code':
        return 'Doğrulama kodu hatalı.';
      case 'invalid-phone-number':
        return 'Telefon numarası geçersiz.';
      case 'quota-exceeded':
        return 'SMS doğrulama kotası aşıldı. Daha sonra tekrar deneyin.';
      case 'too-many-requests':
        return 'Çok fazla deneme yapıldı. Bir süre sonra tekrar deneyin.';
      case 'network-request-failed':
        return 'İnternet bağlantısını kontrol edin.';
      case 'user-disabled':
        return 'Bu kullanıcı hesabı devre dışı bırakılmış.';
      case 'requires-recent-login':
        return 'Bu işlem için yeniden giriş yapmanız gerekiyor.';
      case 'account-exists-with-different-credential':
        return 'Bu e-posta farklı bir giriş yöntemiyle kayıtlı.';
      default:
        return 'Giriş işlemi tamamlanamadı: $code';
    }
  }
}
