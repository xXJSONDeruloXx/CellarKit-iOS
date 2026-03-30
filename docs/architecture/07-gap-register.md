# Gap register

This document is the single place to answer: **what is implemented, what is partial, and what is still missing?**

Status values used here:
- **implemented** — present in code and validated at least by unit/smoke tests
- **partial** — structurally present but not production-ready or not yet backed by the real runtime/device path
- **missing** — not implemented in a meaningful way yet
- **deferred** — intentionally postponed

## App shell and UX

### Host app target
- Status: **implemented**
- Notes:
  - `App/CellarApp` exists
  - simulator UI smoke test exists

### Container list and selection
- Status: **implemented**
- Notes:
  - list, select, inspect metadata, and view launch state all exist

### Container rename
- Status: **implemented**
- Notes:
  - selected container title can now be edited and saved

### Container delete
- Status: **implemented**
- Notes:
  - deletes metadata and associated session / benchmark artifacts
  - managed-copy payload cleanup is implemented

### Import UX
- Status: **partial**
- Notes:
  - managed-copy import exists
  - external-reference linking exists
  - importer UX is still button-level and not yet a polished flow
  - duplicate handling, richer validation, and recovery UX are still missing

### Container detail/settings editor
- Status: **implemented**
- Notes:
  - title editing exists
  - runtime-profile editing now exists for backend, graphics backend, memory budget, shader cache budget, and touch/controller defaults

### Session detail screen
- Status: **implemented**
- Notes:
  - selected session detail and event timeline now exist in the host shell

### Benchmark detail screen
- Status: **implemented**
- Notes:
  - selected benchmark detail now exists in the host shell

### Runtime play surface / dedicated launch surface
- Status: **partial**
- Notes:
  - a launch-surface placeholder now appears after launch
  - for DX11 payloads (Hello Cube) the surface shows a live SwiftUI 3D spinning cube and translation pipeline badges
  - it is not yet a real render/input owning runtime surface

### Touch overlay UX
- Status: **missing**

### Controller UX
- Status: **missing**

## Core data and persistence

### Container metadata persistence
- Status: **implemented**

### Launch-session persistence
- Status: **implemented**

### Benchmark persistence
- Status: **implemented**

### Imported content references
- Status: **implemented**
- Notes:
  - managed copy
  - bundled sample
  - external reference / bookmark identifier

### Migration strategy for future metadata changes
- Status: **partial**
- Notes:
  - current JSON structures are stable for the prototype
  - explicit versioned migrations are not yet implemented

## Import and filesystem behavior

### Managed-copy payload import
- Status: **implemented**

### External-reference / bookmark-backed linking
- Status: **partial**
- Notes:
  - structure exists
  - save/resolve exists
  - true long-lived sandbox bookmark lifecycle needs hardening
  - stale bookmark recovery UX is missing

### Real document/folder guidance UX
- Status: **missing**

## Capability and environment detection

### Lane / distribution / JIT heuristics
- Status: **implemented**

### Real-device capability detection
- Status: **partial**
- Notes:
  - current behavior is heuristic / environment-driven
  - device-specific proof is still needed

## Runtime and launch pipeline

### Planner and backend selection
- Status: **implemented**

### Native bridge stub
- Status: **implemented**
- Notes:
  - C-backed callback bridge exists
  - launch configuration translation exists

### Launch target metadata and bootstrap validation
- Status: **partial**
- Notes:
  - containers now persist an `entryExecutableRelativePath`
  - managed-copy and external-link imports attempt to infer a `.exe` entry target
  - runtime launch configuration now resolves an executable path when possible
  - the native stub now fails early when a non-sample payload has no resolvable launch executable
  - manual entry-target editing and real execution of that target are still missing

### Real runtime bootstrap
- Status: **missing**

### Real Wine/runtime integration
- Status: **missing**

### Render/input/audio lifecycle with actual runtime
- Status: **missing**

## Observability and testing

### Swift package test coverage
- Status: **implemented**

### iOS simulator UI smoke test
- Status: **implemented**

### Real-device automated validation
- Status: **missing**

### Rich benchmark capture
- Status: **partial**
- Notes:
  - derived session timing exists
  - thermals, device identity, memory-pressure signals, and richer runtime evidence are not yet collected

## Storefronts and ecosystem features

### Store auth / library sync / install management
- Status: **deferred**

### Cloud-save sync
- Status: **deferred**

### Broad compatibility claims
- Status: **deferred**

## Immediate highest-value missing pieces

If another agent needs the shortest truthful list, it is:
1. real runtime bootstrap shim that consumes the resolved launch executable
2. hardened bookmark lifecycle
3. real render/input-owning runtime surface
4. real-device validation
5. richer import UX, including manual entry-executable override/recovery flows
6. deeper benchmark and runtime evidence capture

## Validated end-to-end flows (as of latest commit)

- Hello Cube (DX11, mindaptiv/Hello-Cube-Windows Tutorial04) bundled sample:
  - Container creates successfully via `createHelloCubeButton`
  - Entry executable `Debug/Tutorial04.exe` persists in container metadata
  - Launch completes with DX11/DXVK/MoltenVK simulated log output from native C bridge stub
  - Launch surface sheet appears with live SpinningCubeView and translation pipeline badges
  - Session record and benchmark are persisted and visible after launch
  - All 6 CellarKitE2ETests pass; all 35 unit tests pass
