import importlib.util
from pathlib import Path
import tempfile
import unittest
import xml.etree.ElementTree as ET

spec = importlib.util.spec_from_file_location('splash', Path(__file__).parents[1] / 'configure_android_splash.py')
splash = importlib.util.module_from_spec(spec)
spec.loader.exec_module(splash)

class SplashHostTest(unittest.TestCase):
    def test_recreated_hosts_keep_normal_theme_and_original_logo(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            logo = root / splash.LOGO
            logo.parent.mkdir(parents=True)
            logo.write_bytes(b'approved-logo-unchanged')
            res = root / 'android/app/src/main/res'
            for qualifier in ('values', 'values-night', 'values-v31', 'values-night-v31'):
                path = res / qualifier / 'styles.xml'
                path.parent.mkdir(parents=True)
                path.write_text('<resources><style name="LaunchTheme" parent="@android:style/Theme.Black.NoTitleBar"><item name="android:windowBackground">@android:color/white</item></style><style name="NormalTheme"><item name="android:windowBackground">?android:colorBackground</item></style></resources>')
            splash.configure(root)
            once = {str(p.relative_to(res)): p.read_bytes() for p in res.rglob('*') if p.is_file()}
            splash.configure(root)
            self.assertEqual(once, {str(p.relative_to(res)): p.read_bytes() for p in res.rglob('*') if p.is_file()})
            self.assertEqual((res / 'drawable-nodpi/tbt_splash_logo.png').read_bytes(), logo.read_bytes())
            for qualifier in ('values', 'values-night', 'values-v31', 'values-night-v31'):
                styles = ET.parse(res / qualifier / 'styles.xml').getroot()
                self.assertEqual(styles.find("style[@name='NormalTheme']/item").text, '?android:colorBackground')
                items = {x.get('name'): x.text for x in styles.find("style[@name='LaunchTheme']")}
                self.assertEqual(items['android:windowBackground'], '@drawable/launch_background')
                if qualifier.endswith('v31'):
                    self.assertEqual(items['android:windowSplashScreenIconBackgroundColor'], '@android:color/transparent')
                    self.assertEqual(items['android:windowSplashScreenAnimatedIcon'], '@drawable/tbt_splash_icon')
            for path in res.rglob('*.xml'):
                ET.parse(path)

    def test_missing_generated_host_fails_before_any_change(self):
        with tempfile.TemporaryDirectory() as directory:
            with self.assertRaises(RuntimeError):
                splash.configure(Path(directory))
            self.assertEqual(list(Path(directory).iterdir()), [])

if __name__ == '__main__':
    unittest.main()
