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
- Status: **partial**
- Notes:
  - title editing exists
  - runtime-profile editing does not yet exist in the app UI

### Session detail screen
- Status: **missing**

### Benchmark detail screen
- Status: **missing**

### Runtime play surface / dedicated launch surface
- Status: **missing**

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
1. real runtime bootstrap shim
2. hardened bookmark lifecycle
3. runtime-profile settings editor in the app
4. dedicated session/log/benchmark detail views
5. play-surface placeholder and eventual real runtime surface
6. real-device validation
