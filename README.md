# CellarKit iOS

Research and implementation scaffolding for a Wine/CrossOver/Whisky-style Windows game runtime host for iPhone and iPad.

## Status

Current state of the repo:
- first-pass research is complete,
- architecture docs are in place,
- `CellarCore` planning/persistence exists,
- `CellarHost` launch orchestration exists,
- `CellarUI` and `CellarPreviewApp` provide a runnable SwiftUI host-shell prototype on Apple platforms.

## Repository layout

### Research
- `docs/research/01-executive-summary.md`
- `docs/research/02-prior-art.md`
- `docs/research/03-platform-constraints.md`
- `docs/research/04-licensing-and-policy.md`
- `docs/research/05-source-index.md`
- `docs/research/06-open-questions.md`
- `docs/research/07-component-matrix.md`
- `docs/research/08-benchmark-and-test-plan.md`

### Architecture
- `docs/architecture/01-proposed-architecture.md`
- `docs/architecture/02-roadmap.md`
- `docs/architecture/03-xcode-target-plan.md`
- `docs/architecture/04-first-mvp-spec.md`
- `docs/architecture/05-host-stack.md`

### Agent guidance
- `docs/agents/01-autonomous-build-plan.md`
- `docs/agents/02-next-implementation-queue.md`

### Swift modules
- `Sources/CellarCore/`
- `Sources/CellarHost/`
- `Sources/CellarUI/`
- `Sources/CellarPreviewApp/`

## Implemented modules

### `CellarCore`
Pure domain and planning logic:
- distribution channels,
- product lanes,
- JIT/execution modes,
- guest architectures,
- acquisition modes,
- backend planning,
- policy risk grading,
- container metadata,
- container persistence,
- runtime-profile defaults.

### `CellarHost`
Apple-host integration and orchestration scaffolding:
- capability detection overrides and heuristics,
- launch-session models,
- per-session JSON + log persistence,
- simulated runtime bridge,
- actor-based host coordinator.

### `CellarUI`
SwiftUI host-shell prototype:
- capability summary,
- container list,
- sample-container creation,
- planner inspection,
- launch-session history,
- latest-log viewer.

### `CellarPreviewApp`
A lightweight preview shell that exercises the host stack with a simulated runtime.

## First-pass conclusions still holding

- A straight macOS wrapper port is not realistic.
- A side-load / developer-signed / jailbreak-first MVP is the most credible path.
- UTM remains the strongest iOS-native runtime reference.
- GameNative remains the strongest mobile UX reference.
- App Store distribution for a full Windows-game storefront runner remains a separate, high-risk question.

## Local validation

Run the full test suite:

```bash
swift test
```

Launch the preview host shell on macOS:

```bash
swift run CellarPreviewApp
```

## Most important next implementation steps

1. Replace the simulated runtime bridge with a native bridge spike.
2. Add a real iOS app target that embeds `CellarUI`/`CellarHost`.
3. Replace heuristic capability detection with real-device classification.
4. Implement security-scoped bookmark import and persistent payload access.
5. Add durable launch metrics and experiment-result capture.
6. Prove one narrow interactive sample path on device.
