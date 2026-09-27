"""Initialize Maps in regenerated iOS hosts without replacing other native hooks."""
import os
import plistlib
from pathlib import Path


def configure(root=Path('ios/Runner')):
    key = (os.environ.get('IOS_MAPS_API_KEY') or os.environ.get('MAPS_API_KEY') or '').strip()
    if not key:
        raise RuntimeError('IOS_MAPS_API_KEY or MAPS_API_KEY is required; refusing a build with uninitialized Maps')
    delegate = root / 'AppDelegate.swift'
    source = delegate.read_text()
    marker = '    return super.application(application, didFinishLaunchingWithOptions: launchOptions)'
    if marker not in source:
        raise RuntimeError('iOS launch hook not found')
    if '// TBT Maps bootstrap' not in source:
        source = 'import GoogleMaps\n' + source
        source = source.replace(marker, '''    // TBT Maps bootstrap: configured before any Flutter map is created.
    if let mapsKey = Bundle.main.object(forInfoDictionaryKey: "GMSApiKey") as? String,
       !mapsKey.isEmpty {
      GMSServices.provideAPIKey(mapsKey)
    }
''' + marker, 1)
    info_path = root / 'Info.plist'
    with info_path.open('rb') as f:
        info = plistlib.load(f)
    info['GMSApiKey'] = key
    with info_path.open('wb') as f:
        plistlib.dump(info, f, sort_keys=False)
    delegate.write_text(source)


if __name__ == '__main__':
    configure()
