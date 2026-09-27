"""Keep CamerAwesome's front-camera mirror setting off the rear sensor."""
import json
from pathlib import Path
import sys
from urllib.parse import unquote, urljoin, urlparse


def package_root():
    config = Path('.dart_tool/package_config.json').resolve()
    packages = json.loads(config.read_text())['packages']
    package = next(p for p in packages if p['name'] == 'camerawesome')
    uri = urlparse(urljoin(config.as_uri(), package['rootUri']))
    if uri.scheme != 'file':
        raise SystemExit('Expected a local CamerAwesome package')
    return Path(unquote(uri.path))


def patch(root):
    candidates = list((root / 'ios').rglob('SingleCameraPreview.m'))
    if len(candidates) != 1:
        raise SystemExit('Expected one iOS SingleCameraPreview.m')
    path = candidates[0]
    original = path.read_text()
    updated = original
    # The constructor runs after initCameraPreview. It used to overwrite the
    # rear sensor's correct non-mirrored connection with the selfie preference.
    replacements = {
        '[_captureConnection setVideoMirrored:mirrorFrontCamera];':
        '[_captureConnection setVideoMirrored:(mirrorFrontCamera && _cameraSensorPosition == PigeonSensorPositionFront)];',
        '[_captureConnection setVideoMirrored:value];':
        '[_captureConnection setVideoMirrored:(value && _cameraSensorPosition == PigeonSensorPositionFront)];',
    }
    for before, after in replacements.items():
        if updated.count(before) == 1 and after not in updated:
            updated = updated.replace(before, after)
        elif updated.count(after) != 1 or before in updated:
            raise SystemExit('CamerAwesome mirroring implementation changed; review before building')
    if updated != original:
        path.write_text(updated)
    print('iOS camera: rear mirroring disabled; front preference preserved')


if __name__ == '__main__':
    patch(Path(sys.argv[1]) if len(sys.argv) > 1 else package_root())
