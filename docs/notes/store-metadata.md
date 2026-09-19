# Store metadata layout

Both store listings are kept in the repository under `fastlane/`, in the layout mirae settled on: text under `metadata/`, images under `screenshots/`, and the upload lanes in the platform directories pointing back up at these trees.
Added 2026-09-19, when the App Store listing was pulled from App Store Connect next to the Play listing that had been here since 2026-09-05.

```log
fastlane/
  metadata/android/{en-US,ko-KR}/   title, short_description, full_description, changelogs/<versionCode>.txt
  metadata/ios/                     copyright, the six category files, review_information/
  metadata/ios/{en-US,ko}/          name, subtitle, description, keywords, promotional_text, release_notes, support_url, marketing_url, privacy_url
  screenshots/android/en-US/        Play phone screenshots, 1080x1920
  screenshots/ios/en-US/            App Store screenshots as deliver names them (APP_IPHONE_65, APP_IPAD_PRO_3GEN_129)
  screenshots/store_artwork/en-US/  Play featureGraphic (1024x500) and icon (512x512)
```

The locale codes differ per store and are not interchangeable: Play uses `ko-KR`, App Store Connect uses `ko`.
Only `en-US` carries screenshots on either store today.

## Who reads what

- `merry run release alpha publish` uploads the AAB and `metadata/android/<locale>/changelogs/<versionCode>.txt`, nothing else; `tool/release_android_alpha.dart` validates those changelogs and `docs/notes/android-release-checklist.md` owns that flow.
- `tool/store_screenshots/generate.sh` writes the Play screenshots into `screenshots/android/en-US/`, and `tool/store_screenshots/validate.sh` checks the Play text limits, the artwork and screenshot dimensions across the three Play directories.
  `supply` would read images from `metadata/android/<locale>/images/` if a lane ever uploaded them; none does, so the images live only under `screenshots/` and a future image-upload lane copies them across, as mirae's does.
- `ios/fastlane/Deliverfile` points `metadata_path` and `screenshots_path` at `metadata/ios` and `screenshots/ios`, so `deliver` reads and writes these trees directly.
  `review_information/notes.txt` is generated from `docs/notes/app-review-information.md`, which owns the text and the command.
  `review_information/email_address.txt` and `phone_number.txt` are ignored because the repository is public; recreate them on a new machine before running a metadata upload.

## Commands

The iOS lanes are not in `merry.yaml` yet, so they run directly, each from its platform directory with that directory's bundle and the Ruby named by `.ruby-version`:

```sh
cd ios
BUNDLE_PATH=vendor/bundle bundle install
BUNDLE_PATH=vendor/bundle bundle exec fastlane deliver download_metadata
BUNDLE_PATH=vendor/bundle bundle exec fastlane deliver download_screenshots
BUNDLE_PATH=vendor/bundle bundle exec fastlane ios metadata
```

`download_*` overwrite the trees with what App Store Connect holds, so run them on a clean tree and read the diff before committing.
`ios metadata` uploads text and screenshots without a binary and skips screenshots on its own while a review submission is open.
Both need an Apple ID login with two-factor authentication, so they are run by hand rather than from an agent session.
