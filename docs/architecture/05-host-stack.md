# Host stack implementation snapshot

This document describes the **currently implemented** host-side stack in the repository.

## Why this layer exists

The project needed something more concrete than research docs but still lighter than a full native runtime bridge. The current host stack provides that middle layer:
- persistent container metadata,
- deterministic planning,
- launch-session recording,
- a simulated runtime pipeline,
- a SwiftUI shell that future agents can replace piece by piece.

## Implemented modules

## `CellarCore`

Responsibilities already implemented:
- execution planning,
- product-lane feature gating,
- container metadata,
- imported-content references,
- runtime profiles,
- JSON-backed container persistence,
- default profile generation through `ContainerFactory`.

Important files:
- `Sources/CellarCore/Planning/ExecutionPlanner.swift`
- `Sources/CellarCore/Planning/ContainerFactory.swift`
- `Sources/CellarCore/Planning/ContainerLaunchRequestAdapter.swift`
- `Sources/CellarCore/Persistence/ContainerStore.swift`

## `CellarHost`

Responsibilities already implemented:
- capability detection with environment overrides,
- launch-session record models,
- per-container session persistence,
- benchmark capture derived from launch sessions,
- bookmark and managed-copy import abstractions,
- a simulated runtime bridge,
- actor-based orchestration through `HostCoordinator`.

Important files:
- `Sources/CellarHost/Benchmark/BenchmarkModels.swift`
- `Sources/CellarHost/Benchmark/BenchmarkStore.swift`
- `Sources/CellarHost/Environment/HostCapabilityDetector.swift`
- `Sources/CellarHost/Import/BookmarkStore.swift`
- `Sources/CellarHost/Import/ContentImportCoordinator.swift`
- `Sources/CellarHost/Sessions/LaunchSessionModels.swift`
- `Sources/CellarHost/Sessions/LaunchSessionStore.swift`
- `Sources/CellarHost/Runtime/RuntimeBridge.swift`
- `Sources/CellarHost/Runtime/SimulatedRuntimeBridge.swift`
- `Sources/CellarHost/Orchestration/HostCoordinator.swift`

## `CellarUI`

Responsibilities already implemented:
- display detected capability snapshot,
- show containers,
- create a sample container,
- show current planning decision,
- show recent launch sessions,
- show latest captured runtime log.

Important files:
- `Sources/CellarUI/ViewModels/HostShellViewModel.swift`
- `Sources/CellarUI/Views/HostShellRootView.swift`

## `CellarPreviewApp`

This is a thin executable wrapper around `CellarUI`.

Purpose:
- give future agents a real shell to evolve,
- make the host flow runnable before an iOS app target exists,
- validate that the orchestration layers are coherent end to end.

## `CellarRuntimeBridge`

This module now provides a native C-backed bridge stub.

Implemented pieces:
- C bridge API in `Sources/CCellarBridgeStub/`,
- Swift wrapper in `Sources/CellarRuntimeBridge/NativeRuntimeBridge.swift`,
- event translation into `RuntimeBridgeEvent`,
- tests proving callback-driven happy/failure paths.

## `CellarApp`

This is the first dedicated iOS app target.

Implemented pieces:
- XcodeGen project spec at `App/CellarApp/project.yml`,
- SwiftUI app entrypoint at `App/CellarApp/CellarApp/CellarApp.swift`,
- simulator UI smoke test at `App/CellarApp/CellarAppUITests/CellarAppUITests.swift`,
- automation scripts in `scripts/dev/`.

## Current end-to-end flow

1. Detect lane and capability assumptions.
2. Create or load a container.
3. Convert the container to a launch request.
4. Run the planner.
5. Launch through the runtime bridge abstraction.
6. Record launch events and log output.
7. Persist session history.
8. Surface state in SwiftUI.

## What is still simulated

The following pieces are placeholders and must be replaced later:
- actual iOS entitlement/runtime detection,
- hardened security-scoped bookmark resolution,
- real Wine/runtime bootstrap,
- real render/input lifecycle handling.

## Why this is still useful

Even with a simulated bridge, the stack already exercises the product decisions that matter:
- whether a lane allows a backend,
- whether x64 should fall back to interpreter mode,
- whether a session is recorded as success or failure,
- whether container state survives relaunch,
- whether the host shell can display the right information.

## Immediate upgrade path

### Step 1
Replace `SimulatedRuntimeBridge` with a bridge that only fakes logs but uses the real startup/shutdown threading model.

### Step 2
Replace the current smoke-test-oriented iOS app target with a fuller app shell that owns import flows, settings, and app-sandbox-aware storage.

### Step 3
Replace `HostCapabilityDetector` heuristics with device/sandbox-aware detection.

### Step 4
Add bookmark-backed import flows and durable payload mounting.

### Step 5
Add benchmark capture so every runtime attempt generates machine-readable evidence.
