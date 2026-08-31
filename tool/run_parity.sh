#!/usr/bin/env bash

# Runs the native parity test on every simulator or emulator that is already
# running, and on nothing else.
#
# The aggregate gate calls this, so it has to cost nothing when no runtime is
# up: it skips rather than booting one. Booting an emulator is the heaviest job
# on this machine, and a gate that expensive gets bypassed, which is worse than
# a gate that says plainly what it did not cover. That is why the last line is
# always either "covered" or "SKIPPED": a green gate alone means neither.
#
# It also cannot reach a physical device. Only simctl and adb are asked, so a
# connected iPhone is never a candidate; the daily phone is refused by ID as a
# second guard in case that ever stops being true.

set -euo pipefail

readonly daily_phone_id='00008140-001938282206801C'
readonly parity_test='integration_test/rules_engine_parity_test.dart'
project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly project_root

devices=()

# `flutter test -d` resolves the Android SDK from Flutter's own configuration,
# not from PATH, and an Android Studio install routinely leaves platform-tools
# off PATH. Finding no adb there would make this script report SKIPPED with an
# emulator running, which is the one thing it exists not to do.
# Each helper prints a path or nothing, and never fails: an exit status here
# would have to be read in an `if`, which switches `set -e` off inside it.
adb_under() {
	if [[ -n ${1} && -x ${1}/platform-tools/adb ]]; then
		printf '%s\n' "${1}/platform-tools/adb"
	fi
}

resolve_adb() {
	if command -v adb >/dev/null 2>&1; then
		command -v adb
		return
	fi

	local root found
	for root in "${ANDROID_HOME:-}" "${ANDROID_SDK_ROOT:-}"; do
		found="$(adb_under "${root}")"
		if [[ -n ${found} ]]; then
			printf '%s\n' "${found}"
			return
		fi
	done

	# Asked last because it costs a Flutter start-up. It reports the SDK
	# Flutter auto-detected as well as one set through `flutter config`, so it
	# subsumes the default install locations.
	local listed configured
	listed="$(flutter config --list 2>/dev/null || true)"
	configured="$(sed -n 's/^[[:space:]]*android-sdk:[[:space:]]*//p' <<<"${listed}")"
	adb_under "${configured}"
}

collect() {
	# A here-string always yields one line, so an empty list would otherwise
	# enter the loop once with an empty value and fail under `set -e`.
	local line
	while IFS= read -r line; do
		if [[ -n ${line} ]]; then
			devices+=("${line}")
		fi
	done <<<"${1}"
}

if command -v xcrun >/dev/null 2>&1; then
	# The runtime filter matters: simctl lists every booted CoreSimulator
	# device, and Flutter discovers only iOS ones, so a booted watchOS or
	# visionOS device would otherwise be handed to `flutter test -d` and fail
	# the gate on a runtime nobody asked it to cover.
	# A failed query is not an empty one. CoreSimulator wedges often enough
	# that swallowing the error here would report SKIPPED with a simulator
	# running, which is the false claim this script exists to prevent.
	if ! simulators="$(xcrun simctl list devices booted iOS 2>&1)"; then
		echo "parity: FAILED, could not list booted iOS simulators:" >&2
		echo "${simulators}" >&2
		exit 1
	fi
	booted_udids="$(sed -n 's/.*(\([0-9A-Fa-f-]\{36\}\)) (Booted).*/\1/p' <<<"${simulators}")"
	collect "${booted_udids}"
else
	echo "parity: xcrun not found, so no iOS simulator was inspected." >&2
fi

adb_bin="$(resolve_adb)"
if [[ -n ${adb_bin} ]]; then
	# Same reasoning: an adb that was found but cannot answer is an inspection
	# failure, not evidence that no emulator is running.
	if ! attached="$("${adb_bin}" devices 2>&1)"; then
		echo "parity: FAILED, ${adb_bin} could not list devices:" >&2
		echo "${attached}" >&2
		exit 1
	fi
	booted_serials="$(awk '$2 == "device" && $1 ~ /^emulator-/ { print $1 }' <<<"${attached}")"
	collect "${booted_serials}"
else
	echo "parity: adb not found, so no Android emulator was inspected." >&2
fi

if [[ ${#devices[@]} -eq 0 ]]; then
	# The status goes last in both branches, because that is where CLAUDE.md
	# tells a reader to look for it.
	echo "parity: this run covered no native packaging. Start a runtime and re-run to cover it."
	echo "parity: SKIPPED, no simulator or emulator is running."
	exit 0
fi

for device in "${devices[@]}"; do
	if [[ ${device} == "${daily_phone_id}" ]]; then
		echo "parity: refusing ${device}: that is the operator's daily phone." >&2
		exit 1
	fi
	echo "parity: running on ${device}"
	(cd "${project_root}" && flutter test "${parity_test}" -d "${device}" --flavor development)
done

echo "parity: covered ${#devices[@]} runtime(s): ${devices[*]}"
