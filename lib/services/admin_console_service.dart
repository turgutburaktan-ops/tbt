import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminConsoleService {
  AdminConsoleService._();
  static final instance = AdminConsoleService._();

  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'europe-west1',
  );

  Future<void> _ensureFreshAdminAuth() async {
    final current = FirebaseAuth.instance.currentUser;
    if (current == null) {
      throw FirebaseAuthException(
        code: 'not-signed-in',
        message: 'Yönetici işlemi için giriş gerekli.',
      );
    }
    await current.reload();
    final refreshed = FirebaseAuth.instance.currentUser;
    if (refreshed == null) {
      throw FirebaseAuthException(
        code: 'not-signed-in',
        message: 'Yönetici oturumu bulunamadı.',
      );
    }
    await refreshed.getIdToken(true);
    final token = await refreshed.getIdTokenResult();
    if (token.claims?['admin'] != true) {
      throw FirebaseAuthException(
        code: 'admin-claim-missing',
        message: 'Yönetici yetkisi doğrulanamadı.',
      );
    }
  }

  Future<Map<String, dynamic>> overview() async {
    await _ensureFreshAdminAuth();
    final result = await _functions.httpsCallable('adminGetOverview').call();
    return Map<String, dynamic>.from(result.data as Map);
  }

  Future<List<Map<String, dynamic>>> recentUsers({int limit = 60}) async {
    await _ensureFreshAdminAuth();
    final result = await _functions
        .httpsCallable('adminListRecentUsers')
        .call({'limit': limit});
    final data = Map<String, dynamic>.from(result.data as Map);
    return (data['items'] as List? ?? const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  Future<List<Map<String, dynamic>>> businessClaims({int limit = 120}) async {
    await _ensureFreshAdminAuth();
    final result = await _functions
        .httpsCallable('getAdminBusinessClaims')
        .call({'limit': limit});
    final data = Map<String, dynamic>.from(result.data as Map);
    return (data['items'] as List? ?? const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  Future<void> reviewBusinessClaim({
    required String category,
    required String venueId,
    required bool approve,
    String reason = '',
  }) async {
    await _ensureFreshAdminAuth();
    await _functions.httpsCallable('adminReviewBusinessClaim').call({
      'category': category,
      'venueId': venueId,
      'decision': approve ? 'verified' : 'rejected',
      'reason': reason.trim(),
    });
  }

  Future<AdminInsightsData> insights() async {
    await _ensureFreshAdminAuth();
    final result = await _functions.httpsCallable('getAdminInsights').call();
    final data = Map<String, dynamic>.from(result.data as Map);
    final counts = Map<String, dynamic>.from(
      (data['counts'] as Map?) ?? const {},
    );
    final errors = ((data['errors'] as List?) ?? const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    return AdminInsightsData(counts: counts, errors: errors);
  }
}

class AdminInsightsData {
  final Map<String, dynamic> counts;
  final List<Map<String, dynamic>> errors;

  const AdminInsightsData({required this.counts, required this.errors});

  int value(String key) => (counts[key] as num?)?.toInt() ?? 0;
}
