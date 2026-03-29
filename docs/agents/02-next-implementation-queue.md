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

### 3. Add per-container settings editing in the app
The app should let users edit at least:
- title,
- backend preference,
- graphics backend,
- memory budget,
- shader cache budget,
- touch/controller defaults.

### 4. Add real-device capability detection
Replace heuristics with stronger evidence where possible:
- simulator vs device,
- debugger attachment,
- distribution-channel assumptions,
- bookmark support behavior,
- memory-limit-related state,
- notes recorded for benchmark context.

## Tier 2 — still high value

### 5. Improve import UX
Turn the current button-level flow into a clearer import experience:
- import mode chooser,
- file/folder guidance,
- better success/failure messaging,
- duplicate-name handling,
- visible linked vs copied content state.

### 6. Add container management UX
Support:
- rename container,
- delete container,
- inspect resolved payload path,
- show content mode and bookmark state,
- show last-launched timestamp clearly.

### 7. Add session and benchmark detail views
Current history is summary-only. Add:
- full session event timeline,
- full log view,
- benchmark detail page,
- explicit failure explanation,
- export-friendly evidence surface.

### 8. Add a runtime play-surface placeholder
Even before a real runtime is wired up, create a dedicated launch surface that can own:
- runtime state banner,
- log console toggle,
- quick menu entry,
- future overlay/controller hooks.

## Tier 3 — after the above

### 9. Add first real runtime experiment
Potential order:
- minimal embedded native loop,
- diagnostic executable sample,
- ARM64-friendly narrow content path,
- only then wider translation/runtime work.

### 10. Add input/control UX scaffolding
At minimum prove one of:
- touch overlay stub,
- controller presence/status,
- session quick menu.

### 11. Expand benchmark capture
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
