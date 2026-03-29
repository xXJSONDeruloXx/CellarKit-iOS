# Autonomous build plan for future agents

This file is written for coding agents, not just humans.

## Primary objective

Build toward a side-load-first iOS MVP for running Windows game workloads in per-game containers, while preserving a future path to a more constrained public SKU.

## Non-objectives for the first implementation wave

Do **not** start by:
- cloning the entire GameNative UX in SwiftUI,
- building every storefront integration at once,
- assuming App Store compatibility,
- assuming x64 translation is the first runnable path.

## Preferred task order

### Task 1 — keep research current

Before changing code materially:
- verify the source index,
- confirm referenced external repos/paths still exist,
- update docs when assumptions change.

### Task 2 — extend the planning core

Implement and test pure-Swift domain models for:
- distribution channels,
- product lanes,
- JIT/execution modes,
- guest architectures,
- acquisition modes,
- backend planning decisions,
- policy risk grading,
- container metadata and persistence.

Expected output:
- deterministic unit tests,
- no platform-specific dependencies required.

### Task 3 — add an iOS host app target

Implement a minimal SwiftUI app that can:
- display current capability state,
- create a container record,
- import a file/folder,
- persist metadata.

Expected output:
- real-device smoke build,
- app relaunch persistence.

### Task 4 — runtime bridge spike

Implement the thinnest possible native bridge to prove:
- runtime startup,
- log capture,
- shutdown/failure reporting,
- in-process threading model.

Expected output:
- no storefronts,
- no beautiful UI required.

### Task 5 — first launch pipeline

Choose one narrow target:
- ARM64-friendly sample if possible,
- otherwise a deliberately tiny x64 proof-of-life with explicit JIT assumptions.

Expected output:
- one reproducible sample launch path.

### Task 6 — input and overlay

Implement:
- one touch overlay profile format,
- one controller path,
- one in-game runtime menu.

### Task 7 — only then consider storefront automation

When runtime, lifecycle, and input work, begin:
- auth abstractions,
- library sync abstractions,
- download/install abstractions,
- save-sync abstractions.

## Guardrails

1. Keep GPL code provenance explicit.
2. Prefer original Swift implementations for shell logic.
3. Add tests when business/planning logic changes.
4. Update docs when reality differs from earlier assumptions.
5. Record whether a claim is direct evidence or inference.

## Suggested future issue buckets

- `capability-detection`
- `container-model`
- `runtime-bridge`
- `graphics`
- `input-overlay`
- `audio`
- `lifecycle`
- `storefronts`
- `cloud-saves`
- `policy`
- `benchmarks`

## Done criteria for agent-created PRs

A change is not “done” unless it includes:
- updated docs if architecture changed,
- tests for planning logic,
- clear runtime assumptions,
- a note about distribution-lane impact if relevant.
