# Roadmap

## Guiding principle

Ship the project in layers that reduce uncertainty in the right order:

1. **capabilities**
2. **import/container model**
3. **runtime proof-of-life**
4. **graphics/input/audio usability**
5. **storefront automation**
6. **public-distribution strategy**

## Phase 0 — research repo and planning core

Status:
- in progress via this repository.
- research, planning, persistence, and a preview host shell are now implemented.

Deliverables:
- source-backed docs,
- planning models,
- decision logic for backend selection,
- clear experiment list.

Exit criteria:
- future agents can read the repo and know what to implement next.

## Phase 1 — capability probe app shell

Goal:
- build a tiny host that reports runtime constraints, first as a preview shell and then as a dedicated iOS app.

Deliverables:
- device info screen,
- execution mode detection,
- debugger/JIT state reporting,
- memory-limit reporting,
- file-import smoke tests.

Current status:
- heuristic capability detection exists in `CellarHost`,
- a preview SwiftUI shell exists in `CellarUI` / `CellarPreviewApp`,
- a first dedicated iOS app target now exists at `App/CellarApp`,
- simulator UI smoke testing is automated,
- an initial SwiftUI file-import path now exists,
- real device classification is still pending.

Acceptance tests:
- launches on real device,
- correctly distinguishes side-load / debugger-attached scenarios,
- imports at least one file/folder and reopens it after relaunch.

## Phase 2 — container and import MVP

Goal:
- define the durable game/container abstraction.

Deliverables:
- create/delete container,
- attach imported payload,
- persist metadata,
- choose managed copy vs bookmark mode,
- per-container logs and settings.

Current status:
- container metadata, content references, container persistence, launch-session history, and log persistence are implemented,
- managed-copy and bookmark-storage abstractions are now implemented,
- SwiftUI file-import wiring now exists for managed copies and external references,
- true long-lived sandbox bookmark workflows are still pending.

Acceptance tests:
- container survives app relaunch,
- imported payload can be found again,
- metadata migration path exists.

## Phase 3 — embedded runtime proof-of-life

Goal:
- prove a native runtime loop can be hosted in-process on iOS.

Deliverables:
- runtime bridge scaffold,
- one minimal backend hooked into the app,
- stdout/stderr/event plumbing into Swift.

### Stage 1 — real process execution ✅ complete (2026-03-30, commit c877994)

What shipped:
- `cellarkit_bridge.c` now uses `posix_spawn()` + bidirectional pipes instead of hard-coded fake events.
- `wine-stub` compiled ARM64 binary bundled in `CellarApp.app/Binaries/` via Xcode preBuildScript.
  - Simulator build: macOS ARM64 (platform 1) so the sim's host process can `posix_spawn()` it directly.
  - Device build: iOS ARM64 (to be replaced by real Wine in Stage 2).
- `RuntimeLaunchConfiguration.resolveRuntimeBinaryPath()` locates the binary, copies it to `NSTemporaryDirectory()`, and `chmod 0755` before passing the path to the bridge (`xcrun simctl install` strips the +x bit).
- 31 real log lines captured from child stdout and stored in the session record.
- Legacy simulated-events fallback retained for when no binary is present.
- 35 unit tests + 6 E2E UI tests all pass.

### Stage 2 — real Wine binary (next)

Goal: replace `wine-stub` with a real `wine64` build so actual Windows PE binaries execute.

Preferred order:
1. Install / cross-compile Wine macOS ARM64 (`brew install --build-from-source wine-stable` or use a pre-built Homebrew bottle).
2. Copy `wine64` + required dylibs into `CellarApp.app/Binaries/` via the same build phase.
3. Update `cellarkit_bridge.c` argv from `[stub, --exe, ...]` to `[wine64, exe_path]`.
4. Bundle a simple Windows console `.exe` (Hello World PE, no graphics) as a test payload.
5. See actual Windows CRT output in the runtime log surface.

### Stage 3 — graphics (future)

Goal: route Wine's D3D11 output through DXVK → MoltenVK → Metal to a `CAMetalLayer` owned by `LaunchSurfaceView`.

Acceptance tests:
- start and stop runtime without app crash,
- collect logs,
- detect clean vs failed termination.

## Phase 4 — first executable title path

Goal:
- launch something real.

Preferred order:
1. Windows console app via Wine (no graphics) — validates Wine + PE loader end-to-end
2. ARM64/ARM64EC-friendly target path
3. x64 translation path with JIT support
4. interpreter-only fallback path

Deliverables:
- one launch pipeline from container metadata to running content,
- visible rendering,
- input path connected,
- audio path connected.

Current status:
- `posix_spawn` bridge operational; `wine-stub` placeholder produces real logs.
- Stage 2 (real Wine) is the active next milestone.

Acceptance tests:
- one known sample/game reaches menu or gameplay,
- frame pacing and thermal logs captured,
- relaunch works.

## Phase 5 — overlay and controls MVP

Goal:
- make phone usage actually viable.

Deliverables:
- touch overlay editor or preset loader,
- virtual gamepad,
- physical controller support,
- haptics fallback,
- in-game quick menu.

Acceptance tests:
- one title playable using only touch,
- one title playable with controller,
- overlay changes persist.

## Phase 6 — save paths and cloud sync

Goal:
- reproduce a subset of GameNative’s real-world usability.

Deliverables:
- local save path mapping,
- per-container save metadata,
- sync engine abstraction,
- first provider integration (likely Steam-style logic as reference only).

Acceptance tests:
- save discovery works,
- conflict policy exists,
- upload/download roundtrip works in a controlled scenario.

## Phase 7 — storefront integration

Goal:
- move from import-only to managed libraries.

Preferred order:
1. local import polish
2. Steam-like integration
3. GOG / Epic / Amazon

Deliverables:
- auth flow abstraction,
- library sync,
- install plan generation,
- download manager,
- per-store metadata handling.

Acceptance tests:
- auth survives relaunch,
- library refresh is incremental,
- installs can resume,
- uninstall cleanup works.

## Phase 8 — distribution split

Goal:
- separate the product into realistic shipping lanes.

Deliverables:
- research build configuration,
- constrained build configuration,
- explicit feature gating by distribution lane,
- policy checklist.

Acceptance tests:
- app clearly reports current lane and limitations,
- code paths are not accidentally mixed.

## Benchmarks to collect starting in Phase 4

For every backend experiment, record:
- cold launch time,
- prefix/container initialization time,
- memory footprint,
- JIT/interpreter mode,
- FPS in a known scene/menu,
- sustained performance after 10 minutes,
- thermal state,
- battery drain estimate,
- input latency observations,
- crash frequency.

## MVP definition

This project should only claim an MVP once all of the following are true:

- one real title or representative sample launches,
- rendering is stable enough to interact with,
- audio works,
- touch or controller input is usable,
- container state is durable,
- logs are inspectable,
- lifecycle events do not routinely destroy progress,
- at least one realistic distribution lane is operational.

## Long-term north star

The long-term target remains:
- sign in to game stores,
- see your library,
- install owned games,
- run them in per-game containers,
- sync saves,
- configure controls and runtime settings from an in-game overlay.

But the roadmap intentionally gets there **after** runtime viability is proven.
