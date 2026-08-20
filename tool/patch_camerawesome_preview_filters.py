from pathlib import Path
import re
import sys


def find_camera_awesome_x() -> Path:
    roots = [
        Path.home() / ".pub-cache" / "hosted" / "pub.dev",
        Path.home() / ".pub-cache" / "hosted" / "pub.dartlang.org",
    ]
    for root in roots:
        for package in sorted(root.glob("camerawesome-*"), reverse=True):
            candidate = package / (
                "android/src/main/kotlin/com/apparence/camerawesome/"
                "cameraX/CameraAwesomeX.kt"
            )
            if candidate.exists():
                return candidate
    raise SystemExit("CamerAwesome CameraAwesomeX.kt not found")


path = Path(sys.argv[1]) if len(sys.argv) > 1 else find_camera_awesome_x()
if not path.exists():
    raise SystemExit(f"CamerAwesome CameraAwesomeX.kt not found: {path}")

text = path.read_text(encoding="utf-8")
pattern = re.compile(
    r"\n\s{20}if \(colorMatrix != null && noneFilter != colorMatrix\) \{"
    r".*?"
    r"\n\s{20}\}\n"
    r"(?=\n\s{20}if \(exifPreferences\.saveGPSLocation\))",
    flags=re.DOTALL,
)
replacement = (
    "\n                    // Filters remain GPU-only in the live preview. Applying\n"
    "                    // them here decoded the full sensor JPEG on the main\n"
    "                    // thread and caused multi-second freezes/OOM crashes.\n"
)
text, count = pattern.subn(replacement, text, count=1)
if count != 1 and "Filters remain GPU-only in the live preview" not in text:
    raise SystemExit("CamerAwesome captured-filter block not found")

path.write_text(text, encoding="utf-8")
print(f"CamerAwesome live filters kept preview-only in {path}")
