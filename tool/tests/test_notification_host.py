import pathlib
import subprocess
import sys
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
TEMPLATE = '''import Flutter
import UIKit
@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(_ application: UIApplication,
      didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
'''

class NotificationHostTest(unittest.TestCase):
    def test_cold_launch_registration_and_idempotence(self):
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            delegate = root / 'ios/Runner/AppDelegate.swift'
            delegate.parent.mkdir(parents=True)
            delegate.write_text(TEMPLATE)
            native = root / 'tool/native_notifications'
            native.mkdir(parents=True)
            (native / 'AppDelegateReply.swift').write_text((ROOT / 'tool/native_notifications/AppDelegateReply.swift').read_text())
            command = [sys.executable, str(ROOT / 'tool/configure_notifications.py'), 'ios']
            subprocess.run(command, cwd=root, check=True)
            first = delegate.read_text()
            self.assertIn('FirebaseApp.configure()', first)
            self.assertIn('application.registerForRemoteNotifications()', first)
            self.assertIn('UNTextInputNotificationAction(identifier: "tbt_reply"', first)
            self.assertIn('options: [.authenticationRequired]', first)
            self.assertNotIn('.foreground', first)
            self.assertIn('user.uid == recipient', first)
            self.assertIn('replyToNotification', first)
            self.assertLess(first.index('FirebaseApp.configure()'), first.index('return super.application'))
            subprocess.run(command, cwd=root, check=True)
            self.assertEqual(first, delegate.read_text())
            # Upgrading a previously patched host also installs the new setup.
            start = first.index('    // TBT push setup v2')
            end = first.index('    return super.application', start)
            delegate.write_text(first[:start] + first[end:])
            subprocess.run(command, cwd=root, check=True)
            self.assertEqual(first, delegate.read_text())

if __name__ == '__main__':
    unittest.main()
