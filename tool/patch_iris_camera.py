from pathlib import Path
import glob


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
        // iris_camera 1.0.6 assumes YUV and tries to read planes[1]/planes[2],
        // which breaks still capture on affected Android devices.
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

    builder_marker = "            val options = CaptureRequestOptions.Builder()\n"
    if "CaptureRequest.CONTROL_AE_MODE_OFF" not in text:
        if builder_marker not in text:
            raise SystemExit("CameraController capture options builder not found")
        replacement = builder_marker + """            // Manual ISO and shutter only become real sensor requests when AE is off.
            options.setCaptureRequestOption(
                CaptureRequest.CONTROL_AE_MODE,
                CaptureRequest.CONTROL_AE_MODE_OFF
            )
"""
        text = text.replace(builder_marker, replacement, 1)

    old_apply = "            camera2?.setCaptureRequestOptions(options.build())\n"
    new_apply = "            camera2?.setCaptureRequestOptions(options.build())?.await()\n"
    if old_apply in text:
        text = text.replace(old_apply, new_apply, 1)

    path.write_text(text)


def main() -> None:
    root = find_iris_root()
    patch_image_util(root)
    patch_camera_controller(root)
    print(f"Iris Android capture patch applied to {root.name}")


if __name__ == "__main__":
    main()
