from pathlib import Path


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


path = find_camera_x_state()
text = path.read_text(encoding="utf-8")

marker = "val imageCapture = ImageCapture.Builder()\n"
quality = (
    "val imageCapture = ImageCapture.Builder()\n"
    "                    .setCaptureMode(ImageCapture.CAPTURE_MODE_MAXIMIZE_QUALITY)\n"
    "                    .setJpegQuality(100)\n"
)

if "CAPTURE_MODE_MAXIMIZE_QUALITY" not in text:
    count = text.count(marker)
    if count != 2:
        raise SystemExit(f"Expected two ImageCapture builders, found {count}")
    text = text.replace(marker, quality)

path.write_text(text, encoding="utf-8")
print(f"CamerAwesome maximum-quality still capture applied to {path}")
