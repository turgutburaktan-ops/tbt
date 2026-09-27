import importlib.util
import json
import os
from pathlib import Path
import plistlib
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]


def module(name):
    spec = importlib.util.spec_from_file_location(name, ROOT / 'tool' / (name + '.py'))
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


class NativeConfigurationTest(unittest.TestCase):
    def test_maps_preserves_hooks_and_is_idempotent(self):
        with tempfile.TemporaryDirectory() as tmp, patch.dict(os.environ, {'IOS_MAPS_API_KEY': 'test-key'}):
            root = Path(tmp)
            source = '''import Flutter
import UIKit
@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    // existing notifications and album channel
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
'''
            (root / 'AppDelegate.swift').write_text(source)
            (root / 'Info.plist').write_bytes(plistlib.dumps({'NSCameraUsageDescription': 'camera'}))
            setup = module('configure_ios_maps')
            setup.configure(root)
            first = (root / 'AppDelegate.swift').read_text()
            setup.configure(root)
            self.assertEqual(first, (root / 'AppDelegate.swift').read_text())
            self.assertIn('// existing notifications and album channel', first)
            self.assertEqual(first.count('GMSServices.provideAPIKey'), 1)
            self.assertLess(first.index('GMSServices.provideAPIKey'), first.index('return super.application'))
            info = plistlib.loads((root / 'Info.plist').read_bytes())
            self.assertEqual(info['GMSApiKey'], 'test-key')
            self.assertEqual(info['NSCameraUsageDescription'], 'camera')

    def test_maps_rejects_missing_key(self):
        with patch.dict(os.environ, {'IOS_MAPS_API_KEY': '', 'MAPS_API_KEY': ''}):
            with self.assertRaisesRegex(RuntimeError, 'required'):
                module('configure_ios_maps').configure(Path('/unused'))

    def test_crashlytics_gradle_supports_both_generated_hosts(self):
        for suffix in ['', '.kts']:
            with self.subTest(suffix=suffix), tempfile.TemporaryDirectory() as tmp:
                root = Path(tmp)
                (root / 'app').mkdir()
                (root / 'app/google-services.json').write_text(json.dumps({'client':[{'client_info':{'android_client_info':{'package_name':'com.tbt.social'}}}]}))
                paths = [root / ('settings.gradle' + suffix), root / ('app/build.gradle' + suffix)]
                for path in paths:
                    path.write_text('plugins {\n}\n// existing configuration\n')
                setup = module('configure_android_crashlytics')
                setup.configure(root)
                setup.configure(root)
                for path in paths:
                    self.assertEqual(path.read_text().count('com.google.firebase.crashlytics'), 1)
                    self.assertEqual(path.read_text().count('com.google.gms.google-services'), 1)
                    self.assertIn('// existing configuration', path.read_text())


if __name__ == '__main__':
    unittest.main()
