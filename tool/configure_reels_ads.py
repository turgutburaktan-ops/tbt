"""Register full-page Reels native factories in generated hosts, without replacing hooks."""
from pathlib import Path
import re
import sys


def configure(platform):
    if platform == 'android':
        paths = list(Path('android/app/src/main').rglob('MainActivity.kt'))
        if len(paths) != 1:
            raise RuntimeError('Expected one Android activity')
        p = paths[0]
        s = p.read_text()
        if '// TBT Reels native ad factory' in s:
            return
        marker = 'super.configureFlutterEngine(flutterEngine)'
        if marker not in s:
            if 'configureFlutterEngine' in s:
                raise RuntimeError('Unrecognized engine hook')
            method = '\n    override fun configureFlutterEngine(flutterEngine: io.flutter.embedding.engine.FlutterEngine) {\n        '+marker+'\n    }\n'
            if re.search(r'class MainActivity\s*:\s*Flutter(?:Fragment)?Activity\(\)\s*$', s):
                s = s.rstrip()+' {'+method+'}\n'
            else:
                end = s.rfind('}')
                if end < 0: raise RuntimeError('Missing activity body')
                s = s[:end]+method+s[end:]
        s = s.replace(marker, marker+'\n        io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin.registerNativeAdFactory(flutterEngine, "tbtReels", TBTReelsAdFactory(this))', 1)
        s += '\n'+Path('tool/native_reels/android.txt').read_text()
        p.write_text(s)
    elif platform == 'ios':
        from configure_admob_privacy import configure as configure_privacy
        configure_privacy()
        p = Path('ios/Runner/AppDelegate.swift')
        s = p.read_text()
        if '// TBT Reels native ad factory' in s:
            return
        pattern = r'GeneratedPluginRegistrant\.register\(with: (self|engineBridge\.pluginRegistry)\)'
        if not re.search(pattern, s): raise RuntimeError('Missing iOS engine registry')
        s = re.sub(pattern, lambda m: m.group(0)+'\n    FLTGoogleMobileAdsPlugin.registerNativeAdFactory('+m.group(1)+', factoryId: "tbtReels", nativeAdFactory: TBTReelsAdFactory())', s)
        s = 'import GoogleMobileAds\nimport google_mobile_ads\n'+s+'\n'+Path('tool/native_reels/ios.txt').read_text()
        p.write_text(s)
    else:
        raise RuntimeError('Expected android or ios')


if __name__ == '__main__':
    configure(sys.argv[1])
