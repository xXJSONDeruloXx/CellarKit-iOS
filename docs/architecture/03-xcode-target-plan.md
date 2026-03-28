# Suggested Xcode target plan

This is a concrete target/module layout for the first real Apple-platform implementation.

## Goals

- keep domain logic testable outside the app target,
- isolate iOS-specific code from pure planning code,
- make low-level runtime work replaceable,
- keep future agent work parallelizable.

## Recommended targets

### 1. `CellarApp` (iOS app target)

Responsibilities:
- SwiftUI screens,
- scene lifecycle,
- document picker / file importer,
- settings,
- runtime status UI,
- launch flow orchestration.

Depends on:
- `CellarCore`
- `CellarHost`

### 2. `CellarCore` (Swift package / shared module)

Responsibilities:
- domain models,
- planning logic,
- policy classification,
- container metadata models,
- provider/runtime protocols.

Should avoid:
- UIKit,
- SwiftUI,
- Objective-C runtime hacks,
- direct file importer APIs.

### 3. `CellarHost` (Apple-platform integration module)

Responsibilities:
- iOS capability detection,
- security-scoped bookmark handling,
- lifecycle adapters,
- audio session ownership,
- controller discovery,
- bridge-friendly file paths.

Depends on:
- `CellarCore`

### 4. `CellarRuntimeBridge` (Objective-C++ / C++ bridge target)

Responsibilities:
- wrap native runtime entry points,
- expose start/stop/log callbacks,
- convert Swift-friendly config into native runtime config,
- own in-process threading bootstrap.

Depends on:
- native runtime libs,
- `CellarCore` model translation glue where needed.

### 5. `CellarOverlay` (optional later Swift module)

Responsibilities:
- touch overlay UI,
- runtime quick menu,
- controller remap UI,
- overlay profile editor.

### 6. `CellarStorefronts` (optional later module)

Responsibilities:
- auth abstraction implementations,
- library sync,
- install plans,
- cloud save adapters.

This module should be easy to omit from constrained builds.

## Test targets

### `CellarCoreTests`

Use for:
- planning decisions,
- metadata encoding,
- migration logic,
- save-path mapping.

### `CellarHostTests`

Use for:
- bookmark persistence behavior where testable,
- capability-detection classification,
- launch configuration assembly.

### `CellarRuntimeBridgeTests` (later)

Use for:
- smoke tests around bridge startup/shutdown,
- log callback wiring,
- configuration marshalling.

## Recommended source tree

```text
CellarKit-iOS/
  App/
    CellarApp.xcodeproj
    CellarApp/
  Packages/
    CellarCore/
  Sources/
    CellarHost/
    CellarRuntimeBridge/
    CellarOverlay/
    CellarStorefronts/
  Vendor/
  docs/
```

## Build configurations

### `ResearchDebug`

- verbose logs enabled,
- capability banners enabled,
- experimental backends visible,
- internal diagnostics exposed.

### `ResearchRelease`

- side-load oriented,
- reduced debug noise,
- still allows experimental backends.

### `ConstrainedDebug`

- policy-sensitive feature flags visible,
- storefront modules optionally disabled,
- interpreter-only or narrow backend mode possible.

### `ConstrainedRelease`

- minimal feature surface,
- explicit product-lane restrictions,
- only the intended public-safe features compiled in.

## Dependency principles

1. Keep third-party runtime dependencies out of the main app target where possible.
2. Prefer explicit wrapper layers over direct calls from SwiftUI into native runtime code.
3. Keep storefront logic optional at compile time.
4. Keep container metadata in `CellarCore` so both app and runtime bridge can share it.

## Why this split matters

It lets multiple agents work at once:
- one agent on docs and policy,
- one on `CellarCore`,
- one on the iOS host shell,
- one on runtime bridge experiments.
