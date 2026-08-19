from pathlib import Path
import os
import re
import subprocess


def configure_gradle() -> None:
    gradle = Path("android/app/build.gradle")
    gradle_kts = Path("android/app/build.gradle.kts")
    app_gradle = gradle if gradle.exists() else gradle_kts
    if not app_gradle.exists():
        raise SystemExit("Android app Gradle file not found")

    text = app_gradle.read_text()
    text = text.replace("compileSdkVersion flutter.compileSdkVersion", "compileSdkVersion 36")
    text = text.replace("compileSdk = flutter.compileSdkVersion", "compileSdk = 36")
    text = text.replace("compileSdkVersion 35", "compileSdkVersion 36")
    text = text.replace("compileSdk = 35", "compileSdk = 36")
    text = text.replace("minSdkVersion flutter.minSdkVersion", "minSdkVersion 26")
    text = text.replace("minSdk = flutter.minSdkVersion", "minSdk = 26")
    text = re.sub(r'applicationId\s+["\'][^"\']+["\']', 'applicationId "com.example.tbt"', text)
    text = re.sub(r'applicationId\s*=\s*["\'][^"\']+["\']', 'applicationId = "com.example.tbt"', text)
    app_gradle.write_text(text)

    settings = Path("android/settings.gradle")
    settings_kts = Path("android/settings.gradle.kts")
    settings_file = settings if settings.exists() else settings_kts
    if not settings_file.exists():
        raise SystemExit("Android settings Gradle file not found")

    st = settings_file.read_text()
    st = re.sub(
        r'(org\.jetbrains\.kotlin\.android[^\n]*version\s+["\'])[0-9.]+',
        r'\g<1>2.2.20',
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

    gradle_properties = Path("android/gradle.properties")
    if gradle_properties.exists():
        gp = gradle_properties.read_text()
        if "android.newDsl=" not in gp:
            if gp and not gp.endswith("\n"):
                gp += "\n"
            gp += "android.newDsl=false\n"
        else:
            gp = re.sub(r'^android\.newDsl=.*$', 'android.newDsl=false', gp, flags=re.MULTILINE)
        gradle_properties.write_text(gp)


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
        '<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />',
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
        meta = "\n        <meta-data\n            android:name=\"com.google.android.geo.API_KEY\"\n            android:value=\"%s\" />\n" % maps_key
        text = text[:app_end + 1] + meta + text[app_end + 1:]
    activity_end = text.find("</activity>")
    if activity_end >= 0:
        activity_start = text.rfind("<activity", 0, activity_end)
        activity_block = text[activity_start:activity_end]
        additions = ""
        if "flutter_deeplinking_enabled" not in activity_block:
            additions += '\n            <meta-data android:name="flutter_deeplinking_enabled" android:value="false" />\n'
        if 'android:scheme="tbt"' not in activity_block:
            additions += '''\n            <intent-filter>\n                <action android:name="android.intent.action.VIEW" />\n                <category android:name="android.intent.category.DEFAULT" />\n                <category android:name="android.intent.category.BROWSABLE" />\n                <data android:scheme="tbt" />\n            </intent-filter>\n'''
        if additions:
            text = text[:activity_end] + additions + text[activity_end:]
    manifest.write_text(text)


def copy_firebase() -> None:
    target = Path("android/app/google-services.json")
    candidates = [path for path in Path(".").rglob("*google*services*.json") if path.resolve() != target.resolve()]
    if not candidates:
        raise SystemExit("google-services.json not found")
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(candidates[0].read_bytes())


def patch_app_features() -> None:
    subprocess.run(["python3", "tool/patch_explore_spot_repository.py"], check=True)
    subprocess.run(["python3", "tool/patch_messages_navigation.py"], check=True)
    subprocess.run(["python3", "tool/patch_social_event_invites.py"], check=True)


def main() -> None:
    configure_gradle()
    configure_manifest()
    copy_firebase()
    patch_app_features()
    print("Android build preparation complete")


if __name__ == "__main__":
    main()
