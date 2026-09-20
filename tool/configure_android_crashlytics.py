"""Install Crashlytics on generated Gradle hosts (Groovy and Kotlin DSL)."""
from pathlib import Path
import json
import shutil


def configure(root=Path('android')):
    # Crashlytics needs the native Google app id and generated build id too.
    google = root / 'app/google-services.json'
    if not google.exists():
        bundled = root.parent / 'firabase/google-services.json'
        if not bundled.exists():
            raise RuntimeError('Firebase Android configuration not found')
        shutil.copyfile(bundled, google)
    data = json.loads(google.read_text())
    if not any(c.get('client_info', {}).get('android_client_info', {}).get('package_name') == 'com.tbt.social'
               for c in data.get('client', [])):
        raise RuntimeError('Firebase config must contain com.tbt.social')
    for relative, declaration in [('settings.gradle', True), ('app/build.gradle', False)]:
        path = root / (relative + '.kts')
        if not path.exists():
            path = root / relative
        source = path.read_text()
        if 'plugins {' not in source:
            raise RuntimeError(f'Gradle plugins block not found: {path}')
        for name, version in [('com.google.gms.google-services', '4.4.2'),
                              ('com.google.firebase.crashlytics', '3.0.6')]:
            if name in source:
                continue
            plugin = (f'id("{name}")' if path.suffix == '.kts' else f'id "{name}"')
            if declaration:
                plugin += f' version "{version}" apply false'
            source = source.replace('plugins {', f'plugins {{\n    {plugin}', 1)
        path.write_text(source)


if __name__ == '__main__':
    configure()
