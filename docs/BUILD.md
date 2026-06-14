# Build & install (no Mac required)

## How CI builds an unsigned IPA

`.github/workflows/ios-build.yml` runs on `macos-latest`:

1. `brew install xcodegen`
2. `xcodegen generate` → produces `Growly.xcodeproj` from `project.yml`
3. `xcodebuild … -sdk iphoneos -destination 'generic/platform=iOS' clean build CODE_SIGNING_ALLOWED=NO`
4. Package: copy `Release-iphoneos/Growly.app` into `Payload/`, zip → `Growly-<version>-<run>.ipa`
5. Upload as a workflow artifact (14-day retention)

Trigger it by pushing to `main`, or **Actions → iOS Build → Run workflow**.

## Run it locally (if you ever get a Mac)

```bash
brew install xcodegen
xcodegen generate
open Growly.xcodeproj   # build & run on a simulator or device
```

## Unit tests

`.github/workflows/tests.yml` (dispatch-only, to save free macOS minutes) runs the
gamification tests on a simulator:

```bash
xcodegen generate
xcodebuild test -scheme Growly -destination 'platform=iOS Simulator,name=iPhone 16'
```

## Install with Sideloadly

1. Download the `Growly-*.ipa` artifact and unzip once to get the `.ipa`.
2. Install iTunes (apple.com build) + [Sideloadly](https://sideloadly.io/).
3. Connect your iPhone, drag the `.ipa` into Sideloadly, sign in with a **free Apple ID**,
   Start.
4. On device: **Settings → General → VPN & Device Management → Trust**.

> Free Apple ID limits: the app must be re-signed every **7 days**, max 3 sideloaded
> apps. Growly uses no entitlement-gated capabilities, so nothing is disabled on a
> free sideload.

## Versioning

`VERSION` is the source of truth used to name the IPA; keep `MARKETING_VERSION` in
`project.yml` in sync when you cut a release.
