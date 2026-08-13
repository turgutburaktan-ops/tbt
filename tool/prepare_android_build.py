from pathlib import Path
import os
import re


def configure_gradle() -> None:
    gradle = Path("android/app/build.gradle")
    gradle_kts = Path("android/app/build.gradle.kts")
    app_gradle = gradle if gradle.exists() else gradle_kts
    if not app_gradle.exists():
        raise SystemExit("Android app Gradle file not found")

    text = app_gradle.read_text()
    text = text.replace("compileSdkVersion flutter.compileSdkVersion", "compileSdkVersion 35")
    text = text.replace("compileSdk = flutter.compileSdkVersion", "compileSdk = 35")
    text = text.replace("minSdkVersion flutter.minSdkVersion", "minSdkVersion 26")
    text = text.replace("minSdk = flutter.minSdkVersion", "minSdk = 26")
    app_gradle.write_text(text)

    settings = Path("android/settings.gradle")
    settings_kts = Path("android/settings.gradle.kts")
    settings_file = settings if settings.exists() else settings_kts
    if not settings_file.exists():
        raise SystemExit("Android settings Gradle file not found")

    st = settings_file.read_text()
    st = re.sub(
        r'(org\.jetbrains\.kotlin\.android[^\n]*version\s+["\'])[0-9.]+',
        r'\g<1>1.9.24',
        st,
    )

    if "com.google.gms.google-services" not in st:
        if settings_file.suffix == ".kts":
            st = st.replace(
                "plugins {",
                'plugins {\n    id("com.google.gms.google-services") version "4.4.2" apply false',
                1,
            )
        else:
            st = st.replace(
                "plugins {",
                'plugins {\n    id "com.google.gms.google-services" version "4.4.2" apply false',
                1,
            )
    settings_file.write_text(st)

    text = app_gradle.read_text()
    if "com.google.gms.google-services" not in text:
        if app_gradle.suffix == ".kts":
            text = text.replace(
                "plugins {",
                'plugins {\n    id("com.google.gms.google-services")',
                1,
            )
        else:
            text = text.replace(
                "plugins {",
                'plugins {\n    id "com.google.gms.google-services"',
                1,
            )
        app_gradle.write_text(text)


def configure_manifest() -> None:
    manifest = Path("android/app/src/main/AndroidManifest.xml")
    if not manifest.exists():
        raise SystemExit("AndroidManifest.xml not found")

    text = manifest.read_text()
    permissions = [
        '<uses-permission android:name="android.permission.INTERNET" />',
        '<uses-permission android:name="android.permission.CAMERA" />',
        '<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />',
        '<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />',
    ]
    missing = [permission for permission in permissions if permission not in text]
    if missing:
        text = text.replace("<application", "\n".join(missing) + "\n\n    <application", 1)

    maps_key = os.environ.get("MAPS_API_KEY", "").strip()
    if not maps_key:
        raise SystemExit("MAPS_API_KEY secret is missing")

    if "com.google.android.geo.API_KEY" not in text:
        app_start = text.find("<application")
        app_end = text.find(">", app_start)
        if app_start < 0 or app_end < 0:
            raise SystemExit("Android application tag not found")
        meta = (
            "\n        <meta-data\n"
            '            android:name="com.google.android.geo.API_KEY"\n'
            f'            android:value="{maps_key}" />\n'
        )
        text = text[: app_end + 1] + meta + text[app_end + 1 :]

    manifest.write_text(text)


def copy_firebase() -> None:
    target = Path("android/app/google-services.json")
    candidates = [
        path
        for path in Path(".").rglob("*google*services*.json")
        if path.resolve() != target.resolve()
    ]
    if not candidates:
        raise SystemExit("google-services.json not found")

    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(candidates[0].read_bytes())


def main() -> None:
    configure_gradle()
    configure_manifest()
    copy_firebase()
    print("Android build preparation complete")


if __name__ == "__main__":
    main()
