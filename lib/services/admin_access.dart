import 'package:firebase_auth/firebase_auth.dart';

/// Single source of truth for the private TBT administration account.
class AdminAccess {
  AdminAccess._();

  static const email = 'turgutburaktan@gmail.com';

  static bool emailMatches(User? user) =>
      (user?.email ?? '').trim().toLowerCase() == email;

  static bool tokenMatches(User? user, IdTokenResult? token) =>
      emailMatches(user) && token?.claims?['admin'] == true;

  static Future<bool> currentUserIsAuthorized({bool forceRefresh = true}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (!emailMatches(user)) return false;
    final token = await user!.getIdTokenResult(forceRefresh);
    return tokenMatches(user, token);
  }
}
