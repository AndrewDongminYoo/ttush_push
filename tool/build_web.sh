#!/usr/bin/env bash

set -euo pipefail

readonly expected_codegen_version='flutter_rust_bridge_codegen 2.13.0'
project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly project_root
actual_codegen_version="$(flutter_rust_bridge_codegen --version)"
readonly actual_codegen_version

if [[ ${actual_codegen_version} != "${expected_codegen_version}" ]]; then
	echo "Expected ${expected_codegen_version}, found ${actual_codegen_version}." >&2
	exit 1
fi

cd "${project_root}"
flutter_rust_bridge_codegen build-web \
	--dart-root . \
	--rust-root engine \
	--output ../web \
	--release
flutter build web --release --target lib/main_production.dart
