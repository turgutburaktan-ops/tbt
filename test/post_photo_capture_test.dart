import 'dart:io';
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:best_photo_spot/services/post_photo_capture_service.dart';

img.Image scene() {
  final result=img.Image(width:120,height:200);
  for(var y=0;y<200;y++) {for(var x=0;x<120;x++) {result.setPixelRgb(x,y,x,y,50);}}
  return result;
}
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('visible asymmetric frame selects the same pixels without rescaling', () {
    final output=cropPostPhoto(scene(),[.1,.2,.8,.6],0);
    expect(output.width,96);expect(output.height,120);
    expect(output.getPixel(0,0).r,12);expect(output.getPixel(0,0).g,40);
    expect(output.getPixel(95,119).r,107);expect(output.getPixel(95,119).g,159);
  });
  test('all four device rotations return to the portrait preview coordinates', () {
    for(var turns=0;turns<4;turns++) {
      final capture=img.copyRotate(scene(),angle:((4-turns)%4)*90);
      final output=cropPostPhoto(capture,[.1,.2,.8,.6],turns);
      expect(output.width,96);expect(output.height,120);
      expect(output.getPixel(0,0).r,12);expect(output.getPixel(0,0).g,40);
      expect(output.getPixel(95,119).r,107);expect(output.getPixel(95,119).g,159);
    }
  });
  test('EXIF rotation and front-camera reflection are baked exactly once', () {
    for(var orientation=1;orientation<=8;orientation++) {
      final raw=scene();raw.exif.imageIfd.orientation=orientation;
      final expected=img.bakeOrientation(raw);
      final units=(expected.width/4).floor().clamp(1,(expected.height/5).floor());
      final x=((expected.width-units*4)/2).round(),y=((expected.height-units*5)/2).round();
      final output=cropPostPhoto(raw,[0,0,1,1],0);
      expect(output.width,units*4);expect(output.height,units*5);
      expect(output.getPixel(0,0).r,expected.getPixel(x,y).r);
      expect(output.getPixel(0,0).g,expected.getPixel(x,y).g);
      expect(output.getPixel(output.width-1,0).r,expected.getPixel(x+output.width-1,y).r);
    }
  });
  test('file processing preserves the original and creates a decodable 4:5 JPEG', () async {
    final folder=await Directory.systemTemp.createTemp('post-frame-test');
    try {
      final input=File('${folder.path}/original.png');final bytes=img.encodePng(scene());
      await input.writeAsBytes(bytes);
      final output=await PostPhotoCaptureService.prepare(input,const Rect.fromLTWH(.1,.2,.8,.6),0);
      expect(await input.readAsBytes(),bytes);
      final decoded=img.decodeJpg(await output.readAsBytes())!;
      expect(decoded.width,96);expect(decoded.height,120);
      expect(decoded.getPixel(0,0).r,closeTo(12,3));
      expect(decoded.getPixel(0,0).g,closeTo(40,3));
    } finally {await folder.delete(recursive:true);}
  });
  test('invalid crop fails instead of silently sharing the wrong framing', () {
    expect(()=>cropPostPhoto(scene(),[0,0,2,1],0),throwsFormatException);
  });
}
