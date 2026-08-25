import 'package:cloud_functions/cloud_functions.dart';

class AdminConsoleService {
  AdminConsoleService._();
  static final instance = AdminConsoleService._();

  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(region: 'europe-west1');

  Future<List<Map<String, dynamic>>> businessClaims() async {
    final result = await _functions.httpsCallable('getAdminBusinessClaims').call();
    final data = Map<String, dynamic>.from(result.data as Map);
    final raw = (data['items'] as List?) ?? const [];
    return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<AdminInsightsData> insights() async {
    final result = await _functions.httpsCallable('getAdminInsights').call();
    final data = Map<String, dynamic>.from(result.data as Map);
    final counts = Map<String, dynamic>.from((data['counts'] as Map?) ?? const {});
    final errors = ((data['errors'] as List?) ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
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
