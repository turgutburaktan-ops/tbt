import tempfile
import unittest
from pathlib import Path

from tool.patch_ios_camera_mirroring import patch


class CameraMirroringTests(unittest.TestCase):
    def test_rear_never_inherits_selfie_mirror_and_patch_is_idempotent(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            target = root / 'ios' / 'Classes' / 'SingleCameraPreview.m'
            target.parent.mkdir(parents=True)
            target.write_text('''
[_captureConnection setVideoMirrored:mirrorFrontCamera];
[_captureConnection setVideoMirrored:value];
[_captureConnection setVideoOrientation:orientation];
''')
            patch(root)
            updated = target.read_text()
            for value in ['mirrorFrontCamera', 'value']:
                self.assertIn(
                    f'setVideoMirrored:({value} && _cameraSensorPosition == PigeonSensorPositionFront)',
                    updated,
                )
            self.assertIn('setVideoOrientation:orientation', updated)
            patch(root)
            self.assertEqual(updated, target.read_text())

    def test_unknown_plugin_layout_blocks_build_instead_of_silently_skipping(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            target = root / 'ios' / 'SingleCameraPreview.m'
            target.parent.mkdir(parents=True)
            target.write_text('// incompatible new plugin implementation')
            with self.assertRaises(SystemExit):
                patch(root)


if __name__ == '__main__':
    unittest.main()
