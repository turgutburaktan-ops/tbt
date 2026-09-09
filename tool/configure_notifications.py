"""Install notification actions in generated mobile hosts. Idempotent, fail closed on template drift."""
from pathlib import Path
import sys
if sys.argv[1] == 'android':
    path = Path('android/app/build.gradle.kts')
    source = path.read_text()
    if 'isCoreLibraryDesugaringEnabled = true' not in source:
        if 'compileOptions {' not in source: raise RuntimeError('Android compileOptions not found')
        source = source.replace('compileOptions {', 'compileOptions {\n        isCoreLibraryDesugaringEnabled = true', 1)
        source += '\ndependencies { coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4") }\n'
        path.write_text(source)
    manifest = Path('android/app/src/main/AndroidManifest.xml')
    source = manifest.read_text()
    if 'ActionBroadcastReceiver' not in source:
        source = source.replace('</application>', '<receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ActionBroadcastReceiver" />\n    </application>')
        manifest.write_text(source)
    icon = Path('android/app/src/main/res/drawable/ic_stat_tbt.xml')
    icon.parent.mkdir(parents=True, exist_ok=True)
    icon.write_text('<vector xmlns:android="http://schemas.android.com/apk/res/android" android:width="24dp" android:height="24dp" android:viewportWidth="24" android:viewportHeight="24"><path android:fillColor="#FFFFFFFF" android:pathData="M4,3h16a2,2 0,0 1,2 2v12a2,2 0,0 1,-2 2H8l-6,4V5a2,2 0,0 1,2 -2zM6,7v2h12V7zM6,12v2h9v-2z"/></vector>')
    # The icon is selected by name through a platform channel, so release resource shrinking cannot see the reference.
    keep = Path('android/app/src/main/res/raw/tbt_notification_keep.xml')
    keep.parent.mkdir(parents=True, exist_ok=True)
    keep.write_text('<resources xmlns:tools="http://schemas.android.com/tools" tools:keep="@drawable/ic_stat_tbt"/>')
elif sys.argv[1] == 'ios':
    path = Path('ios/Runner/AppDelegate.swift')
    source = path.read_text()
    if '// TBT inline replies' not in source:
        marker = '    return super.application(application, didFinishLaunchingWithOptions: launchOptions)'
        if marker not in source: raise RuntimeError('iOS AppDelegate launch hook not found')
        setup = '''    UNUserNotificationCenter.current().delegate = self
    FlutterLocalNotificationsPlugin.setPluginRegistrantCallback { registry in
      GeneratedPluginRegistrant.register(with: registry)
    }
'''
        source = 'import FirebaseAuth\nimport FirebaseCore\nimport UserNotifications\nimport flutter_local_notifications\n' + source.replace(marker, setup + marker, 1)
        end = source.rfind('}')
        source = source[:end] + Path('tool/native_notifications/AppDelegateReply.swift').read_text() + '\n' + source[end:]
        path.write_text(source)
else:
    raise RuntimeError('Expected android or ios')
