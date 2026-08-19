from pathlib import Path
import glob
import re


def find_iris_root() -> Path:
    matches = sorted(glob.glob(str(Path.home() / ".pub-cache/hosted/pub.dev/iris_camera-*")))
    if not matches:
        raise SystemExit("iris_camera package cache not found")
    return Path(matches[-1])


def patch_image_util(root: Path) -> None:
    path = root / "android/src/main/kotlin/com/anies1212/iris_camera/ImageUtil.kt"
    text = path.read_text()
    if "image.format == ImageFormat.JPEG" in text:
        return
    marker = "    fun imageProxyToJpeg(image: ImageProxy): ByteArray {\n"
    if marker not in text:
        raise SystemExit("ImageUtil.imageProxyToJpeg not found")
    replacement = marker + """        // CameraX still capture may return JPEG as a one-plane ImageProxy.
        if (image.format == ImageFormat.JPEG && image.planes.isNotEmpty()) {
            val buffer = image.planes[0].buffer.apply { rewind() }
            val bytes = ByteArray(buffer.remaining())
            buffer.get(bytes)
            return bytes
        }
        if (image.planes.size < 3) {
            throw IllegalStateException(
                \"Unsupported ImageProxy format=${image.format}, planes=${image.planes.size}\"
            )
        }

"""
    path.write_text(text.replace(marker, replacement, 1))


def patch_camera_controller(root: Path) -> None:
    path = root / "android/src/main/kotlin/com/anies1212/iris_camera/CameraController.kt"
    text = path.read_text()

    pattern = re.compile(
        r"        if \(exposureDurationMicros != null \|\| iso != null\) \{\n"
        r"            val camera2 = camera\?\.cameraControl\?\.let \{ Camera2CameraControl\.from\(it\) \}\n"
        r"            val options = CaptureRequestOptions\.Builder\(\)\n"
        r"            exposureDurationMicros\?\.let \{\n"
        r"                options\.setCaptureRequestOption\(CaptureRequest\.SENSOR_EXPOSURE_TIME, it \* 1000\)\n"
        r"            \}\n"
        r"            iso\?\.let \{ options\.setCaptureRequestOption\(CaptureRequest\.SENSOR_SENSITIVITY, it\.toInt\(\)\) \}\n"
        r"            camera2\?\.setCaptureRequestOptions\(options\.build\(\)\)(?:\?\.await\(\))?\n"
        r"        \}\n"
        r"        return suspendCancellableTakePicture\(capture\)"
    )
    replacement = """        var manualCamera2: Camera2CameraControl? = null
        if (exposureDurationMicros != null || iso != null) {
            manualCamera2 = camera?.cameraControl?.let { Camera2CameraControl.from(it) }
            val options = CaptureRequestOptions.Builder()
            val manager = context.getSystemService(Context.CAMERA_SERVICE) as CameraManager
            val selectedCharacteristicsId = selectedLensId?.let { rawId ->
                val physicalMarker = \"::physical::\"
                val markerIndex = rawId.indexOf(physicalMarker)
                if (markerIndex >= 0) {
                    rawId.substring(markerIndex + physicalMarker.length)
                } else {
                    rawId
                }
            }
            val characteristics = selectedCharacteristicsId?.let {
                try {
                    manager.getCameraCharacteristics(it)
                } catch (_: Throwable) {
                    null
                }
            }
            val exposureRange = characteristics?.get(CameraCharacteristics.SENSOR_INFO_EXPOSURE_TIME_RANGE)
            val sensitivityRange = characteristics?.get(CameraCharacteristics.SENSOR_INFO_SENSITIVITY_RANGE)

            options.setCaptureRequestOption(
                CaptureRequest.CONTROL_AE_MODE,
                CaptureRequest.CONTROL_AE_MODE_OFF
            )
            exposureDurationMicros?.let {
                val requestedNs = it * 1000L
                val safeNs = exposureRange?.let { range ->
                    requestedNs.coerceIn(range.lower, range.upper)
                } ?: requestedNs
                options.setCaptureRequestOption(CaptureRequest.SENSOR_EXPOSURE_TIME, safeNs)
            }
            iso?.let {
                val requestedIso = it.toInt()
                val safeIso = sensitivityRange?.let { range ->
                    requestedIso.coerceIn(range.lower, range.upper)
                } ?: requestedIso
                options.setCaptureRequestOption(CaptureRequest.SENSOR_SENSITIVITY, safeIso)
            }
            manualCamera2?.setCaptureRequestOptions(options.build())?.await()
        }
        return try {
            suspendCancellableTakePicture(capture)
        } finally {
            if (manualCamera2 != null) {
                try {
                    manualCamera2.clearCaptureRequestOptions().await()
                    setExposureMode(ExposureModeNative.AUTO)
                } catch (_: Throwable) {
                }
            }
        }"""
    text, count = pattern.subn(replacement, text, count=1)
    if count != 1:
        raise SystemExit("Iris capturePhoto manual exposure block not found")
    path.write_text(text)


def patch_preview_composition(root: Path) -> None:
    path = root / "android/src/main/kotlin/com/anies1212/iris_camera/IrisCameraPlugin.kt"
    text = path.read_text()
    marker = "                val previewView = PreviewView(context)\n"
    compatible = marker + "                previewView.implementationMode = PreviewView.ImplementationMode.COMPATIBLE\n"
    if "PreviewView.ImplementationMode.COMPATIBLE" not in text:
        if marker not in text:
            raise SystemExit("Iris PreviewView creation marker not found")
        text = text.replace(marker, compatible, 1)
    path.write_text(text)


def patch_flutter_focus_lock() -> None:
    path = Path("lib/screens/camera_screen.dart")
    if not path.exists():
        return
    text = path.read_text(encoding="utf-8")
    text = text.replace(
        "await _camera.setFocus(point: _focusPoint!); await _camera.setExposurePoint(_focusPoint!);",
        "await _camera.setFocus(point: _focusPoint!);",
    )
    text = text.replace(
        "await _camera.setFocus(point: p);\n      await _camera.setExposurePoint(p);",
        "await _camera.setFocus(point: p);",
    )
    path.write_text(text, encoding="utf-8")


def main() -> None:
    root = find_iris_root()
    patch_image_util(root)
    patch_camera_controller(root)
    patch_preview_composition(root)
    patch_flutter_focus_lock()
    print(f"Iris Android capture + clamped true Pro manual exposure patch applied to {root.name}")


if __name__ == "__main__":
    main()
