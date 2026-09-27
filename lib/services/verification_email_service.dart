import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';

class VerificationEmailSendResult {
  final bool alreadyVerified;
  final int retryAfterSeconds;

  const VerificationEmailSendResult({
    required this.alreadyVerified,
    required this.retryAfterSeconds,
  });
}

class VerificationEmailService {
  VerificationEmailService._();
  static final instance = VerificationEmailService._();

  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    app: Firebase.app(),
    region: 'europe-west1',
  );

  Future<VerificationEmailSendResult> send() async {
    final response = await _functions
        .httpsCallable('sendVerificationEmail')
        .call()
        .timeout(const Duration(seconds: 18));
    final data = Map<String, dynamic>.from((response.data as Map?) ?? const {});
    return VerificationEmailSendResult(
      alreadyVerified: data['alreadyVerified'] == true,
      retryAfterSeconds: (data['retryAfterSeconds'] as num?)?.toInt() ?? 60,
    );
  }

  String messageFor(Object error) {
    if (error is TimeoutException) {
      return 'E-posta servisine ulaşılamadı. Tekrar dene.';
    }
    if (error is FirebaseFunctionsException) {
      if (error.code == 'resource-exhausted') {
        return error.message ?? 'Tekrar göndermek için biraz bekle.';
      }
      if (error.code == 'unauthenticated') {
        return 'Oturumun yenilenmeli. Çıkış yapıp tekrar giriş yap.';
      }
      return error.message ?? 'Doğrulama e-postası gönderilemedi.';
    }
    return 'Doğrulama e-postası gönderilemedi. Tekrar dene.';
  }
}
