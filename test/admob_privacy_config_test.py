import importlib.util
import json
import plistlib
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('privacy', ROOT / 'tool/configure_admob_privacy.py')
privacy = importlib.util.module_from_spec(spec)
spec.loader.exec_module(privacy)


class PrivacyConfigTest(unittest.TestCase):
    def test_preserves_existing_settings_and_is_idempotent(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / 'Info.plist'
            original = {'GADApplicationIdentifier': 'production-id',
                        'NSUserTrackingUsageDescription': 'Existing text',
                        'SKAdNetworkItems': [{'SKAdNetworkIdentifier': 'existing.skadnetwork'}]}
            path.write_bytes(plistlib.dumps(original))
            privacy.configure(path)
            first = path.read_bytes()
            privacy.configure(path)
            self.assertEqual(first, path.read_bytes())
            result = plistlib.loads(first)
            self.assertEqual(result['GADApplicationIdentifier'], 'production-id')
            self.assertEqual(result['NSUserTrackingUsageDescription'], 'Existing text')
            ids = [i['SKAdNetworkIdentifier'] for i in result['SKAdNetworkItems']]
            source = json.loads((ROOT / 'tool/admob_skadnetwork_ids.json').read_text())
            self.assertEqual(set(ids), set(source) | {'existing.skadnetwork'})
            self.assertEqual(len(ids), len(set(ids)))
            self.assertIn('cstr6suwn9.skadnetwork', ids)


if __name__ == '__main__':
    unittest.main()
