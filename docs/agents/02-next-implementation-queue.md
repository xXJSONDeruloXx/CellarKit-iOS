# Next implementation queue

This is the concrete queue I would hand to the next agent session.

## Tier 1 — highest value

### 1. Add an iOS app target
Build a tiny host app that can:
- list containers,
- create a container,
- show the planner decision,
- persist and reload metadata.

### 2. Add capability-report models and a simple UI surface
Expose:
- lane,
- distribution-channel classification,
- JIT class,
- bookmark/import mode support,
- notes/warnings.

### 3. Add a launch-session model
Model:
- launch id,
- start time,
- end time,
- selected backend,
- exit state,
- log file path.

## Tier 2 — still strong value

### 4. Add import workflow abstractions
Create use cases for:
- managed copy import,
- bundled sample import,
- future security-scoped reference import.

### 5. Add default runtime-profile factory logic
Given lane + architecture + capability state, produce sane defaults for:
- graphics backend,
- memory budget,
- shader cache budget,
- touch overlay default.

### 6. Add benchmark result models
Keep experiment data machine-readable so future agents can compare backend runs.

## Tier 3 — after host app exists

### 7. Add native launch bridge spike
Even if the runtime is fake at first, prove:
- threaded start,
- stop,
- log callbacks,
- error propagation.

### 8. Add a minimal overlay shell
A tiny overlay that proves:
- settings access while a runtime session is active,
- one virtual control path,
- one session status path.

## Explicitly defer for now

- multi-store auth implementation
- cloud-save sync implementation
- full controller editor
- App Store submission work
- broad compatibility claims
