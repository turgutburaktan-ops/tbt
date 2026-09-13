from pathlib import Path
import sys
platform = sys.argv[1]
if platform == 'android':
    paths = list(Path('android/app/src/main').rglob('MainActivity.kt'))
    if len(paths) != 1: raise RuntimeError('Expected one Android host')
    p = paths[0]
    s = p.read_text()
    if '// TBT private route album export' not in s:
        marker = '        super.configureFlutterEngine(flutterEngine)'
        if marker not in s:
            raise RuntimeError('Configure photo pipeline before album export')
        s = s.replace(marker, marker+'\n'+Path('tool/native_album/android.txt').read_text(),1)
        p.write_text(s)
    manifest = Path('android/app/src/main/AndroidManifest.xml')
    if manifest.exists():
        xml = manifest.read_text()
        if 'android.permission.WRITE_EXTERNAL_STORAGE' not in xml:
            xml = xml.replace('<application', '<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" android:maxSdkVersion="28" />\n    <application', 1)
            manifest.write_text(xml)
elif platform == 'ios':
    p = Path('ios/Runner/AppDelegate.swift')
    s = p.read_text()
    if '// TBT private route album export' not in s:
        marker = '    return super.application(application, didFinishLaunchingWithOptions: launchOptions)'
        if marker not in s: raise RuntimeError('iOS launch hook not found')
        s = 'import Photos\n'+s.replace(marker,Path('tool/native_album/ios.txt').read_text()+marker,1)
        p.write_text(s)
else: raise RuntimeError('Expected android or ios')
