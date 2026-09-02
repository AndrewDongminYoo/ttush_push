#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
magick_bin="${MAGICK_BIN:-$(command -v magick || true)}"
oxipng_bin="${OXIPNG_BIN:-$(command -v oxipng || true)}"

if [[ -z ${magick_bin} ]]; then
	echo "ImageMagick is required: install magick or set MAGICK_BIN." >&2
	exit 1
fi

if [[ -z ${oxipng_bin} ]]; then
	echo "OxiPNG is required: install oxipng or set OXIPNG_BIN." >&2
	exit 1
fi

app_icon_artwork_source="${repo_root}/assets/images/branding/app_icon_artwork.png"
azure_source="${repo_root}/assets/images/sprites/azure_explorer_top_down.png"
ember_source="${repo_root}/assets/images/sprites/ember_explorer_top_down.png"
foothold_source="${repo_root}/assets/images/sprites/foothold_intact.png"

for source_file in "${app_icon_artwork_source}" "${azure_source}" "${ember_source}" "${foothold_source}"; do
	if [[ ! -f ${source_file} ]]; then
		echo "Missing brand source: ${source_file}" >&2
		exit 1
	fi
done

branding_dir="${repo_root}/assets/images/branding"
temporary_dir="$(mktemp -d "${TMPDIR:-/tmp}/ttush-brand-assets.XXXXXX")"
trap 'rm -rf "$temporary_dir"' EXIT
mkdir -p "${branding_dir}"

app_icon="${branding_dir}/app_icon.png"
launch_mark="${branding_dir}/launch_mark.png"

"${magick_bin}" "${app_icon_artwork_source}" \
	-resize 1024x1024! \
	-alpha off \
	-strip \
	"PNG24:${app_icon}"

"${magick_bin}" -size 600x600 canvas:none \
	\( "${foothold_source}" -resize 430x430 \) \
	-gravity center \
	-geometry +0+55 \
	-composite \
	\( "${azure_source}" -resize 240x240 \) \
	-geometry -120-15 \
	-composite \
	\( "${ember_source}" -resize 240x240 \) \
	-geometry +120-15 \
	-composite \
	-strip \
	"PNG32:${launch_mark}"

compose_flavor_icon() {
	local badge_dir="$1"
	local output_path="$2"

	"${magick_bin}" "${app_icon}" \
		\( "${badge_dir}/Flag.png" -resize 360x360 \) \
		-gravity northeast \
		-geometry +0+0 \
		-composite \
		\( "${badge_dir}/Environment.png" -resize 360x360 \) \
		-geometry +0+0 \
		-composite \
		-alpha off \
		-strip \
		"PNG24:${output_path}"
}

compose_flavor_icon \
	"${repo_root}/ios/Runner/AppIcons/AppIcon-dev.icon/Assets" \
	"${temporary_dir}/app-icon-development.png"
compose_flavor_icon \
	"${repo_root}/ios/Runner/AppIcons/AppIcon-stg.icon/Assets" \
	"${temporary_dir}/app-icon-staging.png"

"${magick_bin}" -size 1024x1024 canvas:none \
	-fill white \
	-draw 'roundrectangle 24,24 1000,1000 190,190' \
	"${temporary_dir}/rounded-mask.png"
"${magick_bin}" -size 1024x1024 canvas:none \
	-fill white \
	-draw 'circle 512,512 512,24' \
	"${temporary_dir}/round-mask.png"

generate_android_flavor() {
	local source_set="$1"
	local icon_source="$2"
	local badge_dir="${3:-}"
	local source_root="${repo_root}/android/app/src/${source_set}"

	mkdir -p "${source_root}/res/drawable-xxxhdpi"
	"${magick_bin}" "${app_icon}" \
		-resize 432x432! \
		-alpha off \
		-strip \
		"PNG24:${source_root}/res/drawable-xxxhdpi/ic_launcher_background_art.png"
	if [[ -n ${badge_dir} ]]; then
		"${magick_bin}" -size 432x432 canvas:none \
			\( "${badge_dir}/Flag.png" -resize 96x96 \) \
			-gravity northeast \
			-geometry +84+84 \
			-composite \
			\( "${badge_dir}/Environment.png" -resize 96x96 \) \
			-geometry +84+84 \
			-composite \
			-strip \
			"PNG32:${source_root}/res/drawable-xxxhdpi/ic_launcher_foreground.png"
	fi
	"${magick_bin}" "${icon_source}" \
		"${temporary_dir}/rounded-mask.png" \
		-alpha off \
		-compose CopyOpacity \
		-composite \
		-strip \
		"PNG32:${temporary_dir}/${source_set}-rounded.png"
	"${magick_bin}" "${icon_source}" \
		"${temporary_dir}/round-mask.png" \
		-alpha off \
		-compose CopyOpacity \
		-composite \
		-strip \
		"PNG32:${temporary_dir}/${source_set}-round.png"
	"${magick_bin}" "${icon_source}" -resize 512x512 -strip \
		"PNG24:${source_root}/ic_launcher-playstore.png"

	local density
	local size
	for density_and_size in mdpi:48 hdpi:72 xhdpi:96 xxhdpi:144 xxxhdpi:192; do
		density="${density_and_size%%:*}"
		size="${density_and_size##*:}"
		mkdir -p "${source_root}/res/mipmap-${density}"
		"${magick_bin}" "${temporary_dir}/${source_set}-rounded.png" \
			-resize "${size}x${size}" \
			-strip \
			"PNG32:${source_root}/res/mipmap-${density}/ic_launcher.png"
		"${magick_bin}" "${temporary_dir}/${source_set}-round.png" \
			-resize "${size}x${size}" \
			-strip \
			"PNG32:${source_root}/res/mipmap-${density}/ic_launcher_round.png"
	done
}

generate_android_flavor main "${app_icon}"
generate_android_flavor \
	development \
	"${temporary_dir}/app-icon-development.png" \
	"${repo_root}/ios/Runner/AppIcons/AppIcon-dev.icon/Assets"
generate_android_flavor \
	staging \
	"${temporary_dir}/app-icon-staging.png" \
	"${repo_root}/ios/Runner/AppIcons/AppIcon-stg.icon/Assets"

mkdir -p "${repo_root}/android/app/src/main/res/drawable-xhdpi"
"${magick_bin}" "${launch_mark}" -resize 512x512 -strip \
	"PNG32:${repo_root}/android/app/src/main/res/drawable-xhdpi/ic_launch_image.png"

for apple_root in "${repo_root}/ios/Runner/AppIcons" "${repo_root}/macos/AppIcons"; do
	cp "${app_icon}" "${apple_root}/AppIcon.icon/Assets/Artwork.png"
	cp "${branding_dir}/icon-composer.json" "${apple_root}/AppIcon.icon/icon.json"
	cp "${temporary_dir}/app-icon-development.png" \
		"${apple_root}/AppIcon-dev.icon/Assets/Artwork.png"
	cp "${branding_dir}/icon-composer.json" "${apple_root}/AppIcon-dev.icon/icon.json"
	cp "${temporary_dir}/app-icon-staging.png" \
		"${apple_root}/AppIcon-stg.icon/Assets/Artwork.png"
	cp "${branding_dir}/icon-composer.json" "${apple_root}/AppIcon-stg.icon/icon.json"
done

ios_launch_root="${repo_root}/ios/Runner/Assets.xcassets/LaunchImage.imageset"
"${magick_bin}" "${launch_mark}" -resize 150x150 -strip \
	"PNG32:${ios_launch_root}/LaunchImage@1x.png"
"${magick_bin}" "${launch_mark}" -resize 300x300 -strip \
	"PNG32:${ios_launch_root}/LaunchImage@2x.png"
cp "${launch_mark}" "${ios_launch_root}/LaunchImage@3x.png"

"${magick_bin}" "${app_icon}" -resize 512x512 -strip \
	"PNG24:${repo_root}/web/icons/Icon-512.png"
"${magick_bin}" "${app_icon}" -resize 192x192 -strip \
	"PNG24:${repo_root}/web/icons/Icon-192.png"
"${magick_bin}" "${app_icon}" -resize 32x32 -strip \
	"PNG24:${repo_root}/web/favicon.png"
cp "${repo_root}/web/favicon.png" "${repo_root}/web/icons/favicon.png"
"${magick_bin}" "${launch_mark}" -resize 192x192 -strip \
	"PNG32:${repo_root}/web/icons/LaunchMark-192.png"

find \
	"${branding_dir}" \
	"${repo_root}/android/app/src/main" \
	"${repo_root}/android/app/src/development" \
	"${repo_root}/android/app/src/staging" \
	"${repo_root}/ios/Runner/AppIcons" \
	"${repo_root}/ios/Runner/Assets.xcassets/LaunchImage.imageset" \
	"${repo_root}/macos/AppIcons" \
	"${repo_root}/web/icons" \
	"${repo_root}/web/favicon.png" \
	-type f \
	\( \
	-name 'app_icon.png' -o \
	-name 'launch_mark.png' -o \
	-name 'ic_launcher*.png' -o \
	-name 'ic_launch_image.png' -o \
	-name 'Artwork.png' -o \
	-name 'LaunchImage*.png' -o \
	-name 'Icon-*.png' -o \
	-name 'LaunchMark-*.png' -o \
	-name 'favicon.png' \
	\) \
	-print0 |
	xargs -0 "${oxipng_bin}" --quiet --strip safe

echo "Generated branded app icons and launch assets."
