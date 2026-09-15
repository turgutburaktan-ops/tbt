from pathlib import Path
import sys


def find_camera_x_state() -> Path:
    roots = [
        Path.home() / ".pub-cache" / "hosted" / "pub.dev",
        Path.home() / ".pub-cache" / "hosted" / "pub.dartlang.org",
    ]
    for root in roots:
        for package in sorted(root.glob("camerawesome-*"), reverse=True):
            candidate = package / (
                "android/src/main/kotlin/com/apparence/camerawesome/"
                "cameraX/CameraXState.kt"
            )
            if candidate.exists():
                return candidate
    raise SystemExit("CamerAwesome CameraXState.kt not found")


path = Path(sys.argv[1]) if len(sys.argv) > 1 else find_camera_x_state()
if not path.exists():
    raise SystemExit(f"CamerAwesome CameraXState.kt not found: {path}")
text = path.read_text(encoding="utf-8")

marker = "val imageCapture = ImageCapture.Builder()\n"
quality = (
    "val imageCapture = ImageCapture.Builder()\n"
    "                    .setCaptureMode(ImageCapture.CAPTURE_MODE_MAXIMIZE_QUALITY)\n"
    "                    .setJpegQuality(100)\n"
)

text = text.replace(
    ".setCaptureMode(ImageCapture.CAPTURE_MODE_MINIMIZE_LATENCY)",
    ".setCaptureMode(ImageCapture.CAPTURE_MODE_MAXIMIZE_QUALITY)",
)

if "CAPTURE_MODE_MAXIMIZE_QUALITY" not in text:
    count = text.count(marker)
    if count != 2:
        raise SystemExit(f"Expected two ImageCapture builders, found {count}")
    text = text.replace(marker, quality)

# CamerAwesome 2.5.0 applies its highest-available selector to both the JPEG
# and the live Preview use cases. A sensor-sized preview wastes GPU/bandwidth
# without improving the saved photo. Keep ImageCapture at the highest sensor
# size, but bind the live preview near the device display resolution.
preview_marker = (
    "Preview.Builder()\n"
    "                            .setResolutionSelector(resolutionSelector)\n"
    "                            .build()"
)
preview_balanced = (
    "Preview.Builder()\n"
    "                            .setTargetResolution(\n"
    "                                if (aspectRatio == AspectRatio.RATIO_16_9) Size(1920, 1080)\n"
    "                                else Size(1920, 1440)\n"
    "                            )\n"
    "                            .build()"
)
old_preview_balanced = (
    "Preview.Builder()\n"
    "                            .setTargetResolution(\n"
    "                                if (aspectRatio == AspectRatio.RATIO_16_9) Size(1280, 720)\n"
    "                                else Size(1280, 960)\n"
    "                            )\n"
    "                            .build()"
)
text = text.replace(old_preview_balanced, preview_balanced)
if preview_balanced not in text:
    count = text.count(preview_marker)
    if count != 1:
        raise SystemExit(f"Expected one single-camera Preview builder, found {count}")
    text = text.replace(preview_marker, preview_balanced)

path.write_text(text, encoding="utf-8")
print(f"CamerAwesome maximum-quality JPEG and high-resolution preview applied to {path}")
