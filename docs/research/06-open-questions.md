# Open questions and experiments

This list is intentionally split into **known unknowns** and **speculative unknown unknowns**.

## Known unknowns

### 1. What is the best first execution backend?

Candidates:
- Wine + Windows ARM64/ARM64EC only
- Wine + Box64/FEX/QEMU-user style translation
- threaded-interpreter proof-of-life backend
- UTM-style full-system fallback only for diagnostics

### 2. Can Wine userland be embedded cleanly in a single iOS app process?

We have strong prior art from UTM embedding QEMU loops in-process, but we do not yet have a validated iOS-specific Wine embedding design.

### 3. Which graphics path is most realistic on iOS?

Needs experimentation across:
- DXVK + MoltenVK
- VKD3D-Proton + MoltenVK
- WineD3D fallback
- any Metal-native or Apple-specific translation paths worth exploring later

### 4. How usable is x64 translation with debugger-assisted JIT on actual phone hardware?

Benchmarks needed:
- cold boot time
- prefix initialization time
- title menu frame pacing
- input latency
- thermal throttling over 10–20 minutes

### 5. Can an App Store-safe SKU exist without neutering the product?

We need a practical review strategy answer, not just a theoretical one.

Potential test shape:
- import-only shell,
- no integrated storefront downloads,
- constrained runtime mode,
- submit early and learn from feedback.

### 6. How much of the GameNative UX should be replicated before the runtime is proven?

Risk:
- overbuild shell UX while the runtime remains uncertain.

Recommendation:
- prove local import + launch + input + graphics first,
- then add storefronts.

## Speculative unknown unknowns

These are areas where surprises are likely.

### 1. iOS code-signing / JIT behavior may change between releases

UTM’s patch history already shows iOS-version-specific workarounds.
Assume iOS point releases can change viability.

### 2. Shader translation and cache behavior may be worse on phones than expected

Even if the backend is technically functional, thermal and memory limits may make some graphics paths non-viable for real play sessions.

### 3. Anti-cheat / launcher / DRM behaviors may be a bigger blocker than the runtime itself

A technically working Windows userland does not imply store launches or protected titles will work.

### 4. Touch-first game UX may dominate engineering time

A surprising amount of value may live in:
- overlays,
- controller profiles,
- per-title presets,
- suspend/resume handling,
- save-path resolution,
- not the raw runtime core.

## Recommended experiments

## Experiment 1 — capability probe shell

Goal:
- native Swift iOS app that reports:
  - distribution channel,
  - JIT mode,
  - debugger attachment,
  - available memory limit state,
  - file import / bookmark behavior.

Success criteria:
- can reliably classify device/runtime mode at startup.

## Experiment 2 — import and container bundle

Goal:
- import a folder or executable,
- store metadata,
- persist bookmark or managed copy,
- show a launchable game entry.

Success criteria:
- robust re-open across app relaunches.

## Experiment 3 — embedded runtime spike

Goal:
- prove a tiny embedded C/C++ runtime loop can run safely in-process with SwiftUI host lifecycle.

Success criteria:
- no fatal lifecycle/pathing surprises.

## Experiment 4 — graphics proof-of-life

Goal:
- render a known D3D sample path through the proposed graphics bridge.

Success criteria:
- stable output, measurable frame pacing, acceptable memory footprint.

## Experiment 5 — input overlay prototype

Goal:
- define touch regions, virtual gamepad state, controller passthrough, and haptics behavior.

Success criteria:
- one sample title can be meaningfully controlled on-phone.

## Experiment 6 — policy reconnaissance

Goal:
- define a stripped-down App Store candidate and assess review risk.

Success criteria:
- concrete go/no-go criteria for a public SKU.

## Exit criteria before “real MVP”

Before claiming an MVP, the project should prove:
- import works,
- one backend launches something real,
- one graphics path is stable,
- one input overlay is usable,
- logs survive crashes,
- background/foreground behavior is not catastrophic,
- at least one distribution lane is operational.
