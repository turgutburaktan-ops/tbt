import hashlib, pathlib, plistlib, zipfile
source=pathlib.Path('assets/spot_thumbnails/tbt_app_icon_1024.png')
assert hashlib.sha256(source.read_bytes()).hexdigest()=='7d90b462ca3510c8fd1aec7bc4d650353e0755a75220ee9d6ee34ed03373349b', 'Unexpected TBT logo source'
ipas=list(pathlib.Path('build/ios/ipa').glob('*.ipa'))
assert len(ipas)==1, 'Expected one signed IPA'
with zipfile.ZipFile(ipas[0]) as archive:
 names=archive.namelist()
 info=plistlib.loads(archive.read('Payload/Runner.app/Info.plist'))
 assert info['CFBundleIdentifier']=='com.tbt.social'
 assert info['CFBundleShortVersionString']=='1.0.31'
 assert info['CFBundleVersion']=='59'
 icon=info['CFBundleIcons']['CFBundlePrimaryIcon']
 assert icon['CFBundleIconName']=='AppIcon'
 assert icon.get('CFBundleIconFiles'), 'Missing compiled launcher icon references'
 assert any(n.startswith('Payload/Runner.app/AppIcon') and n.endswith('.png') for n in names), 'Missing compiled launcher icons'
print('Verified TBT logo source, compiled AppIcon and com.tbt.social 1.0.31 (59)')
