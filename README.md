# CellarKit iOS

Research and implementation scaffolding for a Wine/CrossOver/Whisky-style Windows game runtime host for iPhone and iPad.

## Status

Current state of the repo:
- first-pass research is complete,
- architecture docs are in place,
- `CellarCore` planning/persistence exists,
- `CellarHost` launch orchestration exists,
- `CellarRuntimeBridge` provides a native C-backed bridge stub,
- `CellarUI` and `CellarPreviewApp` provide a runnable SwiftUI host-shell prototype on Apple platforms,
- `App/CellarApp` provides the first dedicated iOS app target and simulator UI smoke test path.

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
- `docs/architecture/06-local-testing.md`
- `docs/architecture/07-gap-register.md`

### Agent guidance
- `docs/agents/01-autonomous-build-plan.md`
- `docs/agents/02-next-implementation-queue.md`

### Swift modules and app targets
- `Sources/CellarCore/`
- `Sources/CellarHost/`
- `Sources/CellarUI/`
- `Sources/CellarPreviewApp/`
- `App/CellarApp/`
- `scripts/dev/`

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
- benchmark capture and persistence,
- managed-copy / bookmark import abstractions,
- actor-based host coordinator.

### `CellarRuntimeBridge`
A native C-backed bridge stub that exercises callback plumbing, launch-configuration translation, and event translation before a real Wine/runtime integration exists.

### `CellarUI`
SwiftUI host-shell prototype:
- capability summary,
- container list,
- sample-container creation,
- managed-copy import via file importer,
- external-reference linking via file importer,
- planner inspection,
- launch-session history,
- benchmark summary,
- latest-log viewer.

### `CellarPreviewApp`
A lightweight preview shell that exercises the host stack using the native bridge stub.

### `CellarApp`
A generated Xcode/iOS app target plus UI smoke test harness for simulator validation.

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

Generate the iOS Xcode project:

```bash
./scripts/dev/generate-ios-project.sh
```

Run the simulator smoke test:

```bash
./scripts/dev/test-ios-simulator.sh
```

This now verifies a real iOS Simulator app flow and stores `.xcresult` bundles on the external drive.

## Most important next implementation steps

1. Replace the current native stub bridge with a real runtime bridge spike.
2. Replace heuristic capability detection with real-device classification.
3. Harden security-scoped bookmark lifecycle and external-reference access during real launches.
4. Add richer launch metrics beyond the current derived benchmarks.
5. Prove one narrow interactive sample path on device.
6. Expand the iOS app beyond the current host shell and smoke-test flow.
