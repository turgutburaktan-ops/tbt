import 'package:flutter_test/flutter_test.dart';
import 'package:best_photo_spot/firebase_options.dart';

void main() {
  test('Android Firebase options point to the production project', () {
    expect(AppFirebaseOptions.android.projectId, 'en-iyi-cekim-noktasi');
    expect(AppFirebaseOptions.android.messagingSenderId, '330568532415');
    expect(
      AppFirebaseOptions.android.appId,
      '1:330568532415:android:425699d143ec3eb041a10a',
    );
  });
}
