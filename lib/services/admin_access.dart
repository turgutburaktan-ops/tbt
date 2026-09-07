import 'package:firebase_auth/firebase_auth.dart';

enum AdminAccessStatus {
  allowed,
  signedOut,
  wrongAccount,
  emailUnverified,
  claimMissing,
  unavailable,
}

/// Single source of truth for the private TBT administration account.
class AdminAccess {
  AdminAccess._();

  static const email = 'turgutburaktan@gmail.com';

  static bool emailMatches(User? user) =>
      (user?.email ?? '').trim().toLowerCase() == email;

  static bool tokenMatches(User? user, IdTokenResult? token) =>
      emailMatches(user) && token?.claims?['admin'] == true &&
      token?.claims?['email_verified'] == true;

  static Future<AdminAccessStatus> currentStatus({
    bool forceRefresh = true,
  }) async {
    var user = FirebaseAuth.instance.currentUser;
    if (user == null) return AdminAccessStatus.signedOut;
    if (!emailMatches(user)) return AdminAccessStatus.wrongAccount;

    try {
      await user.reload().timeout(const Duration(seconds: 8));
      user = FirebaseAuth.instance.currentUser;
    } catch (_) {
      // A cached, still-valid token can keep the private panel usable during
      // a short Firebase connectivity interruption.
    }
    if (user == null) return AdminAccessStatus.signedOut;
    if (!emailMatches(user)) return AdminAccessStatus.wrongAccount;
    if (!user.emailVerified) return AdminAccessStatus.emailUnverified;

    IdTokenResult? token;
    try {
      token = await user
          .getIdTokenResult(forceRefresh)
          .timeout(const Duration(seconds: 12));
    } catch (_) {
      if (!forceRefresh) return AdminAccessStatus.unavailable;
      try {
        token = await user
            .getIdTokenResult()
            .timeout(const Duration(seconds: 5));
      } catch (_) {
        return AdminAccessStatus.unavailable;
      }
    }
    if (tokenMatches(user, token)) return AdminAccessStatus.allowed;
    return AdminAccessStatus.claimMissing;
  }

  static Future<bool> currentUserIsAuthorized({bool forceRefresh = true}) async {
    return await currentStatus(forceRefresh: forceRefresh) ==
        AdminAccessStatus.allowed;
  }
}
