"""Verify the approved TBT icon was generated and included in the Play bundle."""
from pathlib import Path
import hashlib
import struct
import zipfile
import xml.etree.ElementTree as ET

source = Path('assets/spot_thumbnails/tbt_app_icon_1024.png')
assert hashlib.sha256(source.read_bytes()).hexdigest() == '7d90b462ca3510c8fd1aec7bc4d650353e0755a75220ee9d6ee34ed03373349b', 'Unexpected logo source'
manifest = ET.parse('android/app/src/main/AndroidManifest.xml').getroot()
assert manifest.find('application').get('{http://schemas.android.com/apk/res/android}icon') == '@mipmap/ic_launcher', 'Launcher icon is not wired'

def dimensions(data):
    assert data[:8] == b'\x89PNG\r\n\x1a\n', 'Expected a PNG icon'
    return struct.unpack('>II', data[16:24])

with zipfile.ZipFile('build/app/outputs/bundle/release/app-release.aab') as bundle:
    for density, size in [('mdpi', 48), ('hdpi', 72), ('xhdpi', 96), ('xxhdpi', 144), ('xxxhdpi', 192)]:
        local = Path(f'android/app/src/main/res/mipmap-{density}/ic_launcher.png')
        assert dimensions(local.read_bytes()) == (size, size), f'Wrong generated icon: {density}'
        matches = [name for name in bundle.namelist() if name.startswith(f'base/res/mipmap-{density}') and name.endswith('/ic_launcher.png')]
        assert len(matches) == 1, f'Missing or ambiguous compiled icon: {density}'
        assert dimensions(bundle.read(matches[0])) == (size, size), f'Wrong compiled icon: {density}'
print('Verified approved TBT logo source, launcher reference and all five compiled icon densities')
