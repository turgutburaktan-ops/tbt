"""Install Crashlytics on generated Gradle hosts (Groovy and Kotlin DSL)."""
from pathlib import Path


def configure(root=Path('android')):
    for relative, declaration in [('settings.gradle', True), ('app/build.gradle', False)]:
        path = root / (relative + '.kts')
        if not path.exists():
            path = root / relative
        source = path.read_text()
        if 'com.google.firebase.crashlytics' in source:
            continue
        if 'plugins {' not in source:
            raise RuntimeError(f'Gradle plugins block not found: {path}')
        plugin = ('id("com.google.firebase.crashlytics")' if path.suffix == '.kts'
                  else 'id "com.google.firebase.crashlytics"')
        if declaration:
            plugin += ' version "3.0.6" apply false'
        source = source.replace('plugins {', f'plugins {{\n    {plugin}', 1)
        path.write_text(source)


if __name__ == '__main__':
    configure()
