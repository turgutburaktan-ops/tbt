from pathlib import Path
import glob


def find_iris_root() -> Path:
    matches = sorted(glob.glob(str(Path.home() / '.pub-cache/hosted/pub.dev/iris_camera-*')))
    if not matches:
        raise SystemExit('iris_camera package cache not found')
    return Path(matches[-1])


def patch_plugin(root: Path) -> None:
    path = root / 'android/src/main/kotlin/com/anies1212/iris_camera/IrisCameraPlugin.kt'
    text = path.read_text()
    if '"setManualExposure" ->' in text:
        return

    marker = '            "setExposureOffset" -> launchWithPermission(result) {\n'
    if marker not in text:
        raise SystemExit('IrisCameraPlugin exposure marker not found')

    block = '''            "setManualExposure" -> launchWithPermission(result) {\n                val exposureMicros = call.argument<Number>("exposureDurationMicros")?.toLong()\n                    ?: return@launchWithPermission result.error("invalid_arguments", "Missing exposureDurationMicros", null)\n                val iso = call.argument<Number>("iso")?.toDouble()\n                    ?: return@launchWithPermission result.error("invalid_arguments", "Missing iso", null)\n                val ev = call.argument<Number>("ev")?.toDouble() ?: 0.0\n                cameraController?.setManualExposure(exposureMicros, iso, ev)\n                result.success(null)\n            }\n\n'''
    path.write_text(text.replace(marker, block + marker, 1))


def patch_controller(root: Path) -> None:
    path = root / 'android/src/main/kotlin/com/anies1212/iris_camera/CameraController.kt'
    text = path.read_text()
    if 'suspend fun setManualExposure(' in text:
        return

    marker = '    fun setExposureOffset(offset: Double): Double {\n'
    if marker not in text:
        raise SystemExit('CameraController exposure offset marker not found')

    method = '''    suspend fun setManualExposure(\n        exposureDurationMicros: Long,\n        iso: Double,\n        ev: Double,\n    ) {\n        ensureInitialized()\n        val activeCamera = camera ?: return\n        val camera2 = Camera2CameraControl.from(activeCamera.cameraControl)\n\n        val manager = context.getSystemService(Context.CAMERA_SERVICE) as CameraManager\n        val lensId = selectedLensId ?: return\n        val characteristics = manager.getCameraCharacteristics(lensId)\n        val exposureRange = characteristics.get(CameraCharacteristics.SENSOR_INFO_EXPOSURE_TIME_RANGE)\n        val isoRange = characteristics.get(CameraCharacteristics.SENSOR_INFO_SENSITIVITY_RANGE)\n\n        // EV is translated into actual exposure energy while AE is disabled.\n        val evMultiplier = Math.pow(2.0, ev.coerceIn(-2.0, 2.0))\n        var exposureNs = (exposureDurationMicros.toDouble() * 1000.0 * evMultiplier).toLong()\n        if (exposureRange != null) {\n            exposureNs = exposureNs.coerceIn(exposureRange.lower, exposureRange.upper)\n        }\n\n        var sensitivity = iso.toInt()\n        if (isoRange != null) {\n            sensitivity = sensitivity.coerceIn(isoRange.lower, isoRange.upper)\n        }\n\n        val options = CaptureRequestOptions.Builder()\n            .setCaptureRequestOption(CaptureRequest.CONTROL_AE_MODE, CaptureRequest.CONTROL_AE_MODE_OFF)\n            .setCaptureRequestOption(CaptureRequest.SENSOR_EXPOSURE_TIME, exposureNs)\n            .setCaptureRequestOption(CaptureRequest.SENSOR_SENSITIVITY, sensitivity)\n            .build()\n\n        camera2.setCaptureRequestOptions(options).await()\n    }\n\n'''
    path.write_text(text.replace(marker, method + marker, 1))


def patch_flutter_camera() -> None:
    path = Path('lib/screens/camera_screen.dart')
    text = path.read_text()

    if "package:flutter/services.dart" not in text:
        marker = "import 'package:flutter/material.dart';\n"
        if marker not in text:
            raise SystemExit('Flutter material import marker not found')
        text = text.replace(marker, marker + "import 'package:flutter/services.dart';\n", 1)

    if "MethodChannel('iris_camera')" not in text:
        marker = '  final ImagePicker _picker = ImagePicker();\n'
        if marker not in text:
            raise SystemExit('ImagePicker field marker not found')
        text = text.replace(marker, marker + "  static const MethodChannel _irisNative = MethodChannel('iris_camera');\n", 1)

    if 'Future<void> _applyLiveManualExposure(' not in text:
        marker = '  Future<void> _applyModeBaseSettings() async {\n'
        if marker not in text:
            raise SystemExit('Mode base settings marker not found')
        method = '''  Future<void> _applyLiveManualExposure({\n    required int iso,\n    required Duration shutter,\n    required double ev,\n  }) async {\n    try {\n      await _irisNative.invokeMethod<void>('setManualExposure', {\n        'iso': iso.toDouble(),\n        'exposureDurationMicros': shutter.inMicroseconds,\n        'ev': ev,\n      });\n    } catch (e) {\n      debugPrint('Canlı manuel pozlama uygulanamadı: $e');\n    }\n  }\n\n'''
        text = text.replace(marker, method + marker, 1)

    # Apply real ISO/shutter/EV immediately whenever a mode profile is selected.
    mode_anchor = '''    if (_subjectLocked && _subjectPoint != null) {\n      try {\n        await _camera.setFocus(point: _subjectPoint!);\n        await _camera.setExposurePoint(_subjectPoint!);\n      } catch (_) {}\n    }\n\n    if (mounted) {\n'''
    if mode_anchor in text and 'await _applyLiveManualExposure(\n      iso: iso,\n      shutter: shutter,\n      ev: ev,\n    );\n\n    if (mounted)' not in text:
        replacement = mode_anchor.replace('\n    if (mounted) {\n', '''\n    await _applyLiveManualExposure(\n      iso: iso,\n      shutter: shutter,\n      ev: ev,\n    );\n\n    if (mounted) {\n''')
        text = text.replace(mode_anchor, replacement, 1)

    # Re-apply live manual exposure after every AI decision too.
    ai_anchor = '''    try {\n      await _camera.setExposureOffset(ev);\n    } catch (_) {}\n\n    try {\n      if (_subjectLocked && _subjectPoint != null) {\n'''
    if ai_anchor in text and 'AI live exposure' not in text:
        replacement = '''    try {\n      await _camera.setExposureOffset(ev);\n    } catch (_) {}\n\n    // AI live exposure: ISO + shutter + EV are applied to the preview sensor now.\n    await _applyLiveManualExposure(\n      iso: iso,\n      shutter: shutter,\n      ev: ev,\n    );\n\n    try {\n      if (_subjectLocked && _subjectPoint != null) {\n'''
        text = text.replace(ai_anchor, replacement, 1)

    path.write_text(text)


def main() -> None:
    root = find_iris_root()
    patch_plugin(root)
    patch_controller(root)
    patch_flutter_camera()
    print('Live manual ISO/shutter/EV patch applied')


if __name__ == '__main__':
    main()
