#!/usr/bin/env bash

set -euo pipefail

readonly expected_blob_sha='30e7b9b694caa8ea4f74d2db24c9eeebfa3374a4'
project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly project_root
readonly plugin_file="${project_root}/rust_builder/cargokit/gradle/plugin.gradle"
actual_blob_sha="$(git hash-object "${plugin_file}")"
readonly actual_blob_sha

if [[ ${actual_blob_sha} != "${expected_blob_sha}" ]]; then
	echo "Expected Cargokit Gradle plugin ${expected_blob_sha}, found ${actual_blob_sha}." >&2
	echo "Sync from fzyzcjy/cargokit commit 8e2cfa1710503b596f1ca552ecb98ad43d71ebef before regenerating the bridge." >&2
	exit 1
fi
