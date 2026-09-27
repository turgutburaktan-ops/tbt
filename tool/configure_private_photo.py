from pathlib import Path
import re
import sys

platform = sys.argv[1]
if platform == 'android':
    paths = list(Path('android/app/src/main').rglob('MainActivity.kt'))
    if len(paths) != 1:
        raise RuntimeError('Expected one Android host')
    path = paths[0]
    source = path.read_text()
    if '// TBT protected photo viewer' not in source:
        marker = '        super.configureFlutterEngine(flutterEngine)'
        if marker not in source:
            raise RuntimeError('Run the route album host configuration first')
        code = """
        // TBT protected photo viewer
        var privatePhotoWasSecure = false
        var privatePhotoActive = false
        io.flutter.plugin.common.MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger, "tbt/private_photo"
        ).setMethodCallHandler { call, result ->
            if (call.method != "setActive") {
                result.notImplemented()
            } else {
                val active = call.argument<Boolean>("active") == true
                val secure = android.view.WindowManager.LayoutParams.FLAG_SECURE
                if (active && !privatePhotoActive) {
                    privatePhotoWasSecure = (window.attributes.flags and secure) != 0
                    window.addFlags(secure)
                } else if (!active && privatePhotoActive && !privatePhotoWasSecure) {
                    window.clearFlags(secure)
                }
                privatePhotoActive = active
                result.success(mapOf("captured" to false))
            }
        }
"""
        path.write_text(source.replace(marker, marker + code, 1))
elif platform == 'ios':
    path = Path('ios/Runner/AppDelegate.swift')
    source = path.read_text()
    if '// TBT protected photo viewer' not in source:
        pattern = r'GeneratedPluginRegistrant\.register\(with: (self|engineBridge\.pluginRegistry)\)'
        if not re.search(pattern, source):
            raise RuntimeError('iOS plugin registry hook not found')
        source = re.sub(pattern, lambda match: match.group(0) +
            '\n    registerTBTPrivatePhoto(' + match.group(1) + ')', source)
        path.write_text(source + '\n' + Path('tool/native_private_photo/ios.txt').read_text())
else:
    raise RuntimeError('Expected android or ios')
