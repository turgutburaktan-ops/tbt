"""Align the pinned share plugin's Java/Kotlin bytecode targets on Java 24 CI."""
import json
from pathlib import Path
from urllib.parse import unquote, urlparse
config = Path('.dart_tool/package_config.json').resolve()
packages = json.loads(config.read_text())['packages']
package = next(p for p in packages if p['name'] == 'receive_sharing_intent')
uri = urlparse(package['rootUri'])
root = Path(unquote(uri.path)) if uri.scheme == 'file' else (config.parent / unquote(package['rootUri'])).resolve()
path = root / 'android/build.gradle'
source = path.read_text()
marker = '// TBT share plugin JVM compatibility'
if marker not in source:
    if 'android {' not in source: raise RuntimeError('Share plugin Gradle layout changed')
    source = source.replace('android {', '''android {
    // TBT share plugin JVM compatibility
    compileOptions {
        sourceCompatibility JavaVersion.VERSION_11
        targetCompatibility JavaVersion.VERSION_11
    }
    kotlinOptions { jvmTarget = '11' }
''', 1)
    path.write_text(source)
print('Share plugin Java/Kotlin targets aligned to 11')
