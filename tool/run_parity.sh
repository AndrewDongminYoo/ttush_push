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
	simulators="$(xcrun simctl list devices booted 2>/dev/null || true)"
	booted_udids="$(sed -n 's/.*(\([0-9A-Fa-f-]\{36\}\)) (Booted).*/\1/p' <<<"${simulators}")"
	collect "${booted_udids}"
fi

if command -v adb >/dev/null 2>&1; then
	attached="$(adb devices 2>/dev/null || true)"
	booted_serials="$(awk '$2 == "device" && $1 ~ /^emulator-/ { print $1 }' <<<"${attached}")"
	collect "${booted_serials}"
fi

if [[ ${#devices[@]} -eq 0 ]]; then
	echo "parity: SKIPPED, no simulator or emulator is running."
	echo "parity: this run covered no native packaging. Start a runtime and re-run to cover it."
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
