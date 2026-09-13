import pathlib
import subprocess
import sys
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
class AlbumHostTest(unittest.TestCase):
    def test_registers_on_engine_for_legacy_and_scene_lifecycle(self):
        for registry in ['self', 'engineBridge.pluginRegistry']:
            with self.subTest(registry=registry), tempfile.TemporaryDirectory() as directory:
                root=pathlib.Path(directory)
                delegate=root/'ios/Runner/AppDelegate.swift'
                delegate.parent.mkdir(parents=True)
                delegate.write_text('import Flutter\nimport UIKit\nclass AppDelegate { func setup() { GeneratedPluginRegistrant.register(with: '+registry+') } }\n')
                native=root/'tool/native_album'
                native.mkdir(parents=True)
                (native/'ios.txt').write_text((ROOT/'tool/native_album/ios.txt').read_text())
                command=[sys.executable,str(ROOT/'tool/configure_route_album.py'),'ios']
                subprocess.run(command,cwd=root,check=True)
                first=delegate.read_text()
                self.assertIn('registerTBTAlbum('+registry+')',first)
                self.assertIn('registrar.messenger()',first)
                self.assertNotIn('rootViewController',first)
                subprocess.run(command,cwd=root,check=True)
                self.assertEqual(first,delegate.read_text())
if __name__=='__main__':unittest.main()
