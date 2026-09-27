import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import '../lib/models/chat_message.dart';
import '../lib/screens/chat_photo_preview_screen.dart';
import '../lib/services/private_photo_service.dart';

void main() {
  test('private image is resized and the server byte cap is respected', () {
    final original = img.Image(width: 2200, height: 1800);
    final bytes = preparePrivatePhoto(img.encodePng(original));
    expect(bytes.length, lessThanOrEqualTo(512 * 1024));
    expect(img.decodeJpg(bytes)!.width, 1280);
    expect(() => preparePrivatePhoto(Uint8List.fromList([0,1])), throwsException);
  });
  test('replay counts are per user and never show a negative balance', () {
    const message = ChatMessage(id:'p',senderId:'s',text:'photo',type:'private_photo',
      photoMode:'replay',photoViews:{'a':1,'b':2},createdAt:null,deleted:false);
    expect(message.isPrivatePhoto, isTrue);
    expect(message.isImage, isFalse);
    expect(message.remainingPhotoViews('a'),1);
    expect(message.remainingPhotoViews('b'),0);
    expect(message.remainingPhotoViews('c'),2);
  });
  testWidgets('preview keeps ordinary photos default and returns selected replay mode', (tester) async {
    ChatPhotoMode? mode;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) => Scaffold(
      body: TextButton(onPressed: () async {
        mode = await Navigator.push<ChatPhotoMode>(context, MaterialPageRoute(
          builder: (_) => ChatPhotoPreviewScreen(bytes: img.encodePng(img.Image(width:2,height:2)))));
      }, child: const Text('Open'))))));
    await tester.tap(find.text('Open')); await tester.pumpAndSettle();
    await tester.tap(find.text('② Tekrar oynatmaya izin ver')); await tester.pumpAndSettle();
    await tester.tap(find.text('Gönder')); await tester.pumpAndSettle();
    expect(mode,ChatPhotoMode.replay);
    expect(tester.takeException(), isNull);
  });
}
