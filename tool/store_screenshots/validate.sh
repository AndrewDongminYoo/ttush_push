#!/usr/bin/env bash

set -euo pipefail

listing_dir="${1:-fastlane/metadata/android/en-US}"

if ! command -v magick >/dev/null 2>&1; then
	echo "ImageMagick is required to validate store assets." >&2
	exit 69
fi

required_files=(
	"title.txt"
	"short_description.txt"
	"full_description.txt"
	"images/icon.png"
	"images/featureGraphic.png"
)

for required_file in "${required_files[@]}"; do
	if [[ ! -f "${listing_dir}/${required_file}" ]]; then
		echo "Missing required store asset: ${listing_dir}/${required_file}" >&2
		exit 66
	fi
done

validate_text_limit() {
	local relative_path="$1"
	local limit="$2"
	local character_count
	character_count="$(LC_ALL=C.UTF-8 tr -d '\r\n' <"${listing_dir}/${relative_path}" | wc -m | tr -d ' ')"
	if ((character_count > limit)); then
		echo "${relative_path} exceeds ${limit} characters." >&2
		exit 65
	fi
}

validate_text_limit "title.txt" 30
validate_text_limit "short_description.txt" 80
validate_text_limit "full_description.txt" 4000

validate_dimensions() {
	local relative_path="$1"
	local expected_dimensions="$2"
	local actual_dimensions
	actual_dimensions="$(magick identify -format '%wx%h' "${listing_dir}/${relative_path}")"
	if [[ ${actual_dimensions} != "${expected_dimensions}" ]]; then
		echo "$(basename "${relative_path}") must be ${expected_dimensions}, found ${actual_dimensions}." >&2
		exit 65
	fi
}

validate_dimensions "images/icon.png" "512x512"
validate_dimensions "images/featureGraphic.png" "1024x500"

shopt -s nullglob
screenshots=("${listing_dir}"/images/phoneScreenshots/*.png)
if ((${#screenshots[@]} < 4)); then
	echo "Expected at least 4 phone screenshots, found ${#screenshots[@]}." >&2
	exit 65
fi
for screenshot in "${screenshots[@]}"; do
	relative_path="images/phoneScreenshots/$(basename "${screenshot}")"
	validate_dimensions "${relative_path}" "1080x1920"
done

echo "Play Store assets are valid."
