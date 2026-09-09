"""Install the share extension after CI regenerates the iOS host."""
import plistlib
import shutil
import subprocess
from pathlib import Path
root = Path('ios')
group = 'group.com.tbt.social.share'
ext = root / 'TBTShare'
ext.mkdir(exist_ok=True)
shutil.copyfile('tool/native_share/ShareViewController.swift', ext / 'ShareViewController.swift')
shutil.copyfile('tool/native_share/ShareSceneDelegate.swift', root / 'Runner/ShareSceneDelegate.swift')
def patch_plist(path, update):
    data = plistlib.loads(path.read_bytes()) if path.exists() else {}
    update(data)
    path.write_bytes(plistlib.dumps(data))
def runner(info):
    info['AppGroupId'] = group
    urls = info.setdefault('CFBundleURLTypes', [])
    scheme = 'ShareMedia-com.tbt.social'
    if not any(scheme in entry.get('CFBundleURLSchemes', []) for entry in urls):
        urls.append({'CFBundleURLSchemes': [scheme], 'CFBundleTypeRole': 'Editor'})
    def scene_values(value):
        if isinstance(value, dict):
            if 'UISceneDelegateClassName' in value:
                value['UISceneDelegateClassName'] = '$(PRODUCT_MODULE_NAME).ShareSceneDelegate'
            for child in value.values(): scene_values(child)
        elif isinstance(value, list):
            for child in value: scene_values(child)
    scene_values(info.get('UIApplicationSceneManifest', {}))
patch_plist(root / 'Runner/Info.plist', runner)
for entitlements in [root / 'Runner/Runner.entitlements', ext / 'TBTShare.entitlements']:
    def ent(data):
        groups = data.setdefault('com.apple.security.application-groups', [])
        if group not in groups: groups.append(group)
    patch_plist(entitlements, ent)
info = {'CFBundleDisplayName': 'TBT', 'CFBundleName': 'TBTShare', 'CFBundleIdentifier': '$(PRODUCT_BUNDLE_IDENTIFIER)', 'CFBundleExecutable': '$(EXECUTABLE_NAME)', 'CFBundlePackageType': 'XPC!', 'CFBundleShortVersionString': '$(FLUTTER_BUILD_NAME)', 'CFBundleVersion': '$(FLUTTER_BUILD_NUMBER)', 'AppGroupId': group, 'NSExtension': {'NSExtensionPointIdentifier': 'com.apple.share-services', 'NSExtensionPrincipalClass': '$(PRODUCT_MODULE_NAME).ShareViewController', 'NSExtensionAttributes': {'NSExtensionActivationRule': {'NSExtensionActivationSupportsText': True, 'NSExtensionActivationSupportsWebURLWithMaxCount': 1, 'NSExtensionActivationSupportsImageWithMaxCount': 20, 'NSExtensionActivationSupportsMovieWithMaxCount': 20}}}}
(ext / 'Info.plist').write_bytes(plistlib.dumps(info))
(ext / 'Share.xcconfig').write_text('#include "../Flutter/Generated.xcconfig"\n')
subprocess.run(['ruby', 'tool/configure_ios_share.rb'], check=True)
