#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_dir="$(cd "${script_dir}/../.." && pwd)"
raw_dir="${1:-${project_dir}/build/screenshots/store-listing/raw}"
output_dir="${2:-${project_dir}/fastlane/metadata/android/en-US/images/phoneScreenshots}"
manifest="${3:-${script_dir}/copy.tsv}"
font_regular="${project_dir}/assets/fonts/Poppins-Regular.ttf"
font_bold="${project_dir}/assets/fonts/Poppins-Bold.ttf"

magick_bin="${MAGICK_BIN:-$(command -v magick || true)}"
convert_bin="${CONVERT_BIN:-$(command -v convert || true)}"
image_command="${magick_bin:-${convert_bin}}"

if [[ -z ${image_command} ]]; then
	echo "ImageMagick is required to generate store screenshots." >&2
	exit 69
fi

for required_file in "${manifest}" "${font_regular}" "${font_bold}"; do
	if [[ ! -f ${required_file} ]]; then
		echo "Required screenshot input not found: ${required_file}" >&2
		exit 66
	fi
done

mkdir -p "${output_dir}"

while IFS=$'\t' read -r filename accent title subtitle; do
	if [[ ${filename} == "filename" || -z ${filename} ]]; then
		continue
	fi
	raw_path="${raw_dir}/${filename}.png"
	output_path="${output_dir}/${filename}.png"
	if [[ ! -f ${raw_path} ]]; then
		echo "Raw screenshot not found: ${raw_path}" >&2
		exit 66
	fi

	"${image_command}" \
		-size 1080x1920 "gradient:#080B17-#151B36" \
		-fill "#${accent}20" -stroke none \
		-draw "circle 1010,120 1010,390" \
		-draw "circle 70,1780 70,1510" \
		\( "${raw_path}" -resize 760x1420 -background "#0B0D12" -gravity center -extent 760x1420 \) \
		-gravity northwest -geometry +160+390 -compose over -composite \
		-fill none -stroke "#${accent}" -strokewidth 4 \
		-draw "roundrectangle 154,384,926,1816,30,30" \
		-font "${font_bold}" -fill "#${accent}" -stroke none -pointsize 24 \
		-annotate +72+62 "TTUSH PUSH" \
		-font "${font_bold}" -fill white -pointsize 52 \
		-annotate +72+120 "${title}" \
		-font "${font_regular}" -fill "#FFFFFFCC" -pointsize 27 \
		-annotate +72+220 "${subtitle}" \
		-alpha off -type TrueColor -depth 8 "${output_path}"
done <"${manifest}"
