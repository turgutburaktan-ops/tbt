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

    # Use the highest available still resolution by default. The original
    # package defaults to HIGH (1920x1080), which is visibly below modern phone
    # still-camera resolution.
    text = text.replace(
        "private var resolutionPreset: ResolutionPresetNative = ResolutionPresetNative.high",
        "private var resolutionPreset: ResolutionPresetNative = ResolutionPresetNative.max",
        1,
    )

    # Meter only AF on tap. Iris upstream combines AF + AE in setFocus(), which
    # can push some vendor CameraX preview sessions into a grey/washed state.
    text = text.replace(
        "FocusMeteringAction.Builder(meteringPoint, FocusMeteringAction.FLAG_AF or FocusMeteringAction.FLAG_AE)",
        "FocusMeteringAction.Builder(meteringPoint, FocusMeteringAction.FLAG_AF)",
        1,
    )

    # When MAX leaves targetSize null, explicitly keep preview/capture on a 4:3
    # sensor family so the viewfinder and JPEG are based on the same field of
    # view instead of independently choosing 16:9/4:3 streams.
    if "import androidx.camera.core.AspectRatio" not in text:
        text = text.replace(
            "import androidx.camera.core.Camera\n",
            "import androidx.camera.core.Camera\nimport androidx.camera.core.AspectRatio\n",
            1,
        )

    target_block = '''        if (targetSize != null) {
            previewBuilder.setTargetResolution(targetSize)
            captureBuilder.setTargetResolution(targetSize)
            analysisBuilder.setTargetResolution(targetSize)
        }
'''
    target_replacement = '''        if (targetSize != null) {
            previewBuilder.setTargetResolution(targetSize)
            captureBuilder.setTargetResolution(targetSize)
            analysisBuilder.setTargetResolution(targetSize)
        } else {
            previewBuilder.setTargetAspectRatio(AspectRatio.RATIO_4_3)
            captureBuilder.setTargetAspectRatio(AspectRatio.RATIO_4_3)
            analysisBuilder.setTargetAspectRatio(AspectRatio.RATIO_4_3)
        }
'''
    if target_block in text:
        text = text.replace(target_block, target_replacement, 1)
    elif "previewBuilder.setTargetAspectRatio(AspectRatio.RATIO_4_3)" not in text:
        raise SystemExit("Iris target resolution block not found")

    # CameraX documents MAXIMIZE_QUALITY as the still-capture mode that favors
    # quality over latency; explicitly request JPEG 100 as well.
    capture_block = '''        val captureUseCase = captureBuilder
            .setCaptureMode(ImageCapture.CAPTURE_MODE_MINIMIZE_LATENCY)
            .setFlashMode(ImageCapture.FLASH_MODE_AUTO)
            .build()
'''
    capture_replacement = '''        val captureUseCase = captureBuilder
            .setCaptureMode(ImageCapture.CAPTURE_MODE_MAXIMIZE_QUALITY)
            .setJpegQuality(100)
            .setFlashMode(ImageCapture.FLASH_MODE_AUTO)
            .build()
'''
    if capture_block in text:
        text = text.replace(capture_block, capture_replacement, 1)
    elif "CAPTURE_MODE_MAXIMIZE_QUALITY" not in text:
        raise SystemExit("Iris capture quality block not found")

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
    if count != 1 and "var manualCamera2: Camera2CameraControl?" not in text:
        raise SystemExit("Iris capturePhoto manual exposure block not found")

    path.write_text(text)


def patch_preview_composition(root: Path) -> None:
    path = root / "android/src/main/kotlin/com/anies1212/iris_camera/IrisCameraPlugin.kt"
    text = path.read_text()
    marker = "                val previewView = PreviewView(context)\n"
    compatible = marker + "                previewView.implementationMode = PreviewView.ImplementationMode.COMPATIBLE\n                previewView.scaleType = PreviewView.ScaleType.FIT_CENTER\n"
    if "PreviewView.ScaleType.FIT_CENTER" not in text:
        if marker not in text:
            raise SystemExit("Iris PreviewView creation marker not found")
        if "PreviewView.ImplementationMode.COMPATIBLE" in text:
            text = text.replace(
                "                previewView.implementationMode = PreviewView.ImplementationMode.COMPATIBLE\n",
                "                previewView.implementationMode = PreviewView.ImplementationMode.COMPATIBLE\n                previewView.scaleType = PreviewView.ScaleType.FIT_CENTER\n",
                1,
            )
        else:
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
    print(f"Iris Android MAX-quality capture + AF-only focus patch applied to {root.name}")


if __name__ == "__main__":
    main()
