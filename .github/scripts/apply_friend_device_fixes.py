from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if new in text:
        return text
    if old not in text:
        raise SystemExit(f'Missing patch target: {label}')
    return text.replace(old, new, 1)


# Google Sign-In: keep native flow, but fall back to Firebase provider flow.
# This makes sideload/debug APKs usable even when the local Google Sign-In SDK
# rejects a changing CI debug certificate.
p = Path('lib/services/auth_service.dart')
s = p.read_text()
old = """  Future<UserCredential?> signInWithGoogle() async {
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
    } on FirebaseAuthException catch (e) {
      throw Exception(_messageFromCode(e.code));
    } catch (_) {
      throw Exception('Google ile giriş tamamlanamadı.');
    }
  }
"""
new = """  Future<UserCredential?> signInWithGoogle() async {
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
"""
s = replace_once(s, old, new, 'Google fallback sign-in')
p.write_text(s)


# Places: give the embedded page a real header and make cards readable on
# smaller phones instead of compressing text next to the route button.
p = Path('lib/screens/spot_explore_screen_v2.dart')
s = p.read_text()
header_marker = """        slivers: [
          if (!widget.embedded)
"""
header_insert = """        slivers: [
          if (widget.embedded)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 10, 16, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Mekanlar', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -.35)),
                    SizedBox(height: 3),
                    Text('Türkiye genelindeki gezilecek ve fotoğraf çekilecek yerleri keşfet.', style: TextStyle(color: Color(0x75FFFFFF), fontSize: 11.5)),
                  ],
                ),
              ),
            ),
          if (!widget.embedded)
"""
s = replace_once(s, header_marker, header_insert, 'embedded places header')
s = s.replace("SpotImage(spot: spot, width: 82, height: 96", "SpotImage(spot: spot, width: 96, height: 108")
s = s.replace("fontSize: 14.5, height: 1.12", "fontSize: 16.5, height: 1.15")
s = s.replace("fontSize: 10.8", "fontSize: 11.5")
s = s.replace("fontSize: 11, fontWeight: FontWeight.w800", "fontSize: 12, fontWeight: FontWeight.w800")
s = s.replace("fontSize: 9.8, fontWeight: FontWeight.w700", "fontSize: 10.5, fontWeight: FontWeight.w700")
s = s.replace("fontSize: 10.5, fontWeight: FontWeight.w900", "fontSize: 11.5, fontWeight: FontWeight.w900")
s = s.replace("minimumSize: const Size(38, 38)", "minimumSize: const Size(44, 44)")
p.write_text(s)
