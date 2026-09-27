from pathlib import Path

from PIL import Image, ImageOps


SOURCE_DIR = Path("assets/spots")
OUTPUT_DIR = Path("assets/spot_thumbnails")
SUPPORTED_SUFFIXES = {".jpg", ".jpeg", ".png", ".webp"}
TARGET_SIZE = (480, 320)


def main() -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    generated = 0

    for source in sorted(SOURCE_DIR.iterdir()):
        if not source.is_file() or source.suffix.lower() not in SUPPORTED_SUFFIXES:
            continue

        destination = OUTPUT_DIR / f"{source.stem}.webp"
        with Image.open(source) as original:
            oriented = ImageOps.exif_transpose(original)
            preview = ImageOps.fit(
                oriented.convert("RGB"),
                TARGET_SIZE,
                method=Image.Resampling.LANCZOS,
                centering=(0.5, 0.5),
            )
            preview.save(
                destination,
                format="WEBP",
                quality=68,
                method=6,
            )
        generated += 1

    if generated == 0:
        raise RuntimeError("No spot thumbnails were generated")

    total_bytes = sum(path.stat().st_size for path in OUTPUT_DIR.glob("*.webp"))
    print(f"Generated {generated} spot thumbnails ({total_bytes / 1024 / 1024:.1f} MiB)")


if __name__ == "__main__":
    main()
