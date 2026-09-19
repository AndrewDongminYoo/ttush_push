#!/usr/bin/env bash

set -euo pipefail

listing_dir="${1:-fastlane/metadata/android/en-US}"
screenshots_dir="${2:-fastlane/screenshots/android/en-US}"
artwork_dir="${3:-fastlane/screenshots/store_artwork/en-US}"

magick_bin="${MAGICK_BIN:-$(command -v magick || true)}"
identify_bin="${IDENTIFY_BIN:-$(command -v identify || true)}"

if [[ -z ${magick_bin} && -z ${identify_bin} ]]; then
	echo "ImageMagick is required to validate store assets." >&2
	exit 69
fi

required_files=(
	"${listing_dir}/title.txt"
	"${listing_dir}/short_description.txt"
	"${listing_dir}/full_description.txt"
	"${artwork_dir}/icon.png"
	"${artwork_dir}/featureGraphic.png"
)

for required_file in "${required_files[@]}"; do
	if [[ ! -f ${required_file} ]]; then
		echo "Missing required store asset: ${required_file}" >&2
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
	local image_path="$1"
	local expected_dimensions="$2"
	local actual_dimensions
	if [[ -n ${magick_bin} ]]; then
		actual_dimensions="$("${magick_bin}" identify -format '%wx%h' "${image_path}")"
	else
		actual_dimensions="$("${identify_bin}" -format '%wx%h' "${image_path}")"
	fi
	if [[ ${actual_dimensions} != "${expected_dimensions}" ]]; then
		echo "$(basename "${image_path}") must be ${expected_dimensions}, found ${actual_dimensions}." >&2
		exit 65
	fi
}

validate_dimensions "${artwork_dir}/icon.png" "512x512"
validate_dimensions "${artwork_dir}/featureGraphic.png" "1024x500"

shopt -s nullglob
screenshots=("${screenshots_dir}"/*.png)
if ((${#screenshots[@]} < 4)); then
	echo "Expected at least 4 phone screenshots, found ${#screenshots[@]}." >&2
	exit 65
fi
for screenshot in "${screenshots[@]}"; do
	validate_dimensions "${screenshot}" "1080x1920"
done

echo "Play Store assets are valid."
