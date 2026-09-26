from pathlib import Path
import sys
import re
platform = sys.argv[1]
if platform == 'android':
    paths = list(Path('android/app/src/main').rglob('MainActivity.kt'))
    if len(paths) != 1: raise RuntimeError('Expected one Android host')
    p = paths[0]
    s = p.read_text()
    if '// TBT private route album export' not in s:
        marker = '        super.configureFlutterEngine(flutterEngine)'
        if marker not in s:
            if 'configureFlutterEngine' in s: raise RuntimeError('Unrecognized Android engine hook')
            for imp in ['io.flutter.embedding.engine.FlutterEngine', 'io.flutter.plugin.common.MethodChannel']:
                if 'import '+imp not in s:
                    s = re.sub(r'^(package[^\n]+)', lambda m: m.group(0)+'\nimport '+imp, s, count=1, flags=re.M)
            method = '\n    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {\n'+marker+'\n    }\n'
            if re.search(r'class MainActivity\s*:\s*Flutter(?:Fragment)?Activity\(\)\s*$', s):
                s = s.rstrip()+' {'+method+'}\n'
            else:
                end=s.rfind('}')
                if end < 0: raise RuntimeError('Android activity body not found')
                s=s[:end]+method+s[end:]
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
        pattern = r'GeneratedPluginRegistrant\.register\(with: (self|engineBridge\.pluginRegistry)\)'
        if not re.search(pattern, s): raise RuntimeError('iOS plugin registry hook not found')
        s = re.sub(pattern, lambda m: m.group(0)+'\n    registerTBTAlbum('+m.group(1)+')', s)
        s = 'import Photos\n'+s+'\n'+Path('tool/native_album/ios.txt').read_text()
        p.write_text(s)
else: raise RuntimeError('Expected android or ios')

# Protect ephemeral chat photos in every generated store host.
import runpy
runpy.run_path('tool/configure_private_photo.py', run_name='__main__')

