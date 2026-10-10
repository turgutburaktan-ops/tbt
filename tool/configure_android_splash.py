"""Apply TBT launch branding after flutter create recreates the Android host."""
from pathlib import Path
import shutil
import xml.etree.ElementTree as ET

BACKGROUND = '#0B0D10'
LOGO = Path('assets/spot_thumbnails/tbt_app_icon_1024.png')


def configure(root=Path('.')):
    root = Path(root)
    res = root / 'android/app/src/main/res'
    logo = root / LOGO
    if not logo.is_file() or not res.is_dir():
        raise RuntimeError('Generated Android host or approved TBT logo missing')
    (res / 'drawable-nodpi').mkdir(exist_ok=True)
    shutil.copyfile(logo, res / 'drawable-nodpi/tbt_splash_logo.png')
    # Use the original approved bitmap, rather than Android's legacy launcher
    # icon fallback, which adds a white plate on newer Android versions.
    drawable = '''<?xml version="1.0" encoding="utf-8"?>
<layer-list xmlns:android="http://schemas.android.com/apk/res/android">
    <item android:width="192dp" android:height="192dp" android:gravity="center">
        <bitmap android:gravity="fill" android:src="@drawable/tbt_splash_logo" />
    </item>
</layer-list>
'''
    for name in ('drawable', 'drawable-v21'):
        directory = res / name
        directory.mkdir(exist_ok=True)
        (directory / 'tbt_splash_icon.xml').write_text(drawable)
        (directory / 'launch_background.xml').write_text('''<?xml version="1.0" encoding="utf-8"?>
<layer-list xmlns:android="http://schemas.android.com/apk/res/android">
    <item android:drawable="#0B0D10" />
    <item android:drawable="@drawable/tbt_splash_icon" />
</layer-list>
''')
    for name in ('values', 'values-night', 'values-v31', 'values-night-v31'):
        directory = res / name
        directory.mkdir(exist_ok=True)
        path = directory / 'styles.xml'
        tree = ET.parse(path) if path.exists() else ET.ElementTree(ET.Element('resources'))
        resources = tree.getroot()
        launch = resources.find("style[@name='LaunchTheme']")
        if launch is None:
            launch = ET.SubElement(resources, 'style', {'name': 'LaunchTheme', 'parent': '@android:style/Theme.Black.NoTitleBar'})
        values = {'android:windowBackground': '@drawable/launch_background',
                  'android:statusBarColor': BACKGROUND,
                  'android:navigationBarColor': BACKGROUND,
                  'android:windowLightStatusBar': 'false',
                  'android:windowLightNavigationBar': 'false'}
        if name.endswith('v31'):
            values.update({'android:windowSplashScreenBackground': BACKGROUND,
                           'android:windowSplashScreenAnimatedIcon': '@drawable/tbt_splash_icon',
                           'android:windowSplashScreenIconBackgroundColor': '@android:color/transparent'})
        for key, value in values.items():
            item = launch.find(f"item[@name='{key}']")
            if item is None:
                item = ET.SubElement(launch, 'item', {'name': key})
            item.text = value
        ET.indent(tree, space='    ')
        tree.write(path, encoding='utf-8', xml_declaration=True)


if __name__ == '__main__':
    configure()
    print('Configured dark TBT launch screen without the system icon background')
