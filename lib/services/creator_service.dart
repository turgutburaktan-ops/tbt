import 'package:cloud_functions/cloud_functions.dart';

import 'discover_preferences.dart';

class CreatorService {
  CreatorService._();
  static final instance = CreatorService._();
  final _functions = FirebaseFunctions.instanceFor(region: 'europe-west1');

  void recordProfileVisit(String postId) {
    publishing('profileVisit', postId).catchError((_) => <String, dynamic>{});
  }

  Future<Map<String, dynamic>> studio(
    String action, [
    Map<String, dynamic> data = const {},
  ]) async {
    final result = await _functions.httpsCallable('creatorStudio').call({
      'action': action,
      ...data,
    });
    return Map<String, dynamic>.from(result.data as Map);
  }

  Future<Map<String, dynamic>> publishing(
    String action,
    String postId, [
    Map<String, dynamic> data = const {},
  ]) async {
    final result = await _functions.httpsCallable('socialPublishing').call({
      'action': action,
      'postId': postId,
      ...data,
    });
    if (data['enabled'] == true && (action == 'save' || action == 'repost')) {
      DiscoverPreferences.instance.signal(
        postId,
        action,
        action == 'save' ? 4 : 5,
      );
    }
    return Map<String, dynamic>.from(result.data as Map);
  }
}
