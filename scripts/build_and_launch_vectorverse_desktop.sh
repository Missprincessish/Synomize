#!/bin/zsh
set -u

PROJECT="/Users/angie/Documents/SYN_HUMANITY_MASTER/VectorVerse-Godot"
GODOT="/Applications/Godot.app/Contents/MacOS/Godot"
ADB="/Users/angie/Library/Android/sdk/platform-tools/adb"
APK="$PROJECT/Builds/Quest/VectorVerse-Quest-SmokeTest.apk"
PREVIOUS="$PROJECT/Builds/Quest/Previous"
LOG_DIR="/Users/angie/Desktop/VectorVerse Quest Logs"
STAMP="$(date '+%Y-%m-%d_%H-%M-%S')"
LOG="$LOG_DIR/build-and-launch-$STAMP.log"

mkdir -p "$LOG_DIR" "$PREVIOUS"
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
	show_message "Build and Launch Synomize" "$1\n\nThe working APK was preserved.\nLog:\n$LOG"
	exit 1
}

print "Synomize test, build, and launch started: $(date)"
[[ -x "$GODOT" ]] || fail "Godot was not found."
[[ -x "$ADB" ]] || fail "Android adb was not found."

TESTS=(
	"tests/vertical_slice_test.gd"
	"tests/player_interaction_test.gd"
	"tests/xr_adapter_contract_test.gd"
	"tests/quest_smoke_preflight_test.gd"
)

for TEST in "${TESTS[@]}"; do
	print "Running $TEST"
	"$GODOT" --headless --path "$PROJECT" --script "$PROJECT/$TEST" || fail "Tests failed at $TEST. No new APK was built."
done

if [[ -f "$APK" ]]; then
	BACKUP="$PREVIOUS/VectorVerse-Quest-SmokeTest-$STAMP.apk"
	cp -p "$APK" "$BACKUP" || fail "The previous APK could not be preserved."
	print "Preserved previous APK: $BACKUP"
fi

"$GODOT" --headless --editor --quit --path "$PROJECT" || fail "Godot project import failed."
"$GODOT" --headless --path "$PROJECT" --export-debug "Meta Quest Smoke Test" "$APK" || fail "The signed Quest APK build failed."
[[ -s "$APK" ]] || fail "Godot did not produce the Quest APK."

print "Build completed: $APK"
VECTORVERSE_SUPPRESS_DIALOG=1 "$PROJECT/scripts/vectorverse_quest_desktop_launcher.sh" || fail "The APK built, but installation or launch failed."
show_message "Build and Launch Synomize" "Tests passed, the previous APK was preserved, and the new Synomize build launched.\n\nLog saved to:\n$LOG"
