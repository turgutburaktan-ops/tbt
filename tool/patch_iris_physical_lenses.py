from pathlib import Path
import glob
import re


def find_iris_root() -> Path:
    matches = sorted(glob.glob(str(Path.home() / '.pub-cache/hosted/pub.dev/iris_camera-*')))
    if not matches:
        raise SystemExit('iris_camera package cache not found')
    return Path(matches[-1])


def patch_controller(root: Path) -> None:
    path = root / 'android/src/main/kotlin/com/anies1212/iris_camera/CameraController.kt'
    text = path.read_text(encoding='utf-8')

    if 'android.os.Build' not in text:
        text = text.replace(
            'import android.hardware.camera2.CaptureRequest\n',
            'import android.hardware.camera2.CaptureRequest\nimport android.os.Build\n',
            1,
        )

    list_pattern = re.compile(
        r'    suspend fun listAvailableLenses\(includeFront: Boolean\): List<CameraLensDescriptorNative> \{.*?\n    \}\n\n    suspend fun switchLens',
        re.S,
    )

    new_list = r'''    suspend fun listAvailableLenses(includeFront: Boolean): List<CameraLensDescriptorNative> {
        ensureInitialized()
        val manager = context.getSystemService(Context.CAMERA_SERVICE) as CameraManager
        val result = mutableListOf<CameraLensDescriptorNative>()
        val seenIds = mutableSetOf<String>()

        fun appendDescriptor(
            descriptorId: String,
            displayName: String,
            characteristics: CameraCharacteristics,
            fallbackFacing: Int? = null,
        ) {
            if (!seenIds.add(descriptorId)) return
            val facing = characteristics.get(CameraCharacteristics.LENS_FACING) ?: fallbackFacing
            val position = when (facing) {
                CameraCharacteristics.LENS_FACING_FRONT -> CameraLensPositionNative.FRONT
                CameraCharacteristics.LENS_FACING_EXTERNAL -> CameraLensPositionNative.EXTERNAL
                else -> CameraLensPositionNative.BACK
            }
            if (!includeFront && position == CameraLensPositionNative.FRONT) return

            val (category, fov) = LensCategorizer.categoryFor(characteristics)
            val focalLength = characteristics
                .get(CameraCharacteristics.LENS_INFO_AVAILABLE_FOCAL_LENGTHS)
                ?.minOrNull()
            val afModes = characteristics
                .get(CameraCharacteristics.CONTROL_AF_AVAILABLE_MODES)
                ?: intArrayOf()
            val supportsFocus = afModes.any {
                it == CaptureRequest.CONTROL_AF_MODE_AUTO ||
                    it == CaptureRequest.CONTROL_AF_MODE_CONTINUOUS_PICTURE
            }

            result.add(
                CameraLensDescriptorNative(
                    id = descriptorId,
                    name = displayName,
                    position = position,
                    category = category,
                    supportsFocus = supportsFocus,
                    focalLength = focalLength?.toDouble(),
                    fieldOfView = fov,
                )
            )
        }

        try {
            manager.cameraIdList.forEach { cameraId ->
                val logicalCharacteristics = manager.getCameraCharacteristics(cameraId)
                val logicalFacing = logicalCharacteristics.get(CameraCharacteristics.LENS_FACING)

                // Physical sensors must be listed before the logical wrapper.
                // Some logical multi-camera descriptors report the shortest
                // focal length and may otherwise look like an ultra-wide lens.
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                    logicalCharacteristics.physicalCameraIds.forEach { physicalId ->
                        try {
                            val physicalCharacteristics = manager.getCameraCharacteristics(physicalId)
                            appendDescriptor(
                                descriptorId = "$cameraId::physical::$physicalId",
                                displayName = "Camera $cameraId / physical $physicalId",
                                characteristics = physicalCharacteristics,
                                fallbackFacing = logicalFacing,
                            )
                        } catch (physicalError: Throwable) {
                            Log.w(
                                "IrisCamera",
                                "Unable to inspect physical camera $physicalId",
                                physicalError,
                            )
                        }
                    }
                }

                appendDescriptor(
                    descriptorId = cameraId,
                    displayName = "Camera $cameraId",
                    characteristics = logicalCharacteristics,
                    fallbackFacing = logicalFacing,
                )
            }
        } catch (error: CameraAccessException) {
            Log.e("IrisCamera", "Failed to list cameras", error)
            throw error
        }

        if (selectedLensId == null && result.isNotEmpty()) {
            val defaultLens = result.firstOrNull {
                it.position == CameraLensPositionNative.BACK &&
                    it.category == CameraLensCategoryNative.WIDE
            } ?: result.firstOrNull {
                it.position == CameraLensPositionNative.BACK
            } ?: result.first()
            selectedLensId = defaultLens.id
            selectedDescriptor = defaultLens
        }
        return result
    }

    suspend fun switchLens'''

    text, count = list_pattern.subn(new_list, text, count=1)
    if count != 1:
        raise SystemExit('listAvailableLenses block not found')

    old_bind_head = '''        val lensId = selectedLensId ?: listAvailableLenses(includeFront = true).firstOrNull()?.id
        val lifecycleOwner = lifecycleOwnerProvider.invoke()
            ?: throw IllegalStateException("No lifecycle owner available for camera binding.")
        val selector = if (lensId != null) {
            CameraSelector.Builder()
                .addCameraFilter { cameras ->
                    cameras.filter { info ->
                        Camera2CameraInfo.from(info).cameraId == lensId
                    }
                }
                .build()
        } else {
            CameraSelector.DEFAULT_BACK_CAMERA
        }
'''

    new_bind_head = '''        val selectedId = selectedLensId ?: listAvailableLenses(includeFront = true).firstOrNull()?.id
        val physicalMarker = "::physical::"
        val physicalIndex = selectedId?.indexOf(physicalMarker) ?: -1
        val logicalLensId = if (physicalIndex >= 0) {
            selectedId!!.substring(0, physicalIndex)
        } else {
            selectedId
        }
        val physicalLensId = if (physicalIndex >= 0) {
            selectedId!!.substring(physicalIndex + physicalMarker.length)
        } else {
            null
        }

        val lifecycleOwner = lifecycleOwnerProvider.invoke()
            ?: throw IllegalStateException("No lifecycle owner available for camera binding.")
        val selector = if (logicalLensId != null) {
            CameraSelector.Builder()
                .addCameraFilter { cameras ->
                    cameras.filter { info ->
                        Camera2CameraInfo.from(info).cameraId == logicalLensId
                    }
                }
                .build()
        } else {
            CameraSelector.DEFAULT_BACK_CAMERA
        }
'''

    if old_bind_head in text:
        text = text.replace(old_bind_head, new_bind_head, 1)
    elif 'val physicalMarker = "::physical::"' not in text:
        raise SystemExit('bindUseCases lens selector block not found')

    interop_marker = '''        val previewInterop = Camera2Interop.Extender(previewBuilder)
        val captureInterop = Camera2Interop.Extender(captureBuilder)
        val analysisInterop = Camera2Interop.Extender(analysisBuilder)
'''
    interop_replacement = interop_marker + '''        if (physicalLensId != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            previewInterop.setPhysicalCameraId(physicalLensId)
            captureInterop.setPhysicalCameraId(physicalLensId)
            analysisInterop.setPhysicalCameraId(physicalLensId)
        }
'''
    if 'previewInterop.setPhysicalCameraId(physicalLensId)' not in text:
        if interop_marker not in text:
            raise SystemExit('Camera2 interop marker not found')
        text = text.replace(interop_marker, interop_replacement, 1)

    old_video = '''        val qualitySelector = qualitySelectorForPreset(resolutionPreset)
        recorder = Recorder.Builder().setQualitySelector(qualitySelector).build()
        videoCapture = VideoCapture.withOutput(recorder!!)
'''
    new_video = '''        // Physical-camera forcing is configured on photo/preview use cases.
        // Do not attach the generic video use case to that session because a
        // mixed logical/physical session can be rejected on some devices.
        if (physicalLensId == null) {
            val qualitySelector = qualitySelectorForPreset(resolutionPreset)
            recorder = Recorder.Builder().setQualitySelector(qualitySelector).build()
            videoCapture = VideoCapture.withOutput(recorder!!)
        } else {
            recorder = null
            videoCapture = null
        }
'''
    if old_video in text:
        text = text.replace(old_video, new_video, 1)
    elif 'if (physicalLensId == null)' not in text:
        raise SystemExit('video setup block not found')

    path.write_text(text, encoding='utf-8')


def main() -> None:
    root = find_iris_root()
    patch_controller(root)
    print(f'Iris physical lens patch applied to {root.name}')


if __name__ == '__main__':
    main()
