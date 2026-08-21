#!/usr/bin/env bash

set -euo pipefail

readonly expected_codegen_version='flutter_rust_bridge_codegen 2.12.0'
project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly project_root
actual_codegen_version="$(flutter_rust_bridge_codegen --version)"
readonly actual_codegen_version

if [[ ${actual_codegen_version} != "${expected_codegen_version}" ]]; then
	echo "Expected ${expected_codegen_version}, found ${actual_codegen_version}." >&2
	exit 1
fi

cd "${project_root}"
flutter_rust_bridge_codegen generate --stop-on-error
bash "${project_root}/tool/verify_cargokit_gradle_plugin.sh"
rustfmt --edition 2024 engine/src/lib.rs engine/src/api.rs engine/src/frb_generated.rs
