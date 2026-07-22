#!/bin/zsh
set -euo pipefail

ADB="/Users/angie/Library/Android/sdk/platform-tools/adb"
APK="/Users/angie/Documents/SYN_HUMANITY_MASTER/VectorVerse-Godot/Builds/Quest/VectorVerse-Quest-SmokeTest.apk"
PACKAGE="org.synhumanity.vectorverse.smoketest"

"$ADB" start-server
DEVICE_LINE=$("$ADB" devices | sed -n '2p')
if [[ -z "$DEVICE_LINE" ]]; then
  echo "Quest not detected. Connect the USB cable, put on the headset, and allow USB debugging."
  exit 1
fi
if [[ "$DEVICE_LINE" == *"unauthorized"* ]]; then
  echo "Quest is waiting for permission. Put on the headset and choose Always allow from this computer."
  exit 1
fi

"$ADB" install -r -d "$APK"
"$ADB" shell am force-stop "$PACKAGE"
"$ADB" logcat -c
"$ADB" shell monkey -p "$PACKAGE" -c android.intent.category.LAUNCHER 1

echo "Synomize Quest smoke test installed and launched. Put on the headset now."
echo "For live Godot status later, run: $ADB logcat -s godot"
