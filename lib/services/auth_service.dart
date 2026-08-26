import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
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
      try {
        final account = await _googleSignIn.signIn();
        if (account == null) return null;
        final authentication = await account.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: authentication.accessToken,
          idToken: authentication.idToken,
        );
        final result = await _auth.signInWithCredential(credential);
        await _ensureSocialProfile(result.user, provider: 'google');
        return result;
      } catch (_) {
        // GitHub Actions debug APKs can be signed with a CI-generated debug
        // certificate that is not registered in Google OAuth. In that case,
        // use Firebase's provider flow instead of failing the whole login.
        try {
          await _googleSignIn.signOut();
        } catch (_) {}
        final result = await _auth.signInWithProvider(GoogleAuthProvider());
        await _ensureSocialProfile(result.user, provider: 'google');
        return result;
      }
    } on FirebaseAuthException catch (e) {
      throw Exception(_messageFromCode(e.code));
    } catch (_) {
      throw Exception('Google ile giriş tamamlanamadı. Lütfen tekrar deneyin.');
    }
  }

  Future<UserCredential> signInWithApple() async {
    try {
      final provider = AppleAuthProvider()
        ..addScope('email')
        ..addScope('name');
      final result = await _auth.signInWithProvider(provider);
      await _ensureSocialProfile(result.user, provider: 'apple');
      return result;
    } on FirebaseAuthException catch (e) {
      throw Exception(_messageFromCode(e.code));
    } catch (_) {
      throw Exception('Apple ile giriş tamamlanamadı.');
    }
  }

  Future<void> _ensureSocialProfile(
    User? user, {
    required String provider,
  }) async {
    if (user == null) return;
    final ref = _firestore.collection('users').doc(user.uid);
    final existing = await ref.get();
    final data = existing.data();

    final fallbackName = (user.displayName ?? '').trim();
    await ref.set({
      'uid': user.uid,
      'email': user.email ?? data?['email'] ?? '',
      'phoneNumber': user.phoneNumber ?? data?['phoneNumber'] ?? '',
      'displayName': fallbackName.isNotEmpty
          ? fallbackName
          : (data?['displayName'] ?? '').toString(),
      'authProvider': provider,
      'onboardingRequired': data == null
          ? true
          : (data['onboardingRequired'] ?? false),
      'onboardingCompleted': data == null
          ? false
          : (data['onboardingCompleted'] ?? false),
      if (data == null) 'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
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
          await _ensureSocialProfile(result.user, provider: 'phone');
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
      final result = await _auth.signInWithCredential(credential);
      await _ensureSocialProfile(result.user, provider: 'phone');
      return result;
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
      case 'operation-not-allowed':
        return 'Bu giriş yöntemi Firebase tarafında henüz etkin değil.';
      case 'web-context-cancelled':
      case 'canceled-popup-request':
        return 'Giriş işlemi iptal edildi.';
      default:
        return 'Giriş işlemi tamamlanamadı: $code';
    }
  }
}
