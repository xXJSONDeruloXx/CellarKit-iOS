# Local testing and toolchain notes

This document records the local testing setup now configured for the repo.

## Installed tools

The machine now has:
- `xcodegen`
- `ios-deploy`
- `xcpretty` via RubyGems at `~/.gem/ruby/2.6.0/bin/xcpretty`

## External-drive usage

Mounted external drive detected:
- `/Volumes/mac-mini-ex`

To reduce pressure on internal storage, Apple-platform build outputs were redirected to the external drive where practical.

### Active externalized paths
- `~/Library/Developer/Xcode/DerivedData` -> `/Volumes/mac-mini-ex/DeveloperBuilds/ApplePlatformCaches/DerivedData`
- project-specific derived data -> `/Volumes/mac-mini-ex/DeveloperBuilds/CellarKit-iOS/DerivedData`
- Xcode test results -> `/Volumes/mac-mini-ex/DeveloperBuilds/CellarKit-iOS/TestResults`
- Homebrew cache used during installs -> `/Volumes/mac-mini-ex/DeveloperBuilds/HomebrewCache`

### Important limitation for simulators

A direct move of `~/Library/Developer/CoreSimulator` to `/Volumes/mac-mini-ex` was attempted and then reverted.

Reason:
- the external APFS volume has **ownership disabled**,
- `CoreSimulatorService` could not create/write device state there,
- simulator device creation failed with permission errors.

Current active simulator location therefore remains:
- `~/Library/Developer/CoreSimulator`

If the user later enables ownership on a dedicated external volume, or if a sparsebundle/image with ownership enabled is mounted from the external disk, the simulator device set can be retried there.

## iOS app project generation

A generated Xcode project lives under:
- `App/CellarApp/CellarApp.xcodeproj`

Generate or regenerate it with:

```bash
./scripts/dev/generate-ios-project.sh
```

## Simulator test automation

Run the iOS simulator smoke test with:

```bash
./scripts/dev/test-ios-simulator.sh
```

What it does:
- generates the Xcode project,
- creates a dedicated simulator device if needed,
- boots the simulator,
- runs the `CellarApp` UI smoke test,
- stores the `.xcresult` bundle on the external drive.

## Current validation status

Verified locally:
- `swift test`
- `./scripts/dev/test-ios-simulator.sh`

The simulator smoke test currently exercises:
- app launch,
- sample-container creation,
- native-stub runtime launch,
- basic UI flow completion on iOS Simulator.

The UI smoke path currently uses `CELLARKIT_AUTOLAUNCH_AFTER_CREATE=true` so the test can validate create + launch deterministically without relying on a second UI tap.
