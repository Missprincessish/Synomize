#!/bin/zsh
set -u

PROJECT="/Users/angie/Documents/SYN_HUMANITY_MASTER/VectorVerse-Godot"
ADB="/Users/angie/Library/Android/sdk/platform-tools/adb"
AAPT="/Users/angie/Library/Android/sdk/build-tools/36.0.0/aapt2"
LOG_DIR="/Users/angie/Desktop/VectorVerse Quest Logs"
STAMP="$(date '+%Y-%m-%d_%H-%M-%S')"
LOG="$LOG_DIR/quest-launch-$STAMP.log"

mkdir -p "$LOG_DIR"
exec > >(tee -a "$LOG") 2>&1

show_message() {
	[[ "${VECTORVERSE_SUPPRESS_DIALOG:-0}" == "1" ]] && return
	/usr/bin/osascript \
		-e 'on run argv' \
		-e 'display dialog (item 2 of argv) with title (item 1 of argv) buttons {"OK"} default button "OK"' \
		-e 'end run' -- "$1" "$2" >/dev/null 2>&1 || true
}

fail() {
	print "ERROR: $1"
	show_message "Synomize Quest Launcher" "$1\n\nTroubleshooting log:\n$LOG"
	exit 1
}

print "VectorVerse Quest launch started: $(date)"
[[ -x "$ADB" ]] || fail "Android adb was not found."
[[ -x "$AAPT" ]] || fail "Android APK inspection tool was not found."

DEVICE_COUNT="$($ADB devices | awk 'NR > 1 && $2 == "device" {count++} END {print count+0}')"
UNAUTHORIZED_COUNT="$($ADB devices | awk 'NR > 1 && $2 == "unauthorized" {count++} END {print count+0}')"
[[ "$UNAUTHORIZED_COUNT" == "0" ]] || fail "The Quest is connected but USB debugging is not authorized. Check the headset."
[[ "$DEVICE_COUNT" == "1" ]] || fail "Connect exactly one authorized Quest. Detected: $DEVICE_COUNT."

APK="$(find "$PROJECT/Builds/Quest" -type f -name '*SmokeTest*.apk' -print0 2>/dev/null | xargs -0 ls -t 2>/dev/null | head -1)"
[[ -n "$APK" && -f "$APK" ]] || fail "No Synomize smoke-test APK was found."

PACKAGE="$($AAPT dump badging "$APK" 2>/dev/null | sed -n "s/^package: name='\([^']*\)'.*/\1/p" | head -1)"
[[ -n "$PACKAGE" ]] || fail "The APK package name could not be verified."
ACTIVITY="com.godot.game.GodotAppLauncher"

print "Quest: $($ADB devices -l | awk 'NR == 2 {print}')"
print "APK: $APK"
print "Package: $PACKAGE"
print "Launch activity: $ACTIVITY"

$ADB install -r -d "$APK" || fail "The APK could not be installed or updated."
$ADB shell pm path "$PACKAGE" >/dev/null || fail "Android did not report the package as installed."
$ADB logcat -c || true
$ADB shell am force-stop "$PACKAGE" || true
$ADB shell am start -n "$PACKAGE/$ACTIVITY" || fail "Android rejected the launch command."

PID=""
for attempt in {1..15}; do
	PID="$($ADB shell pidof "$PACKAGE" 2>/dev/null | tr -d '\r')"
	[[ -n "$PID" ]] && break
	sleep 1
done

if [[ -z "$PID" ]]; then
	$ADB logcat -d -t 400 | grep -E "$PACKAGE|Guardian|Godot|OpenXR" | tail -120 || true
	fail "Synomize installed, but the app process did not start. Put on the headset, clear any Guardian screen, then double-click this launcher again."
fi

print "SUCCESS: package installed and process started with PID $PID"
show_message "Synomize Quest Launcher" "Synomize installed and launched successfully. Put on the headset now.\n\nLog saved to:\n$LOG"
