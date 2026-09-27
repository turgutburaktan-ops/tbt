from pathlib import Path
import re
import sys


def find_package_root() -> Path:
    roots = [
        Path.home() / ".pub-cache" / "hosted" / "pub.dev",
        Path.home() / ".pub-cache" / "hosted" / "pub.dartlang.org",
    ]
    for root in roots:
        for package in sorted(root.glob("camerawesome-*"), reverse=True):
            if (package / "pubspec.yaml").exists():
                return package
    raise SystemExit("CamerAwesome package not found")


if len(sys.argv) > 1:
    supplied = Path(sys.argv[1])
    package_root = next(
        (parent for parent in [supplied, *supplied.parents]
         if (parent / "pubspec.yaml").exists()),
        None,
    )
    if package_root is None:
        raise SystemExit(f"CamerAwesome package root not found for: {supplied}")
else:
    package_root = find_package_root()

path = package_root / (
    "android/src/main/kotlin/com/apparence/camerawesome/"
    "cameraX/CameraAwesomeX.kt"
)
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

# CamerAwesome compares filter objects by identity. AwesomeFilter.None creates
# a new object on every access, so even the natural preview was unnecessarily
# rendered through ColorFiltered. Compare stable IDs instead and keep the
# original camera texture completely untouched in Doğal mode.
preview_path = (
    package_root / "lib/src/widgets/preview/awesome_camera_preview.dart"
)
preview_text = preview_path.read_text(encoding="utf-8")
old_condition = "snapshot.data != AwesomeFilter.None"
new_condition = "snapshot.data!.id != AwesomeFilter.None.id"
if old_condition in preview_text:
    preview_text = preview_text.replace(old_condition, new_condition, 1)
elif new_condition not in preview_text:
    raise SystemExit("CamerAwesome natural-preview filter condition not found")
preview_path.write_text(preview_text, encoding="utf-8")

print(f"CamerAwesome preview-only filters and untouched natural texture applied in {package_root}")
