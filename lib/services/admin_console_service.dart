import 'package:cloud_functions/cloud_functions.dart';

class AdminConsoleService {
  AdminConsoleService._();
  static final instance = AdminConsoleService._();

  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'europe-west1',
  );

  Future<Map<String, dynamic>> overview() async {
    final result = await _functions.httpsCallable('adminGetOverview').call();
    return Map<String, dynamic>.from(result.data as Map);
  }

  Future<List<Map<String, dynamic>>> recentUsers({int limit = 60}) async {
    final result = await _functions
        .httpsCallable('adminListRecentUsers')
        .call({'limit': limit});
    final data = Map<String, dynamic>.from(result.data as Map);
    return (data['items'] as List? ?? const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  Future<List<Map<String, dynamic>>> businessClaims({int limit = 120}) async {
    final result = await _functions
        .httpsCallable('adminListBusinessClaims')
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
    await _functions.httpsCallable('adminReviewBusinessClaim').call({
      'category': category,
      'venueId': venueId,
      'decision': approve ? 'verified' : 'rejected',
      'reason': reason.trim(),
    });
  }
}
