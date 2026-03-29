# Next implementation queue

This is the concrete queue I would hand to the next agent session.

## Already implemented foundation

These items are no longer the next priority because they already exist in some form:
- iOS app target scaffold (`App/CellarApp`)
- SwiftUI host shell (`CellarUI`)
- container persistence
- launch-session persistence
- benchmark persistence
- managed-copy import flow
- external-reference / bookmark-backed linking flow
- native C-backed runtime bridge stub
- simulator UI smoke test automation

## Tier 1 — highest-value remaining work

### 1. Replace the native stub with a real runtime bootstrap shim
Build the first true bridge layer that can:
- assemble launch config into native runtime parameters,
- consume the resolved launch executable path from container metadata,
- start a real embedded runtime thread/process loop,
- surface stdout/stderr/log callbacks,
- stop cleanly,
- distinguish bootstrap failure from runtime failure.

### 2. Harden security-scoped bookmark lifecycle
The current external-link path is structurally present, but needs production-style handling for:
- stale bookmark detection,
- re-resolution after relaunch,
- start/stop access windows,
- permission-loss recovery UX,
- clearer separation between sandbox-friendly links and merely simulated links.

### 3. Add real-device capability detection
Replace heuristics with stronger evidence where possible:
- simulator vs device,
- debugger attachment,
- distribution-channel assumptions,
- bookmark support behavior,
- memory-limit-related state,
- notes recorded for benchmark context.

## Tier 2 — still high value

### 4. Improve import UX
Turn the current button-level flow into a clearer import experience:
- import mode chooser,
- file/folder guidance,
- better success/failure messaging,
- duplicate-name handling,
- visible linked vs copied content state,
- manual entry-executable override when inference is wrong.

### 5. Improve session and benchmark detail surfaces
The host shell now has basic detail views, but still needs:
- fuller log exploration,
- easier failure triage,
- export-friendly evidence presentation,
- richer benchmark metadata.

### 6. Expand the runtime play-surface placeholder into a real runtime surface
The placeholder now exists, but still needs to own:
- runtime state banner,
- log console toggle,
- quick menu entry,
- future overlay/controller hooks,
- eventual real render/input ownership.

## Tier 3 — after the above

### 7. Add first real runtime experiment
Potential order:
- minimal embedded native loop,
- diagnostic executable sample,
- ARM64-friendly narrow content path,
- only then wider translation/runtime work.

### 8. Add input/control UX scaffolding
At minimum prove one of:
- touch overlay stub,
- controller presence/status,
- session quick menu.

### 9. Expand benchmark capture
Capture richer evidence beyond derived session timing:
- device identity,
- OS version,
- thermal state if obtainable,
- memory warnings / pressure signals,
- launch artifact bundle paths.

## Explicitly defer for now

- multi-store auth implementation
- cloud-save sync implementation
- full controller editor
- App Store submission work
- broad compatibility claims
- polished storefront/library UX
