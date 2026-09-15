#!/usr/bin/env bash
set -euo pipefail
mkdir -p /tmp/route-review
adb shell wm size 1080x2400
adb shell wm density 420
adb install -r build/app/outputs/flutter-apk/app-debug.apk
adb shell am force-stop com.google.android.apps.nexuslauncher || true
adb shell am start -n com.tbt.social/.MainActivity
sleep 25
adb shell am force-stop com.google.android.apps.nexuslauncher || true
adb shell am start -n com.tbt.social/.MainActivity
sleep 3
adb shell uiautomator dump /sdcard/window.xml >/dev/null
adb pull /sdcard/window.xml /tmp/route-review/window.xml >/dev/null
if grep -q "isn.t responding" /tmp/route-review/window.xml; then
  echo 'System ANR dialog obscures preview'; exit 1
fi
adb shell screencap -p /sdcard/route-top.png
adb pull /sdcard/route-top.png /tmp/route-review/route-top.png
adb shell screenrecord --time-limit 22 /sdcard/route-preview.mp4 &
recording=$!
sleep 3
adb shell input swipe 540 1830 540 730 700
sleep 4
adb shell screencap -p /sdcard/route-details.png
adb pull /sdcard/route-details.png /tmp/route-review/route-details.png
adb shell input swipe 540 730 540 1830 700
sleep 4
adb shell input tap 940 620
sleep 4
adb shell input keyevent 4
wait "$recording"
adb pull /sdcard/route-preview.mp4 /tmp/route-review/route-preview.mp4
adb logcat -d -s flutter > /tmp/route-review/flutter-log.txt
