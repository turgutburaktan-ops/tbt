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

# App Links owns URL navigation. The share plugin otherwise emits ACTION_VIEW
# links as import drafts and covers the destination with "TBT'ye aktar".
plugin = root / 'android/src/main/kotlin/com/kasem/receive_sharing_intent/ReceiveSharingIntentPlugin.kt'
source = plugin.read_text()
marker = '// TBT: URL views belong to app_links'
if marker not in source:
    anchor = '    private fun handleIntent(intent: Intent, initial: Boolean) {'
    if source.count(anchor) != 1:
        raise RuntimeError('Share plugin intent handler changed')
    source = source.replace(anchor, anchor + '''
        // TBT: URL views belong to app_links
        if (intent.action == Intent.ACTION_VIEW &&
            intent.data?.scheme?.lowercase() in listOf("https", "http", "tbt")) {
            return
        }
''', 1)
    plugin.write_text(source)
print('URL views excluded from media import; SEND and local media preserved')
