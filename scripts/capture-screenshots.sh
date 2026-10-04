#!/bin/bash
set -euo pipefail

# Run from any directory. Only shot 8 is simulator-capturable; see the plan.
# DERIVED overrides build output. SHOT_WAIT defaults to 4 seconds;
# SHOT_WAIT_<n> overrides the settling delay for an individual shot.
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

for tool in xcodebuild xcrun python3 sips; do
    command -v "$tool" >/dev/null || fail "Required tool not found: $tool"
done
[[ -x /usr/libexec/PlistBuddy ]] || fail 'PlistBuddy is unavailable.'

derived="${DERIVED:-.build/shots}"
mkdir -p "$derived"
devices_file="$(mktemp "$derived/devices.XXXXXX")"
# Empty sentinels keep these arrays safe under macOS Bash 3.2 + nounset.
booted_ids=("")
override_ids=("")

cleanup() {
    local result=$? id
    trap - EXIT
    for id in "${override_ids[@]}"; do
        [[ -n "$id" ]] || continue
        if ! xcrun simctl status_bar "$id" clear; then
            printf 'ERROR: Could not clear status bar override: %s\n' "$id" >&2
            result=1
        fi
    done
    for id in "${booted_ids[@]}"; do
        [[ -n "$id" ]] || continue
        if ! xcrun simctl shutdown "$id"; then
            printf 'ERROR: Could not shut down simulator: %s\n' "$id" >&2
            result=1
        fi
    done
    rm -f "$devices_file"
    exit "$result"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

xcrun simctl list devices available -j > "$devices_file"
device_names=('iPhone 18 Pro Max' 'iPad Pro 13-inch (M5)')
device_slugs=('iphone-18-pro-max' 'ipad-pro-13-inch-m5')
widths=(1320 2064)
heights=(2868 2752)
device_ids=()
device_states=()

# Resolve both devices before booting either; ambiguous names fail explicitly.
for index in 0 1; do
    selected="$(python3 -c '
import json, sys
with open(sys.argv[1]) as source:
    devices = json.load(source)["devices"]
matches = [device for runtime, entries in devices.items() if ".iOS-" in runtime
           for device in entries
           if device.get("isAvailable") and device["name"] == sys.argv[2]]
if len(matches) != 1:
    sys.exit("ERROR: Expected one available iOS simulator named " + sys.argv[2]
             + "; found " + str(len(matches))
             + ". Install it in Xcode or resolve duplicate device names.")
device = matches[0]
if device["state"] not in ("Booted", "Shutdown"):
    sys.exit("ERROR: Simulator is transitioning: " + sys.argv[2]
             + " (" + device["state"] + "). Retry when settled.")
print(device["udid"] + "\t" + device["state"])
' "$devices_file" "${device_names[$index]}")"
    IFS=$'\t' read -r device_id device_state <<< "$selected"
    device_ids[index]="$device_id"
    device_states[index]="$device_state"
done

xcodebuild build -project RoomTone.xcodeproj -scheme RoomTone \
    -configuration Debug -destination 'generic/platform=iOS Simulator' \
    -derivedDataPath "$derived" CODE_SIGNING_ALLOWED=NO

app_path="$(python3 -c '
import glob, os, sys
apps = glob.glob(os.path.join(sys.argv[1], "Build", "Products",
                             "Debug-iphonesimulator", "*.app"))
if len(apps) != 1:
    sys.exit("ERROR: Expected one built simulator .app; found " + str(len(apps)))
print(apps[0])
' "$derived")"
bundle_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app_path/Info.plist")"
[[ -n "$bundle_id" ]] || fail 'Built app has no bundle identifier.'

capture_device() {
    local index=$1
    shift
    local id="${device_ids[$index]}" shot wait_key wait_seconds output dimensions termination_output
    printf 'Preparing %s (%s x %s)\n' "${device_names[$index]}" \
        "${widths[$index]}" "${heights[$index]}"
    if [[ "${device_states[$index]}" == Shutdown ]]; then
        xcrun simctl boot "$id"
        booted_ids+=("$id")
    fi
    xcrun simctl bootstatus "$id" -b
    override_ids+=("$id")
    xcrun simctl status_bar "$id" override --time 9:41 --dataNetwork wifi \
        --wifiBars 3 --cellularBars 4 --batteryState charged --batteryLevel 100
    xcrun simctl install "$id" "$app_path"
    xcrun simctl ui "$id" appearance dark

    for shot in "$@"; do
        if [[ "$shot" != 8 ]]; then
            printf '%s shot %02d: OPERATOR: capture on device (LiDAR/camera required)\n' \
                "${device_names[$index]}" "$shot"
            continue
        fi
        wait_key="SHOT_WAIT_$shot"
        wait_seconds="${!wait_key:-${SHOT_WAIT:-4}}"
        [[ "$wait_seconds" =~ ^[0-9]+([.][0-9]+)?$ ]] || \
            fail "$wait_key / SHOT_WAIT must be a nonnegative number of seconds."
        output="screenshots/appstore/${device_slugs[$index]}/$(printf '%02d' "$shot").png"
        mkdir -p "$(dirname "$output")"
        # Ignore only ESRCH (no running process), never an actual termination
        # failure that could leave a stale app instance behind.
        if ! termination_output="$(xcrun simctl terminate "$id" "$bundle_id" 2>&1)"; then
            if [[ "$termination_output" != *'domain=NSPOSIXErrorDomain, code=3'* || \
                  "$termination_output" != *'No such process'* ]]; then
                fail "Could not terminate $bundle_id: $termination_output"
            fi
        fi
        xcrun simctl launch "$id" "$bundle_id" -AppStoreScreenshot "$shot"
        sleep "$wait_seconds"
        xcrun simctl io "$id" screenshot "$output"
        dimensions="$(sips -g pixelWidth -g pixelHeight "$output" | \
            awk '/pixelWidth:/ { width=$2 } /pixelHeight:/ { height=$2 }
                 END { print width "x" height }')"
        [[ "$dimensions" == "${widths[$index]}x${heights[$index]}" ]] || \
            fail "$output is $dimensions; expected ${widths[$index]}x${heights[$index]} portrait pixels."
        printf 'Captured %s (%s)\n' "$output" "$dimensions"
    done
}

capture_device 0 1 2 3 4
capture_device 1 5 6 7 8
printf 'Simulator capture complete. Shots 1-7 still require OPERATOR: capture on device.\n'
